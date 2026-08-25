namespace Bren.Windows.Application;

internal static class Log
{
    private static readonly object Gate = new();
    private static readonly string DirectoryPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Bren", "logs");

    internal static void Write(string message)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(DirectoryPath);
                File.AppendAllText(Path.Combine(DirectoryPath, "bren.log"), $"{DateTimeOffset.UtcNow:O} {message}{Environment.NewLine}");
            }
        }
        catch { /* Diagnostics must never stop translation. */ }
    }
}
