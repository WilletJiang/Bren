using System.Runtime.InteropServices;
using Bren.Windows.Interop;

namespace Bren.Windows.Overlay;

internal static partial class BackdropLuminanceSampler
{
    /// <summary>Samples a small grid before presentation. Pixel values never leave this method.</summary>
    internal static double? Sample(PixelRect panel)
    {
        var desktop = GetDC(0);
        if (desktop == 0) return null;
        try
        {
            var samples = new List<(byte R, byte G, byte B)>();
            for (var row = 1; row <= 12; row++)
            for (var column = 1; column <= 12; column++)
            {
                var color = GetPixel(desktop, panel.X + panel.Width * column / 13, panel.Y + panel.Height * row / 13);
                if (color == 0xFFFF_FFFF) continue;
                samples.Add(((byte)(color & 0xFF), (byte)((color >> 8) & 0xFF), (byte)((color >> 16) & 0xFF)));
            }
            return samples.Count == 0 ? null : BackdropContrast.MedianRelativeLuminance(samples);
        }
        finally { ReleaseDC(0, desktop); }
    }

    [LibraryImport("user32.dll")] private static partial nint GetDC(nint hwnd);
    [LibraryImport("user32.dll")] private static partial int ReleaseDC(nint hwnd, nint hdc);
    [LibraryImport("gdi32.dll")] private static partial uint GetPixel(nint hdc, int x, int y);
}
