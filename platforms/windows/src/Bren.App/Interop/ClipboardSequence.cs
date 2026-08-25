using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

internal static partial class ClipboardSequence
{
    [LibraryImport("user32.dll")] private static partial uint GetClipboardSequenceNumber();
    internal static uint Number() => GetClipboardSequenceNumber();
}
