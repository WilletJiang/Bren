using System.Text;
using System.Runtime.InteropServices;

namespace Bren.Windows.Core;

/// <summary>Incrementally frames UTF-8 JSONL without decoding partial characters.</summary>
internal sealed class JsonlLineReader
{
    private readonly List<byte> pending = [];

    internal IReadOnlyList<string> Append(ReadOnlySpan<byte> chunk)
    {
        pending.AddRange(chunk.ToArray());
        var lines = new List<string>();
        var start = 0;
        for (var index = 0; index < pending.Count; index++)
        {
            if (pending[index] != (byte)'\n') continue;
            var length = index - start;
            if (length > 0 && pending[index - 1] == (byte)'\r') length--;
            lines.Add(Encoding.UTF8.GetString(CollectionsMarshal.AsSpan(pending).Slice(start, length)));
            start = index + 1;
        }

        if (start > 0) pending.RemoveRange(0, start);
        return lines;
    }

    internal bool HasIncompleteLine => pending.Count > 0;
}
