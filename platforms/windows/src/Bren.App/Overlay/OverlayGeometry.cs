using Bren.Windows.Interop;

namespace Bren.Windows.Overlay;

internal readonly record struct PixelSize(int Width, int Height);
internal readonly record struct PixelRect(int X, int Y, int Width, int Height);

internal static class OverlayGeometry
{
    internal static PixelRect Place(PointInt cursor, PixelSize size, RectInt workArea, int gap = 12)
    {
        var x = cursor.X + gap;
        var y = cursor.Y + gap;
        if (x + size.Width > workArea.Right) x = cursor.X - gap - size.Width;
        if (y + size.Height > workArea.Bottom) y = cursor.Y - gap - size.Height;
        return Clamp(new PixelRect(x, y, size.Width, size.Height), workArea);
    }

    internal static PixelRect Clamp(PixelRect panel, RectInt work)
    {
        var width = Math.Min(panel.Width, Math.Max(1, work.Right - work.Left));
        var height = Math.Min(panel.Height, Math.Max(1, work.Bottom - work.Top));
        return new PixelRect(
            Math.Clamp(panel.X, work.Left, work.Right - width),
            Math.Clamp(panel.Y, work.Top, work.Bottom - height), width, height);
    }
}
