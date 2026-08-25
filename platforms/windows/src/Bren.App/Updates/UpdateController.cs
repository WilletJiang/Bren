using Velopack;
using Velopack.Sources;
using Bren.Windows.Application;

namespace Bren.Windows.Updates;

internal sealed class UpdateController
{
    private readonly UpdateManager manager;
    private VelopackAsset? ready;

    internal UpdateController()
    {
        var channel = Environment.Is64BitProcess && System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture == System.Runtime.InteropServices.Architecture.Arm64 ? "win-arm64" : "win-x64";
        manager = new UpdateManager(new GithubSource("https://github.com/WilletJiang/Bren", null, false), new UpdateOptions { ExplicitChannel = channel });
    }

    internal async Task CheckInBackgroundAsync()
    {
        try
        {
            var update = await manager.CheckForUpdatesAsync().ConfigureAwait(false);
            if (update is null) return;
            await manager.DownloadUpdatesAsync(update).ConfigureAwait(false);
            ready = update.TargetFullRelease;
        }
        catch (Exception exception) { Log.Write($"Update check failed: {exception.Message}"); }
    }

    internal bool RestartToApply()
    {
        if (ready is null) return false;
        manager.ApplyUpdatesAndRestart(ready);
        return true;
    }
}
