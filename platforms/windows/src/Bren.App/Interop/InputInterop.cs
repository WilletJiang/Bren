using System.Runtime.InteropServices;

namespace Bren.Windows.Interop;

internal static partial class InputInterop
{
    internal const uint InputKeyboard = 1;
    internal const uint KeyEventFKeyUp = 0x0002;
    internal const ushort VkControl = 0x11;
    internal const ushort VkC = 0x43;

    [StructLayout(LayoutKind.Sequential)] internal struct Input { public uint Type; public InputUnion Data; }
    [StructLayout(LayoutKind.Explicit)] internal struct InputUnion { [FieldOffset(0)] public KeyboardInput Keyboard; }
    [StructLayout(LayoutKind.Sequential)] internal struct KeyboardInput { public ushort Vk; public ushort Scan; public uint Flags; public uint Time; public nint ExtraInfo; }

    [LibraryImport("user32.dll", SetLastError = true)]
    internal static partial uint SendInput(uint inputCount, [In] Input[] inputs, int size);

    internal static bool SendCopy()
    {
        var input = new[]
        {
            Key(VkControl, 0), Key(VkC, 0), Key(VkC, KeyEventFKeyUp), Key(VkControl, KeyEventFKeyUp),
        };
        return SendInput((uint)input.Length, input, Marshal.SizeOf<Input>()) == input.Length;
    }

    private static Input Key(ushort key, uint flags) => new() { Type = InputKeyboard, Data = new InputUnion { Keyboard = new KeyboardInput { Vk = key, Flags = flags } } };
}
