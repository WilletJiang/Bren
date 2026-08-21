using Bren.Windows.Interop;
using Bren.Windows.Overlay;
using Xunit;

namespace Bren.Windows.Tests;

public sealed class OverlayTests
{
    [Fact]
    public void ContrastUsesOnlyBlackAndWhiteWithHysteresis()
    {
        Assert.Equal(ForegroundTone.White, BackdropContrast.Foreground(0.0, null));
        Assert.Equal(ForegroundTone.Black, BackdropContrast.Foreground(1.0, null));
        Assert.Equal(ForegroundTone.White, BackdropContrast.Foreground(.20, ForegroundTone.White));
        Assert.Equal(ForegroundTone.Black, BackdropContrast.Foreground(.24, ForegroundTone.White));
        Assert.Equal(ForegroundTone.Black, BackdropContrast.Foreground(.20, ForegroundTone.Black));
        Assert.Equal(ForegroundTone.White, BackdropContrast.Foreground(.13, ForegroundTone.Black));
    }

    [Fact]
    public void PlacesAndClampsOnNegativeCoordinateMonitor()
    {
        var work = new RectInt { Left = -1920, Top = 0, Right = 0, Bottom = 1080 };
        var panel = OverlayGeometry.Place(new PointInt { X = -10, Y = 1060 }, new PixelSize(320, 220), work);
        Assert.InRange(panel.X, work.Left, work.Right - panel.Width);
        Assert.InRange(panel.Y, work.Top, work.Bottom - panel.Height);
    }
}
