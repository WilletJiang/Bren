using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

internal static partial class ForegroundInterop
{
    private const uint ProcessQueryLimitedInformation = 0x1000;
    private const uint TokenQuery = 0x0008;
    private const int TokenElevationClass = 20;

    [StructLayout(LayoutKind.Sequential)] private struct TokenElevation { public int Elevated; }

    [LibraryImport("user32.dll")] internal static partial nint GetForegroundWindow();
    [LibraryImport("user32.dll")] internal static partial uint GetWindowThreadProcessId(nint window, out uint processId);
    [LibraryImport("kernel32.dll", SetLastError = true)] private static partial nint OpenProcess(uint access, bool inheritHandle, uint processId);
    [LibraryImport("advapi32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool OpenProcessToken(nint process, uint access, out nint token);
    [LibraryImport("advapi32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool GetTokenInformation(nint token, int informationClass, out TokenElevation tokenInformation, int tokenInformationLength, out int returnLength);
    [LibraryImport("kernel32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static partial bool CloseHandle(nint handle);

    internal static bool IsForegroundElevated()
    {
        var window = GetForegroundWindow();
        if (window == 0) return false;
        GetWindowThreadProcessId(window, out var pid);
        var process = OpenProcess(ProcessQueryLimitedInformation, false, pid);
        if (process == 0) return false;
        try
        {
            if (!OpenProcessToken(process, TokenQuery, out var token)) return false;
            try
            {
                return GetTokenInformation(token, TokenElevationClass, out var elevation, Marshal.SizeOf<TokenElevation>(), out _) && elevation.Elevated != 0;
            }
            finally { CloseHandle(token); }
        }
        finally { CloseHandle(process); }
    }
}
