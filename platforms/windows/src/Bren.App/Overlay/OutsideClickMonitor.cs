using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using Bren.Windows.Interop;

namespace Bren.Windows.Overlay;

/// <summary>Temporary low-level mouse monitor; installed only while an unpinned panel is visible.</summary>
internal sealed partial class OutsideClickMonitor : IDisposable
{
    private const int WhMouseLl = 14;
    private const uint WmLButtonDown = 0x0201;
    private const uint WmRButtonDown = 0x0204;
    private readonly nint overlay;
    private readonly DispatcherQueue dispatcher;
    private readonly Action outside;
    private readonly HookProc callback;
    private nint hook;

    internal OutsideClickMonitor(nint overlay, DispatcherQueue dispatcher, Action outside)
    {
        this.overlay = overlay;
        this.dispatcher = dispatcher;
        this.outside = outside;
        callback = Receive;
    }

    internal void Start()
    {
        if (hook != 0) return;
        hook = SetWindowsHookEx(WhMouseLl, callback, 0, 0);
    }

    internal void Stop()
    {
        if (hook == 0) return;
        UnhookWindowsHookEx(hook);
        hook = 0;
    }

    private nint Receive(int code, nuint message, nint data)
    {
        if (code >= 0 && (message is WmLButtonDown or WmRButtonDown) && GetWindowRect(overlay, out var rect))
        {
            var mouse = Marshal.PtrToStructure<MouseHook>(data).Point;
            if (mouse.X < rect.Left || mouse.X >= rect.Right || mouse.Y < rect.Top || mouse.Y >= rect.Bottom)
                dispatcher.TryEnqueue(() => { Stop(); outside(); });
        }
        return CallNextHookEx(hook, code, message, data);
    }

    public void Dispose() { Stop(); GC.KeepAlive(callback); }

    private delegate nint HookProc(int code, nuint message, nint data);
    [StructLayout(LayoutKind.Sequential)] private struct MouseHook { internal PointInt Point; internal uint MouseData; internal uint Flags; internal uint Time; internal nint Extra; }
    [LibraryImport("user32.dll", SetLastError = true)] private static partial nint SetWindowsHookEx(int idHook, HookProc callback, nint module, uint threadId);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool UnhookWindowsHookEx(nint hook);
    [LibraryImport("user32.dll")] private static partial nint CallNextHookEx(nint hook, int code, nuint message, nint data);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool GetWindowRect(nint hwnd, out RectInt rect);
}
