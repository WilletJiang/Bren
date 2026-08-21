# macOS Design

## Reference

Bren 直接采用 Apple 的公开 Liquid Glass 实现与设计原则：

- [Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)
- [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310/)
- [`NSGlassEffectView`](https://developer.apple.com/documentation/appkit/nsglasseffectview)

## Material rules

- 悬浮翻译结果是桌面之上的单一功能层，适合 Liquid Glass。
- 使用一个高透明的 `NSGlassEffectView(.clear)`，并把 SwiftUI hosting view 设为它的 `contentView`。
- clear glass 上只叠加一层没有色相的黑色渐变，透明度范围为 0.70–0.82；即使底层是纯白，纯白文字仍保持稳定对比度。
- 不再使用屏幕录制采样。旧实现会在面板显示后截取同一矩形，采样结果包含 Bren 自身玻璃，无法代表真正的底层背景。
- 不绘制冷暖双色、伪折射、彩色 tint 或第二层玻璃；黑色渐变只是保证可读性的单色遮罩。
- 遵从 Reduce Transparency、Increase Contrast 和 Reduce Motion。

## Information hierarchy

原文已经存在于当前应用的选区中，因此结果面板不重复显示原文、来源、模型、耗时、快捷键说明或 Bren 品牌。默认状态只包含译文。

固定、复制和关闭使用 SF Symbols；静止时完全隐藏，悬停时出现，固定后保持可见。固定后，点击面板外不会自动消散。键盘用户可以使用 `⌘C` 和 `Esc`。顶部中央使用 48×16pt 透明移动热区，右下角使用 22×22pt 透明缩放热区，面板不绘制拖动柄或缩放图标，也不会吞掉文字选择和输入事件。

同一个 `⌥D` 同时覆盖两条路径：存在选区时直接翻译；无法读取选区时进入输入态。输入态回车提交，`Shift+Enter` 换行。输出保持普通文本，只识别 `$…$`、`$$…$$`、`\(…\)`、`\[…\]` 和标准 LaTeX equation environment，不解析 Markdown。

## State and motion

```text
hidden
  → 44×44 loading droplet
  → first token morphs into result module
  → streaming text grows the module from its fixed top edge
  → hover strengthens actions
  → outside click fades and subtly recedes unless pinned
```

几何动画使用 0.14–0.36 秒的分层节奏；SwiftUI 内容使用带阻尼的 spring transition。启用 Reduce Motion 时，AppKit 几何动画立即完成。

## Geometry

- loading：44×44pt 圆形
- result width：220–420pt，按文字视觉列宽计算
- result height：76–220pt，超出后内部滚动
- manual resize：220×76pt 到 720×560pt
- result corner radius：24pt
- content inset：15–16pt
- 面板在光标旁出现，始终限制在当前屏幕 visible frame 内
- 通过顶部透明热区移动面板；通过右下角透明热区连续缩放；流式增长时保持用户指定的位置和尺寸
