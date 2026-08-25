using System.Runtime.InteropServices;
using Bren.Windows.Core;
using Bren.Windows.Interop;
using System.Runtime.InteropServices.ComTypes;

namespace Bren.Windows.Selection;

internal sealed record Selection(string Text);

internal sealed class SelectionReader
{
    private readonly SemaphoreSlim transaction = new(1, 1);

    internal async Task<Selection> ReadAsync(CancellationToken cancellationToken)
    {
        await transaction.WaitAsync(cancellationToken).ConfigureAwait(true);
        try
        {
            if (ForegroundInterop.IsForegroundElevated()) throw new SelectionReadException("The active elevated application cannot be read by Bren.");
            string? text = null;
            if (string.IsNullOrWhiteSpace(text)) text = await CopyFallbackAsync(cancellationToken).ConfigureAwait(true);
            text = text.Trim();
            if (string.IsNullOrWhiteSpace(text)) throw new SelectionReadException("No readable selection.");
            if (!Protocol.IsValidText(text)) throw new SelectionReadException("The selection is longer than 12,000 Unicode code points.");
            return new Selection(text);
        }
        finally { transaction.Release(); }
    }

    private static async Task<string> CopyFallbackAsync(CancellationToken cancellationToken)
    {
        var before = ClipboardInterop.Snapshot();
        var sequence = ClipboardSequence.Number();
        if (!InputInterop.SendCopy()) throw new SelectionReadException("Could not copy the active selection.");

        var deadline = DateTimeOffset.UtcNow.AddMilliseconds(750);
        while (ClipboardSequence.Number() == sequence && DateTimeOffset.UtcNow < deadline)
            await Task.Delay(15, cancellationToken).ConfigureAwait(true);
        if (ClipboardSequence.Number() == sequence) throw new SelectionReadException("No readable selection.");

        try { return ClipboardInterop.ReadUnicodeText(); }
        finally { await RestoreClipboardAsync(before, cancellationToken).ConfigureAwait(true); }
    }

    private static async Task RestoreClipboardAsync(IDataObject? original, CancellationToken cancellationToken)
    {
        if (original is null) return;
        for (var attempt = 0; attempt < 4; attempt++)
        {
            try { if (ClipboardInterop.Restore(original)) return; }
            catch (ExternalException) when (attempt < 3) { await Task.Delay(40, cancellationToken).ConfigureAwait(true); }
        }
    }
}

internal sealed class SelectionReadException(string message) : Exception(message);
