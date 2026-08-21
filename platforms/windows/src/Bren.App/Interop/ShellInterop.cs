using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct NotifyIconData
{
    internal int Size;
    internal nint Window;
    internal uint Id;
    internal uint Flags;
    internal uint CallbackMessage;
    internal nint Icon;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] internal string Tip;
}

internal static partial class ShellInterop
{
    internal const uint NimAdd = 0;
    internal const uint NimDelete = 2;
    internal const uint NifMessage = 1;
    internal const uint NifIcon = 2;
    internal const uint NifTip = 4;
    internal const int WmRButtonUp = 0x0205;
    internal const uint MfString = 0;
    internal const uint TpmReturnCmd = 0x0100;
    internal const uint TpmNonotify = 0x0080;

    [LibraryImport("shell32.dll", EntryPoint = "Shell_NotifyIconW")] [return: MarshalAs(UnmanagedType.Bool)] internal static partial bool ShellNotifyIcon(uint message, ref NotifyIconData data);
    [LibraryImport("user32.dll")] internal static partial nint LoadIcon(nint instance, nint iconName);
    [LibraryImport("user32.dll")] internal static partial nint CreatePopupMenu();
    [LibraryImport("user32.dll", EntryPoint = "AppendMenuW", StringMarshalling = StringMarshalling.Utf16)] [return: MarshalAs(UnmanagedType.Bool)] internal static partial bool AppendMenu(nint menu, uint flags, nuint identifier, string text);
    [LibraryImport("user32.dll")] internal static partial uint TrackPopupMenu(nint menu, uint flags, int x, int y, int reserved, nint window, nint rectangle);
    [LibraryImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] internal static partial bool DestroyMenu(nint menu);
}
