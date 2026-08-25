using System.Runtime.InteropServices;
using Bren.Windows.Application;
using Bren.Windows.Interop;

namespace Bren.Windows.HotKey;

internal sealed partial class GlobalHotKey : IDisposable
{
    private const int Id = 0xB001;
    private const uint ModAlt = 0x0001;
    private const uint VkD = 0x44;
    private readonly MessageWindow window;
    private bool registered;
    internal event Action? Pressed;
    internal bool IsRegistered => registered;

    internal GlobalHotKey(MessageWindow window)
    {
        this.window = window;
        window.Message += HandleMessage;
    }

    internal bool Register()
    {
        registered = RegisterHotKey(window.Handle, Id, ModAlt, VkD);
        if (!registered) Log.Write("Alt+D is already registered by another application.");
        return registered;
    }

    private void HandleMessage(uint message, nuint wParam, nint _) { if (message == MessageWindow.WmHotKey && wParam == Id) Pressed?.Invoke(); }
    public void Dispose() { if (registered) UnregisterHotKey(window.Handle, Id); window.Message -= HandleMessage; }

    [LibraryImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool RegisterHotKey(nint hwnd, int id, uint modifiers, uint key);
    [LibraryImport("user32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool UnregisterHotKey(nint hwnd, int id);
}
