# Architecture

## Objective

Bren 的首要契约是：平台 UI 永远不感知 Codex app-server 的具体协议。app-server 仍在演进，三套原生客户端不应因此同步改动。

```text
macOS / Windows / Linux native UI
                │
        Bren JSONL v1 / stdio
                │
            bren-core
      ┌─────────┼─────────┐
  transport  translation  appserver adapter
                             │
                    Codex app-server
                             │
                           OpenAI
```

## Boundaries

### Platform clients

平台端负责选区捕获、全局快捷键、窗口、动画、无障碍和本地交互。它们只发送 Bren `translate`/`cancel`/`health` 请求并消费稳定事件。

### bren-core

Go 核心负责：

- 发现 Codex CLI
- 启动并维持一个 app-server 子进程
- 完成 `initialize`/`initialized` 握手
- 维持一个临时、只读、只承载真实用户请求的翻译 thread
- 把 app-server delta、完成、失败和中断转换为 Bren v1 事件
- 自动取消被新请求取代的翻译
- 对单次翻译施加 30 秒上限，避免后端异常时呈现为无限加载
- `turn/start` 和 turn gate 均继承调用方 context，不允许已取消请求继续占锁
- 中断后等待 app-server 确认旧 turn 结束，再释放 turn gate
- UI 将等待 core 接单与等待模型首字分开计时，不静默重复用户请求

### Codex adapter

`core/internal/appserver` 是唯一允许理解 `thread/start`、`turn/start`、`item/agentMessage/delta` 和 `turn/completed` 的包。未来协议变化只能影响这里。

### Updates

macOS 客户端通过 Sparkle 2.9.6 读取 GitHub Releases 中的 `appcast.xml`。更新 ZIP 使用独立 EdDSA 密钥签名；公钥嵌入 App，私钥只保存在本机 Keychain 和 GitHub Actions Secret。tag workflow 在 `macos-26` 上测试、构建、签名并发布自包含 Release。

## Runtime choices

- 默认模型：`gpt-5.6-luna`
- reasoning effort：`low`
- service tier：`priority`（Fast）
- app-server transport：默认 stdio JSONL
- thread：单个常驻 `ephemeral` thread
- sandbox：`read-only`
- approval policy：`never`
- model tools：通过 developer instruction 禁止用于翻译
- agent surface：以翻译专用 base instructions 替换默认编程代理指令，并将 environments、capability roots、dynamic tools、apps、plugins、skill search、shell tool 与 `node_repl` MCP 置空或关闭

不发送会污染上下文或阻塞 stdin 的合成预热请求。首次真实翻译承担 thread 冷启动成本，后续 turn 复用同一 ephemeral thread 的热连接；每个 turn 仍显式携带独立翻译命令。

## Future platforms

Windows 和 Linux 只需要实现 Bren v1 客户端及各自原生交互层。跨平台共用逻辑应进入 core；窗口材质、权限、选区读取和快捷键必须留在平台目录。不会为了代码复用而牺牲 WinUI 3 或 libadwaita 的原生行为。
