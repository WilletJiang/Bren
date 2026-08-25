using System.Text.Json;
using System.Text.Json.Serialization;

namespace Bren.Windows.Core;

internal sealed record CoreEvent(
    [property: JsonPropertyName("v")] int Version,
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("event")] string? Event,
    [property: JsonPropertyName("data")] JsonElement? Data,
    [property: JsonPropertyName("error")] CoreError? Error);

internal sealed record CoreError(
    [property: JsonPropertyName("code")] string? Code,
    [property: JsonPropertyName("message")] string? Message,
    [property: JsonPropertyName("retryable")] bool Retryable);

internal static class Protocol
{
    internal const int Version = 1;
    internal const int MaxCodePoints = 12_000;
    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    internal static string Translate(string id, string text) => JsonSerializer.Serialize(new
    {
        v = Version, id, method = "translate", @params = new { text },
    }, Json);

    internal static string Cancel(string id, string requestId) => JsonSerializer.Serialize(new
    {
        v = Version, id, method = "cancel", @params = new { requestId },
    }, Json);

    internal static bool IsValidText(string text) =>
        !string.IsNullOrWhiteSpace(text) && text.EnumerateRunes().Count() <= MaxCodePoints;

    internal static string? Text(CoreEvent item) =>
        item.Data is { } data && data.TryGetProperty("text", out var text) ? text.GetString() : null;
}
