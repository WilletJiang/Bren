using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using WinRT.Interop;
using System.Runtime.InteropServices;
using Bren.Windows.Application;
using Windows.Graphics;
using Windows.UI;
using Bren.Windows.Interop;

namespace Bren.Windows.Overlay;

internal sealed class OverlayController
{
    private readonly Window window = new();
    private readonly Grid root = new();
    private readonly Border panel = new();
    private readonly TextBlock text = new();
    private readonly ProgressRing loading = new() { Width = 44, Height = 44, IsActive = true };
    private readonly StackPanel commands = new() { Orientation = Orientation.Horizontal, Spacing = 2, HorizontalAlignment = HorizontalAlignment.Right };
    private readonly DispatcherTimer contrastTimer = new() { Interval = TimeSpan.FromMilliseconds(750) };
    private ForegroundTone foreground = ForegroundTone.White;
    private readonly OutsideClickMonitor outsideClicks;
    private PixelRect geometry;
    private bool pinned;
    internal event Action? Dismissed;
    internal event Action? CopyRequested;
    internal event Action? CancelRequested;

    internal OverlayController()
    {
        panel.Background = new SolidColorBrush(Colors.Transparent);
        panel.BorderBrush = new SolidColorBrush(Color.FromArgb(70, 255, 255, 255));
        panel.BorderThickness = new Thickness(1);
        panel.CornerRadius = new CornerRadius(24);
        panel.Padding = new Thickness(16, 12, 16, 12);
        root.Children.Add(panel);
        panel.Child = loading;
        window.Content = root;
        window.SystemBackdrop = new DesktopAcrylicBackdrop();
        window.Closed += (_, _) => Dismissed?.Invoke();
        contrastTimer.Tick += (_, _) => { if (pinned) RefreshContrast(); };
        ConfigureNativeWindow();
        outsideClicks = new OutsideClickMonitor(WindowHandle, Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread() ?? throw new InvalidOperationException("UI dispatcher is unavailable."), () => { if (!pinned) Dismiss(); });
    }

    internal void Begin()
    {
        pinned = false;
        loading.IsActive = true;
        panel.Child = loading;
        commands.Visibility = Visibility.Collapsed;
        MoveToCursor(new PixelSize(DipToPixels(44), DipToPixels(44)));
        FadeTo(1);
        contrastTimer.Start();
        outsideClicks.Start();
    }

    internal void Append(string value) { ShowText(value, false); }
    internal void Complete(string value) { ShowText(value, true); }
    internal void Fail(string message) { ShowText(message, true); }
    internal void TogglePinned() { pinned = !pinned; if (pinned) outsideClicks.Stop(); else outsideClicks.Start(); }

    internal void Dismiss()
    {
        contrastTimer.Stop();
        outsideClicks.Stop();
        CancelRequested?.Invoke();
        root.Opacity = 0;
        WindowInterop.ShowWindow(WindowHandle, 0);
        Dismissed?.Invoke();
    }

    private void ShowText(string value, bool complete)
    {
        loading.IsActive = false;
        text.Text = value;
        text.TextWrapping = TextWrapping.Wrap;
        text.Foreground = new SolidColorBrush(foreground == ForegroundTone.Black ? Colors.Black : Colors.White);
        var content = new Grid();
        content.RowDefinitions.Add(new RowDefinition());
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        content.Children.Add(text);
        Grid.SetRow(commands, 1);
        commands.Visibility = complete ? Visibility.Visible : Visibility.Collapsed;
        if (complete && commands.Children.Count == 0) AddCommands();
        content.Children.Add(commands);
        panel.Child = content;
        var charsPerLine = 38;
        var lines = Math.Max(1, (int)Math.Ceiling(value.Length / (double)charsPerLine));
        var widthDip = Math.Clamp(220 + Math.Min(value.Length, 180) * 2, 220, 420);
        var heightDip = Math.Clamp(76 + lines * 24, 76, 220);
        var size = new PixelSize(DipToPixels(widthDip), DipToPixels(heightDip));
        ResizeKeepingTop(size);
    }

    private void AddCommands()
    {
        commands.Children.Add(Button("Pin", (_, _) => TogglePinned()));
        commands.Children.Add(Button("Copy", (_, _) => CopyRequested?.Invoke()));
        commands.Children.Add(Button("Close", (_, _) => Dismiss()));
    }

    private static Button Button(string label, RoutedEventHandler click)
    {
        var button = new Button { Content = label, Padding = new Thickness(6, 2, 6, 2), FontSize = 12 };
        button.Click += click;
        return button;
    }

    private void ConfigureNativeWindow()
    {
        var style = WindowInterop.GetWindowLongPtr(WindowHandle, WindowInterop.GwlExStyle);
        WindowInterop.SetWindowLongPtr(WindowHandle, WindowInterop.GwlExStyle, style | WindowInterop.WsExToolWindow | WindowInterop.WsExNoActivate);
    }

    private nint WindowHandle => WindowNative.GetWindowHandle(window);

    private void MoveToCursor(PixelSize size)
    {
        WindowInterop.GetCursorPos(out var cursor);
        var monitor = WindowInterop.MonitorFromPoint(cursor, WindowInterop.MonitorDefaultToNearest);
        var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        if (!WindowInterop.GetMonitorInfo(monitor, ref info)) return;
        geometry = OverlayGeometry.Place(cursor, size, info.Work);
        RefreshContrast();
        Move(geometry);
        WindowInterop.SetWindowPos(WindowHandle, WindowInterop.HwndTopmost, geometry.X, geometry.Y, geometry.Width, geometry.Height, WindowInterop.SwpNoActivate);
        WindowInterop.ShowWindow(WindowHandle, WindowInterop.SwShownoactivate);
    }

    private void ResizeKeepingTop(PixelSize size)
    {
        geometry = geometry with { Width = size.Width, Height = size.Height };
        Move(geometry);
        RefreshContrast();
    }

    private void Move(PixelRect target)
    {
        var appWindow = AppWindow.GetFromWindowId(Win32Interop.GetWindowIdFromWindow(WindowHandle));
        appWindow.MoveAndResize(new RectInt32(target.X, target.Y, target.Width, target.Height));
        WindowInterop.SetWindowPos(WindowHandle, WindowInterop.HwndTopmost, target.X, target.Y, target.Width, target.Height, WindowInterop.SwpNoActivate);
    }

    private void RefreshContrast()
    {
        if (BackdropLuminanceSampler.Sample(geometry) is { } luminance) foreground = BackdropContrast.Foreground(luminance, foreground);
        text.Foreground = new SolidColorBrush(foreground == ForegroundTone.Black ? Colors.Black : Colors.White);
    }

    private void FadeTo(double opacity) => root.Opacity = opacity;
    private int DipToPixels(double dip) => (int)Math.Round(dip * WindowInterop.GetDpiForWindow(WindowHandle) / 96d);
}

internal static class FluentButton
{
    internal static T Also<T>(this T value, Action<T> action) { action(value); return value; }
}
