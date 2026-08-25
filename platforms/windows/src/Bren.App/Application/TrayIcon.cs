using System.Runtime.InteropServices;
using Bren.Windows.Interop;

namespace Bren.Windows.Application;

internal sealed class TrayIcon : IDisposable
{
    private const uint IconId = 1;
    private const uint Callback = MessageWindow.WmApp + 1;
    private readonly MessageWindow window;
    private NotifyIconData data;
    internal event Action? TranslateRequested;
    internal event Action? UpdateRequested;
    internal event Action? QuitRequested;

    internal TrayIcon(MessageWindow window)
    {
        this.window = window;
        data = new NotifyIconData
        {
            Size = Marshal.SizeOf<NotifyIconData>(), Window = window.Handle, Id = IconId,
            Flags = ShellInterop.NifMessage | ShellInterop.NifIcon | ShellInterop.NifTip,
            CallbackMessage = Callback, Icon = ShellInterop.LoadIcon(0, 32512), Tip = "Bren",
        };
        ShellInterop.ShellNotifyIcon(ShellInterop.NimAdd, ref data);
        window.Message += Receive;
    }

    private void Receive(uint message, nuint _, nint lParam)
    {
        if (message == Callback && lParam == (nint)ShellInterop.WmRButtonUp) ShowMenu();
    }

    private void ShowMenu()
    {
        var menu = ShellInterop.CreatePopupMenu();
        try
        {
            ShellInterop.AppendMenu(menu, ShellInterop.MfString, 1, "Translate");
            ShellInterop.AppendMenu(menu, ShellInterop.MfString, 2, "Check for Updates");
            ShellInterop.AppendMenu(menu, ShellInterop.MfString, 3, "Quit");
            WindowInterop.GetCursorPos(out var point);
            switch (ShellInterop.TrackPopupMenu(menu, ShellInterop.TpmReturnCmd | ShellInterop.TpmNonotify, point.X, point.Y, 0, window.Handle, 0))
            {
                case 1: TranslateRequested?.Invoke(); break;
                case 2: UpdateRequested?.Invoke(); break;
                case 3: QuitRequested?.Invoke(); break;
            }
        }
        finally { ShellInterop.DestroyMenu(menu); }
    }

    public void Dispose()
    {
        window.Message -= Receive;
        ShellInterop.ShellNotifyIcon(ShellInterop.NimDelete, ref data);
    }
}
