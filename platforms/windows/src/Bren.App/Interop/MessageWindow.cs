using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

internal sealed partial class MessageWindow : IDisposable
{
    internal const uint WmHotKey = 0x0312;
    internal const uint WmCommand = 0x0111;
    internal const uint WmApp = 0x8000;
    private const int GwlWndProc = -4;
    private readonly WndProcDelegate proc;
    private readonly nint oldProc;
    internal nint Handle { get; }
    internal event Action<uint, nuint, nint>? Message;

    internal MessageWindow()
    {
        Handle = CreateWindowEx(0, "STATIC", null, 0, 0, 0, 0, 0, new nint(-3), 0, 0, 0);
        if (Handle == 0) throw new InvalidOperationException("Unable to create Bren's message window.");
        proc = WindowProc;
        oldProc = SetWindowLongPtr(Handle, GwlWndProc, Marshal.GetFunctionPointerForDelegate(proc));
    }

    private nint WindowProc(nint hwnd, uint message, nuint wParam, nint lParam)
    {
        Message?.Invoke(message, wParam, lParam);
        return CallWindowProc(oldProc, hwnd, message, wParam, lParam);
    }

    public void Dispose() { if (Handle != 0) DestroyWindow(Handle); GC.KeepAlive(proc); }

    private delegate nint WndProcDelegate(nint hwnd, uint message, nuint wParam, nint lParam);
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16, SetLastError = true)] private static partial nint CreateWindowEx(uint exStyle, string className, string? windowName, uint style, int x, int y, int width, int height, nint parent, nint menu, nint instance, nint parameter);
    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)] private static partial nint SetWindowLongPtr(nint hwnd, int index, nint newLong);
    [LibraryImport("user32.dll")] private static partial nint CallWindowProc(nint previous, nint hwnd, uint message, nuint wParam, nint lParam);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool DestroyWindow(nint hwnd);
}
