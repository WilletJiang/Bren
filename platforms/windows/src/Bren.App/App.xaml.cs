using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using Velopack;
using Bren.Windows.Application;

namespace Bren.Windows;

public partial class App : Application
{
    private AppCoordinator? coordinator;

    [STAThread]
    public static void Main(string[] args)
    {
        VelopackApp.Build().Run();
        var instance = AppInstance.FindOrRegisterForKey("Bren");
        if (!instance.IsCurrent)
        {
            instance.RedirectActivationToAsync(AppInstance.GetCurrent().GetActivatedEventArgs()).AsTask().GetAwaiter().GetResult();
            return;
        }
        Application.Start(_ => new App());
    }

    public App() => InitializeComponent();

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        base.OnLaunched(args);
        coordinator = new AppCoordinator(Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread() ?? throw new InvalidOperationException("UI dispatcher is unavailable."));
        coordinator.Start();
        AppDomain.CurrentDomain.ProcessExit += (_, _) => coordinator.DisposeAsync().AsTask().GetAwaiter().GetResult();
    }
}
