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
- Bren 使用 ScreenCaptureKit 将面板区域低分辨率采样为单个相对亮度值；深背景使用纯白前景，浅背景使用纯黑前景。
- 黑白切换围绕 WCAG 对比度交点设置双阈值滞回，拖动或流式变形时不会在临界背景上闪烁。
- 采样帧只在本机内存中计算中位亮度，不保存，也不发送给翻译后端；未授权屏幕读取时退回系统外观。
- 不绘制固定渐变、伪折射、高光边框或第二层玻璃。
- 不设置品牌 tint；背景颜色、动态范围、高光与阴影由系统根据桌面内容决定。
- 遵从 Reduce Transparency、Increase Contrast 和 Reduce Motion。

## Information hierarchy

原文已经存在于当前应用的选区中，因此结果面板不重复显示原文、来源、模型、耗时、快捷键说明或 Bren 品牌。默认状态只包含译文。

固定、复制和关闭使用 SF Symbols；静止时保持低视觉权重，悬停时增强。固定后，点击面板外不会自动消散。键盘用户可以使用 `⌘C` 和 `Esc`。

## State and motion

```text
hidden
  → 44×44 loading droplet
  → first token morphs into adaptive result module
  → streaming text grows the module from its fixed top edge
  → hover strengthens actions
  → outside click fades and subtly recedes unless pinned
```

几何动画使用 0.14–0.36 秒的分层节奏；SwiftUI 内容使用带阻尼的 spring transition。启用 Reduce Motion 时，AppKit 几何动画立即完成。

## Geometry

- loading：44×44pt 圆形
- result width：220–420pt，按文字视觉列宽计算
- result height：76–220pt，超出后内部滚动
- result corner radius：24pt
- content inset：15–16pt
- 面板在光标旁出现，始终限制在当前屏幕 visible frame 内
- 拖动按钮之外的任意区域移动整个玻璃面板；流式增长时保持拖动后的位置和顶部边缘
