using System.Text;
using System.Text.Json;
using Bren.Windows.Core;
using Xunit;

namespace Bren.Windows.Tests;

public sealed class CoreTests
{
    [Fact]
    public void FramesEveryByteBoundaryIncludingUnicodeAndCrLf()
    {
        var payload = "{\"v\":1,\"event\":\"ready\"}\r\n{\"v\":1,\"id\":\"a\",\"event\":\"delta\",\"data\":{\"text\":\"你\"}}\n";
        var bytes = Encoding.UTF8.GetBytes(payload);
        for (var split = 1; split < bytes.Length; split++)
        {
            var reader = new JsonlLineReader();
            var lines = reader.Append(bytes.AsSpan(0, split)).Concat(reader.Append(bytes.AsSpan(split))).ToArray();
            Assert.Equal(2, lines.Length);
            Assert.Equal("你", Protocol.Text(JsonSerializer.Deserialize<CoreEvent>(lines[1], Protocol.Json)!));
            Assert.False(reader.HasIncompleteLine);
        }
    }

    [Fact]
    public void KeepsMultipleRecordsAndIncompleteTailSeparate()
    {
        var reader = new JsonlLineReader();
        Assert.Equal(new[] { "one", "two" }, reader.Append(Encoding.UTF8.GetBytes("one\ntwo\npartial")));
        Assert.True(reader.HasIncompleteLine);
    }

    [Fact]
    public void StateRejectsEventsForStaleRequests()
    {
        var state = new TranslationSession();
        state.Begin("new");
        Assert.False(state.Delta("old", "stale"));
        Assert.True(state.Started("new"));
        Assert.True(state.Delta("new", "visible"));
        Assert.True(state.Completed("new", "final"));
        Assert.Equal(TranslationPhase.Completed, state.Phase);
        Assert.Equal("final", state.Text);
    }
}
