using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

namespace Bren.Windows.Interop;

internal static partial class ClipboardInterop
{
    private const uint CfUnicodeText = 13;
    private const uint GmemMoveable = 0x0002;

    internal static IDataObject? Snapshot()
    {
        var result = OleGetClipboard(out var data);
        return result >= 0 ? data : null;
    }

    internal static string ReadUnicodeText()
    {
        if (!OpenClipboard(0)) return string.Empty;
        try
        {
            var handle = GetClipboardData(CfUnicodeText);
            if (handle == 0) return string.Empty;
            var pointer = GlobalLock(handle);
            if (pointer == 0) return string.Empty;
            try { return Marshal.PtrToStringUni(pointer) ?? string.Empty; }
            finally { GlobalUnlock(handle); }
        }
        finally { CloseClipboard(); }
    }

    internal static bool Restore(IDataObject data) => OleSetClipboard(data) >= 0;

    internal static void WriteUnicodeText(string text)
    {
        if (!OpenClipboard(0)) return;
        try
        {
            if (!EmptyClipboard()) return;
            var bytes = Encoding.Unicode.GetBytes(text + '\0');
            var memory = GlobalAlloc(GmemMoveable, (nuint)bytes.Length);
            if (memory == 0) return;
            var pointer = GlobalLock(memory);
            if (pointer == 0) { GlobalFree(memory); return; }
            try { Marshal.Copy(bytes, 0, pointer, bytes.Length); }
            finally { GlobalUnlock(memory); }
            if (SetClipboardData(CfUnicodeText, memory) == 0) GlobalFree(memory);
        }
        finally { CloseClipboard(); }
    }

    [LibraryImport("ole32.dll")] private static partial int OleGetClipboard([MarshalAs(UnmanagedType.Interface)] out IDataObject? data);
    [LibraryImport("ole32.dll")] private static partial int OleSetClipboard([MarshalAs(UnmanagedType.Interface)] IDataObject data);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool OpenClipboard(nint window);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool CloseClipboard();
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool EmptyClipboard();
    [LibraryImport("user32.dll")] private static partial nint GetClipboardData(uint format);
    [LibraryImport("user32.dll")] private static partial nint SetClipboardData(uint format, nint memory);
    [LibraryImport("kernel32.dll")] private static partial nint GlobalAlloc(uint flags, nuint bytes);
    [LibraryImport("kernel32.dll")] private static partial nint GlobalFree(nint memory);
    [LibraryImport("kernel32.dll")] private static partial nint GlobalLock(nint memory);
    [LibraryImport("kernel32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool GlobalUnlock(nint memory);
}
