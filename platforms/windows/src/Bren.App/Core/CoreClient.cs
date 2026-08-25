using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;

namespace Bren.Windows.Core;

internal sealed class CoreClient : IAsyncDisposable
{
    private readonly SemaphoreSlim writeGate = new(1, 1);
    private readonly CancellationTokenSource shutdown = new();
    private readonly Action<CoreEvent> onEvent;
    private readonly Action<string> onDiagnostic;
    private Process? process;
    private StreamWriter? stdin;
    private Task? stdoutPump;
    private Task? stderrPump;
    internal TaskCompletionSource<bool> Ready { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

    internal CoreClient(Action<CoreEvent> onEvent, Action<string>? onDiagnostic = null)
    {
        this.onEvent = onEvent;
        this.onDiagnostic = onDiagnostic ?? (_ => { });
    }

    internal void Start()
    {
        if (process is not null) return;
        var started = new ProcessStartInfo(CoreLocator.Resolve())
        {
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardInputEncoding = new UTF8Encoding(false),
            StandardOutputEncoding = new UTF8Encoding(false),
            StandardErrorEncoding = new UTF8Encoding(false),
        };
        process = Process.Start(started) ?? throw new InvalidOperationException("Bren core did not start.");
        stdin = process.StandardInput;
        stdoutPump = PumpStdoutAsync(process.StandardOutput, shutdown.Token);
        stderrPump = PumpStderrAsync(process.StandardError, shutdown.Token);
        _ = ObserveExitAsync(process, shutdown.Token);
    }

    internal async Task<string> TranslateAsync(string id, string text, CancellationToken cancellationToken)
    {
        if (!Protocol.IsValidText(text)) throw new ArgumentException("Selection must contain at most 12,000 Unicode code points.", nameof(text));
        await Ready.Task.WaitAsync(cancellationToken).ConfigureAwait(false);
        await SendAsync(Protocol.Translate(id, text), cancellationToken).ConfigureAwait(false);
        return id;
    }

    internal Task CancelAsync(string requestId, CancellationToken cancellationToken = default) =>
        SendAsync(Protocol.Cancel(Guid.NewGuid().ToString("N"), requestId), cancellationToken);

    private async Task SendAsync(string line, CancellationToken cancellationToken)
    {
        var writer = stdin ?? throw new InvalidOperationException("Bren core is not running.");
        await writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            await writer.WriteLineAsync(line.AsMemory(), cancellationToken).ConfigureAwait(false);
            await writer.FlushAsync(cancellationToken).ConfigureAwait(false);
        }
        finally { writeGate.Release(); }
    }

    private async Task PumpStdoutAsync(StreamReader reader, CancellationToken cancellationToken)
    {
        try
        {
            while (await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false) is { } line)
            {
                try
                {
                    var item = JsonSerializer.Deserialize<CoreEvent>(line, Protocol.Json);
                    if (item is null || item.Version != Protocol.Version) { onDiagnostic("Ignoring unsupported Bren core event."); continue; }
                    if (item.Event == "ready") Ready.TrySetResult(true);
                    onEvent(item);
                }
                catch (JsonException) { onDiagnostic("Ignoring malformed JSONL from Bren core."); }
            }
            if (!shutdown.IsCancellationRequested) Ready.TrySetException(new EndOfStreamException("Bren core closed its protocol stream."));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
        catch (Exception exception) { Ready.TrySetException(exception); onDiagnostic(exception.Message); }
    }

    private async Task PumpStderrAsync(StreamReader reader, CancellationToken cancellationToken)
    {
        try
        {
            while (await reader.ReadLineAsync(cancellationToken).ConfigureAwait(false) is { } line) onDiagnostic(line);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
    }

    private async Task ObserveExitAsync(Process child, CancellationToken cancellationToken)
    {
        try
        {
            await child.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
            if (!shutdown.IsCancellationRequested) Ready.TrySetException(new InvalidOperationException("Bren core exited unexpectedly."));
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { }
    }

    public async ValueTask DisposeAsync()
    {
        shutdown.Cancel();
        stdin?.Close();
        if (process is { HasExited: false } child)
        {
            if (!child.WaitForExit(1_000)) child.Kill(entireProcessTree: true);
        }
        var pumps = new[] { stdoutPump, stderrPump }.Where(task => task is not null).Cast<Task>();
        try { await Task.WhenAll(pumps).ConfigureAwait(false); } catch (OperationCanceledException) { }
        process?.Dispose();
        writeGate.Dispose();
        shutdown.Dispose();
    }
}
