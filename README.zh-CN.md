# Bren

[English](README.md)

Bren 是一个原生桌面翻译工具。平台客户端读取当前文本选区，通过全局快捷键发起翻译，并在指针附近的紧凑非文档窗口中流式显示结果。当前已实现的客户端面向 macOS 26，使用 SwiftUI 与 AppKit。下一步是 Windows 原生客户端，必须同时发布 x64 与 ARM64 版本。

## 架构

平台代码不直接理解 Codex app-server。每个客户端都启动同一个 Go 可执行文件，通过标准输入和标准输出交换逐行 JSON。`bren-core` 负责仍在演进的 app-server 协议、常驻的临时翻译 thread、取消、超时、模型配置，以及把上游事件转换为稳定的 Bren JSONL v1。平台客户端负责选区读取、快捷键、窗口行为、动画、背景对比度、安装和更新。

```text
SwiftUI + AppKit       C# + WinUI 3        GTK4 + libadwaita
        \                   |                    /
                 Bren JSONL v1
                        |
                   bren-core
                        |
                Codex app-server
                        |
                     OpenAI
```

核心的 stdout 只允许承载协议，诊断信息写入 stderr。一次翻译先产生 `started`，随后产生零个或多个 `delta`，最后以 `completed`、`cancelled` 或 `error` 之一结束。新请求会取消仍在执行的旧请求。客户端在 `started` 之前使用 20 秒接单 watchdog，在 `started` 之后使用 15 秒首字 watchdog，但绝不静默重复用户请求；核心的单次翻译上限是 30 秒。完整消息格式见 [docs/protocol.md](docs/protocol.md)。

默认后端是 `gpt-5.6-luna`，reasoning effort 为 low，service tier 为 priority。app-server thread 使用只允许翻译的 base instruction、只读沙箱和 never approval，并关闭模型可见的 apps、plugins、skills、shell、environments 与 `node_repl` MCP。Bren 不发送合成预热请求，因为预热会阻塞真实输入并污染 thread 历史。第一次翻译承担冷启动成本，后续请求复用同一个内存 thread。

## macOS 实现

macOS 客户端是 accessory application，没有普通 Dock 主窗口。Carbon 注册 `⌥D`。选区读取首先请求 `kAXSelectedTextAttribute`；若目标应用没有暴露选中文本，Bren 会发送真实复制命令，等待 pasteboard change count 确实增加，只读取新值，然后恢复原剪贴板。剪贴板未变化时会报错，旧内容永远不会被当成当前选区。

浮层使用 AppKit `NSPanel`，内部只有一个 clear `NSGlassEffectView` 和 SwiftUI 内容树。窗口显示时不夺取焦点，位于普通应用窗口之上，可以从非控件区域拖动；未固定时点击外部会消散。几何从 44pt 加载球过渡到宽 220–420pt 的结果面板。流式文本改变尺寸，但用户拖动后面板顶边保持稳定。

文字颜色只允许纯黑或纯白。ScreenCaptureKit 把面板区域低分辨率采样为中位相对亮度，再以 WCAG 黑白对比度交点和双阈值滞回选择前景色，从而避免拖过临界背景时闪烁。像素只存在于内存中，立即归约成一个数值，不保存，也不发送给翻译后端。因此 macOS 会请求辅助功能和屏幕录制权限。

macOS 版本嵌入 Sparkle 2.9.6。GitHub Releases 保存应用归档和 appcast，更新归档使用 EdDSA 签名，应用默认每天检查一次更新。私钥只存在于本机 Keychain 和仓库的 Actions Secret。当前构建为个人使用的 ad-hoc 签名；若要向其他用户公开分发，还需要 Developer ID 签名和 notarization。

## 构建

macOS 开发需要 macOS 26、Xcode 26、Go 1.24 或更新版本，以及已经安装并登录的 Codex 或 ChatGPT。构建优先使用 ChatGPT 内置的 Codex 可执行文件，然后查找 `PATH` 和常见本地路径；`BREN_CODEX_PATH` 可以显式覆盖。

```sh
make test
make build
open dist/Bren.app
```

`make test` 执行 Go 测试与 vet，获取经过 SHA-256 固定校验的 Sparkle 2.9.6 XCFramework，并执行 Swift 测试。`make build` 生成 `dist/Bren.app`，嵌入 `bren-core` 与 Sparkle，配置运行时搜索路径并验证 bundle。`make preview` 只渲染浮层，不调用模型。

安装包来自 [GitHub Releases](https://github.com/WilletJiang/Bren/releases/latest)。语义版本 tag 会触发 `.github/workflows/release.yml`，远端在 macOS 26 上执行测试、构建版本化归档、签名 Sparkle 更新并发布归档与 appcast。

## 代码组织

`core` 是平台无关的 Go 进程，稳定协议、传输、输入验证和 Codex app-server RPC 分属不同包。`platforms/macos` 只包含 macOS 生命周期、进程传输、热键、选区、浮层和更新代码。`docs` 保存架构、协议、视觉规则与发行说明。能跨平台共享的行为进入 `core`，操作系统 API 必须留在对应平台目录。

Windows 客户端必须保留这条边界，而不是逐行翻译 Swift。首发架构矩阵是 `win-x64` 和 `win-arm64`，暂不包含 32 位 `win-x86`。
