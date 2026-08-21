namespace Bren.Windows.Overlay;

internal enum ForegroundTone { Black, White }

internal static class BackdropContrast
{
    internal static ForegroundTone Foreground(double luminance, ForegroundTone? current)
    {
        var clamped = Math.Clamp(luminance, 0d, 1d);
        return current switch
        {
            ForegroundTone.White when clamped > .23 => ForegroundTone.Black,
            ForegroundTone.Black when clamped < .14 => ForegroundTone.White,
            { } tone => tone,
            _ => clamped > .179 ? ForegroundTone.Black : ForegroundTone.White,
        };
    }

    internal static double MedianRelativeLuminance(IEnumerable<(byte R, byte G, byte B)> pixels)
    {
        var values = pixels.Select(pixel => .2126 * Linear(pixel.R) + .7152 * Linear(pixel.G) + .0722 * Linear(pixel.B)).Order().ToArray();
        if (values.Length == 0) throw new ArgumentException("At least one pixel is required.", nameof(pixels));
        return values[values.Length / 2];
    }

    private static double Linear(byte component)
    {
        var sRgb = component / 255d;
        return sRgb <= .04045 ? sRgb / 12.92 : Math.Pow((sRgb + .055) / 1.055, 2.4);
    }
}
