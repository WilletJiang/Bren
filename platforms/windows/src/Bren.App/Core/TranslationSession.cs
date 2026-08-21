namespace Bren.Windows.Core;

internal enum TranslationPhase { Hidden, Capturing, Starting, Streaming, Completed, Failed, Dismissing }

/// <summary>The sole owner of visible request identity, text, and lifecycle transitions.</summary>
internal sealed class TranslationSession
{
    internal TranslationPhase Phase { get; private set; } = TranslationPhase.Hidden;
    internal string? RequestId { get; private set; }
    internal string Text { get; private set; } = string.Empty;

    internal void Capturing() => Transition(TranslationPhase.Capturing);
    internal void Begin(string requestId)
    {
        if (string.IsNullOrWhiteSpace(requestId)) throw new ArgumentException("Request id is required.", nameof(requestId));
        RequestId = requestId;
        Text = string.Empty;
        Phase = TranslationPhase.Starting;
    }

    internal bool Started(string id) => Matches(id) && Set(TranslationPhase.Streaming);
    internal bool Delta(string id, string? text)
    {
        if (!Matches(id) || string.IsNullOrEmpty(text)) return false;
        if (Phase is not (TranslationPhase.Starting or TranslationPhase.Streaming)) return false;
        Text += text;
        Phase = TranslationPhase.Streaming;
        return true;
    }

    internal bool Completed(string id, string? text)
    {
        if (!Matches(id)) return false;
        if (!string.IsNullOrEmpty(text)) Text = text;
        return Set(TranslationPhase.Completed);
    }

    internal bool Failed(string? id = null)
    {
        if (id is not null && !Matches(id)) return false;
        return Set(TranslationPhase.Failed);
    }

    internal void Dismiss() { Phase = TranslationPhase.Dismissing; RequestId = null; }
    internal void Hide() { Phase = TranslationPhase.Hidden; RequestId = null; Text = string.Empty; }

    private bool Matches(string id) => RequestId is not null && StringComparer.Ordinal.Equals(RequestId, id);
    private bool Set(TranslationPhase phase) { Phase = phase; return true; }
    private void Transition(TranslationPhase phase) => Phase = phase;
}
