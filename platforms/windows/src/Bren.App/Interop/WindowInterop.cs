using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

[StructLayout(LayoutKind.Sequential)] internal struct PointInt { internal int X; internal int Y; }
[StructLayout(LayoutKind.Sequential)] internal struct RectInt { internal int Left; internal int Top; internal int Right; internal int Bottom; }
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] internal struct MonitorInfo { internal int Size; internal RectInt Monitor; internal RectInt Work; internal uint Flags; }

internal static partial class WindowInterop
{
    internal const int GwlExStyle = -20;
    internal const nint WsExToolWindow = 0x00000080;
    internal const nint WsExNoActivate = 0x08000000;
    internal const uint SwpNoActivate = 0x0010;
    internal const uint SwpNoSize = 0x0001;
    internal const int HwndTopmost = -1;
    internal const int SwShownoactivate = 4;
    internal const uint MonitorDefaultToNearest = 2;

    [LibraryImport("user32.dll")] internal static partial bool GetCursorPos(out PointInt point);
    [LibraryImport("user32.dll")] internal static partial nint MonitorFromPoint(PointInt point, uint flags);
    [LibraryImport("user32.dll", SetLastError = true)] internal static partial bool GetMonitorInfo(nint monitor, ref MonitorInfo info);
    [LibraryImport("user32.dll")] internal static partial uint GetDpiForWindow(nint hwnd);
    [LibraryImport("user32.dll")] internal static partial bool ShowWindow(nint hwnd, int command);
    [LibraryImport("user32.dll")] internal static partial bool SetWindowPos(nint hwnd, nint insertAfter, int x, int y, int cx, int cy, uint flags);
    [LibraryImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] internal static partial nint GetWindowLongPtr(nint hwnd, int index);
    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] internal static partial nint SetWindowLongPtr(nint hwnd, int index, nint value);
    [LibraryImport("user32.dll")] internal static partial bool GetWindowRect(nint hwnd, out RectInt rect);
}
