# Bren

Bren 是一个个人使用的原生桌面翻译工具。首个纵向切片面向 macOS：选中文本，按 `⌥D`，在光标旁获得由 Codex app-server 和 `gpt-5.6-luna` 流式生成的中英自动翻译。

## 安装与更新

从 [GitHub Releases](https://github.com/WilletJiang/Bren/releases/latest) 下载并把 `Bren.app` 放入 `/Applications`。Bren 使用 Sparkle 2.9.6 验证 EdDSA 签名的更新，默认每天检查并在可行时后台安装；菜单栏提供“检查更新…”。

## 当前能力

- Accessibility API 读取当前选区，失败时回退剪贴板
- Carbon 全局快捷键 `⌥D`
- AppKit `NSPanel` + `NSGlassEffectView` 原生 Liquid Glass
- 44pt 加载液滴到自适应结果模块的几何 morph
- 流式输出、固定/复制/关闭、点外部自动消散、`⌘C`、`Esc` 与整面板拖动
- Go 核心常驻并管理 Codex app-server、取消、超时与协议隔离
- 启动后在 ephemeral thread 内后台预热 Luna 的中英双向路径；真实请求使用已热 thread
- 临时 Codex thread、只读沙箱、无屏幕捕获

## 要求

- macOS 26 或更新版本
- Xcode 26
- Go 1.24 或更新版本
- 已安装并登录的 Codex CLI

Bren 会依次从 `PATH`、`~/.local/bin`、Homebrew 常见路径寻找 `codex`。也可以设置 `BREN_CODEX_PATH`。

## 构建与运行

```sh
make test
make build
open dist/Bren.app
```

首次启动会请求辅助功能权限。授权后，在任意应用中选择文本并按 `⌥D`。如果暂未授权，Bren 仍可翻译剪贴板中的文本。

仅查看玻璃和动画，不调用模型：

```sh
make preview
```

## 目录

```text
core/
  cmd/bren-core/          可执行入口
  internal/appserver/     Codex app-server 适配器
  internal/protocol/      Bren 稳定消息模型
  internal/translation/   输入约束与翻译服务
  internal/transport/     JSONL / stdio 服务
platforms/
  macos/
    Sources/Bren/
      Application/        生命周期与菜单栏
      Core/               Swift 端核心客户端
      HotKey/             全局快捷键
      Overlay/            Liquid Glass 与动画
      Selection/          选区读取
docs/
  architecture.md
  design.md
  protocol.md
```

Windows 的 WinUI 3 客户端和 Linux 的 GTK4/libadwaita 客户端会共享同一份 Bren 协议；当前没有为尚未实现的平台保留空壳目录。

## 已知边界

- Codex app-server 仍是实验性接口，因此只有 Go 适配器可以依赖它的消息结构。
- Luna 使用 app-server 公布的 `priority` Fast tier；实际首 token 延迟仍受账户和服务状态影响。Bren 不做会阻塞真实请求的合成预热，也不静默重复请求；首字等待 15 秒、核心单次翻译上限 30 秒。
- 很短的译文可能由模型作为单个 delta 一次性发出；长文本仍按 app-server delta 流式展示。
- 当前只做文本翻译，不在磁盘保存历史、不做 OCR。为选择纯黑或纯白文字，macOS 客户端只在本机低分辨率采样面板区域并立即归约为亮度，不保存或上传屏幕内容。

更多细节见 [架构](docs/architecture.md)、[视觉设计](docs/design.md) 和 [协议](docs/protocol.md)。
