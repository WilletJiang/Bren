namespace Bren.Windows.Core;

internal static class CoreLocator
{
    internal static string Resolve()
    {
        var overridePath = Environment.GetEnvironmentVariable("BREN_CORE_PATH");
        if (!string.IsNullOrWhiteSpace(overridePath) && File.Exists(overridePath)) return overridePath;

        var installed = Path.Combine(AppContext.BaseDirectory, "Helpers", "bren-core.exe");
        if (File.Exists(installed)) return installed;
        throw new FileNotFoundException("Bren core was not found. Reinstall Bren or set BREN_CORE_PATH for development.", installed);
    }
}
