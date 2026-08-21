using Microsoft.UI.Dispatching;
using Bren.Windows.Core;
using Bren.Windows.HotKey;
using Bren.Windows.Interop;
using Bren.Windows.Overlay;
using Bren.Windows.Selection;
using Bren.Windows.Updates;

namespace Bren.Windows.Application;

internal sealed class AppCoordinator : IAsyncDisposable
{
    private readonly DispatcherQueue dispatcher;
    private readonly TranslationSession session = new();
    private readonly MessageWindow messages = new();
    private readonly GlobalHotKey hotKey;
    private readonly SelectionReader selection = new();
    private readonly OverlayController overlay = new();
    private readonly UpdateController updates = new();
    private readonly TrayIcon tray;
    private CoreClient? core;
    private CancellationTokenSource? requestCancellation;
    private CancellationTokenSource? acceptanceWatchdog;
    private CancellationTokenSource? firstTokenWatchdog;
    private string? visibleText;

    internal AppCoordinator(DispatcherQueue dispatcher)
    {
        this.dispatcher = dispatcher;
        tray = new TrayIcon(messages);
        hotKey = new GlobalHotKey(messages);
        hotKey.Pressed += TranslateSelection;
        tray.TranslateRequested += TranslateSelection;
        tray.UpdateRequested += () => _ = updates.CheckInBackgroundAsync();
        tray.QuitRequested += () => Microsoft.UI.Xaml.Application.Current.Exit();
        overlay.CopyRequested += CopyVisibleText;
        overlay.CancelRequested += CancelVisibleRequest;
    }

    internal void Start()
    {
        core = new CoreClient(ReceiveCoreEvent, Log.Write);
        core.Start();
        hotKey.Register();
        _ = updates.CheckInBackgroundAsync();
    }

    internal void TranslateSelection()
    {
        _ = CaptureAndTranslateAsync();
    }

    private async Task CaptureAndTranslateAsync()
    {
        CancelVisibleRequest();
        session.Capturing();
        try
        {
            var selected = await selection.ReadAsync(CancellationToken.None).ConfigureAwait(true);
            await (core ?? throw new InvalidOperationException("Bren core is unavailable.")).Ready.Task.ConfigureAwait(true);
            session.Begin(Guid.NewGuid().ToString("N"));
            overlay.Begin();
            requestCancellation = new CancellationTokenSource();
            StartAcceptanceWatchdog(session.RequestId!);
            await (core ?? throw new InvalidOperationException("Bren core is unavailable.")).TranslateAsync(session.RequestId!, selected.Text, requestCancellation.Token).ConfigureAwait(true);
        }
        catch (SelectionReadException exception) { ShowFailure(exception.Message); }
        catch (Exception exception) { ShowFailure($"Translation could not start: {exception.Message}"); }
    }

    private void ReceiveCoreEvent(CoreEvent item) => dispatcher.TryEnqueue(() => HandleCoreEvent(item));

    private void HandleCoreEvent(CoreEvent item)
    {
        if (item.Event == "ready") return;
        if (item.Id is null || item.Id != session.RequestId) { Log.Write("Ignoring core event for an unknown request."); return; }
        switch (item.Event)
        {
            case "started":
                if (session.Started(item.Id)) { Stop(ref acceptanceWatchdog); StartFirstTokenWatchdog(item.Id); }
                break;
            case "delta":
                if (session.Delta(item.Id, Protocol.Text(item))) { Stop(ref firstTokenWatchdog); visibleText = session.Text; overlay.Append(session.Text); }
                break;
            case "completed":
                if (session.Completed(item.Id, Protocol.Text(item))) { ClearWatchdogs(); visibleText = session.Text; overlay.Complete(session.Text); }
                break;
            case "cancelled":
                if (session.Failed(item.Id)) { ClearWatchdogs(); overlay.Fail("Translation cancelled. Try again."); }
                break;
            case "error":
                if (session.Failed(item.Id)) { ClearWatchdogs(); overlay.Fail(item.Error?.Message ?? "Translation failed. Try again."); }
                break;
        }
    }

    private void StartAcceptanceWatchdog(string requestId) => acceptanceWatchdog = Deadline(TimeSpan.FromSeconds(20), requestId, "Bren core did not accept the request. Try again.");
    private void StartFirstTokenWatchdog(string requestId) => firstTokenWatchdog = Deadline(TimeSpan.FromSeconds(15), requestId, "Translation did not start streaming. Try again.");
    private CancellationTokenSource Deadline(TimeSpan duration, string requestId, string message)
    {
        var source = new CancellationTokenSource();
        _ = Task.Run(async () =>
        {
            try { await Task.Delay(duration, source.Token).ConfigureAwait(false); }
            catch (OperationCanceledException) { return; }
            dispatcher.TryEnqueue(() =>
            {
                if (session.RequestId == requestId && session.Failed(requestId)) { CancelVisibleRequest(); overlay.Fail(message); }
            });
        });
        return source;
    }

    private void CancelVisibleRequest()
    {
        var id = session.RequestId;
        requestCancellation?.Cancel();
        if (id is not null && core is not null) _ = core.CancelAsync(id);
        ClearWatchdogs();
    }

    private void ShowFailure(string message) { session.Failed(); ClearWatchdogs(); overlay.Begin(); overlay.Fail(message); }
    private void CopyVisibleText() { if (!string.IsNullOrEmpty(visibleText)) System.Windows.Forms.Clipboard.SetText(visibleText); }
    private static void Stop(ref CancellationTokenSource? source) { source?.Cancel(); source?.Dispose(); source = null; }
    private void ClearWatchdogs() { Stop(ref acceptanceWatchdog); Stop(ref firstTokenWatchdog); }

    public async ValueTask DisposeAsync()
    {
        CancelVisibleRequest();
        tray.Dispose();
        hotKey.Dispose();
        messages.Dispose();
        if (core is not null) await core.DisposeAsync().ConfigureAwait(false);
    }
}
