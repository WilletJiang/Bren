# Bren

[简体中文](README.zh-CN.md)

Bren is a native desktop translation utility. The platform application reads the current text selection, or accepts text entered directly, and presents streamed output in a compact non-document window near the pointer. The implemented client targets macOS 26 with SwiftUI and AppKit. Windows is the next native client and must ship for both x64 and ARM64.

## Architecture

Platform code never talks to Codex app-server directly. Every client launches the same Go executable and exchanges one JSON object per line over standard input and standard output. `bren-core` owns the evolving app-server protocol, the persistent ephemeral translation thread, cancellation, timeouts, model configuration, and the conversion of upstream events into Bren JSONL v1. Platform code owns selection capture, shortcuts, window behavior, animation, background contrast, installation, and updates.

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

The core keeps stdout protocol-only and sends diagnostics to stderr. A translation produces `started`, zero or more `delta` events, and one terminal `completed`, `cancelled`, or `error` event. New requests cancel any active request. The client starts a 20-second acceptance watchdog before `started` and a 15-second first-token watchdog after `started`; it never silently repeats a user request. The core applies a 30-second translation deadline. The complete wire contract is in [docs/protocol.md](docs/protocol.md).

The default backend is `gpt-5.6-luna` with low reasoning effort and the priority service tier. The app-server thread uses a translation-only base instruction, a read-only sandbox, no approval prompts, and no model-visible apps, plugins, skills, shell tools, environments, or `node_repl` MCP server. Bren does not issue synthetic warm-up turns because they block real input and contaminate the thread history. The first translation pays the cold-thread cost; later turns reuse the same in-memory thread.

## macOS implementation

The macOS client is an accessory application without a normal Dock window. Carbon registers `⌥D`. Selection capture first reads `kAXSelectedTextAttribute`; if the focused application does not expose selected text, Bren posts a real copy command, waits for the pasteboard change count to advance, reads only the new value, and restores the original pasteboard. An unchanged pasteboard is never treated as selected text; instead, the same shortcut opens a focused input panel where Return translates and Shift-Return inserts a line break.

The overlay is an AppKit `NSPanel` containing one clear `NSGlassEffectView` and a SwiftUI content tree. It remains above normal application windows, moves from an invisible top-center hot region, resizes from an invisible bottom-right hot corner, disappears after an outside click unless pinned, and grows from a 44-point loading orb into a 220–420 point automatic result module. A manual resize can expand it to 720 × 560 points and takes precedence over subsequent streamed geometry changes.

The native glass remains visible beneath a monochrome black gradient whose lightest stop still provides a stable white-text contrast over a white desktop. This deterministic surface replaces screen sampling and removes the Screen Recording permission. Output is plain selectable text with native rendering for inline and display LaTeX delimiters; Markdown formatting is intentionally not interpreted.

The macOS release embeds Sparkle 2.9.6. GitHub Releases hosts the app archive and appcast, update archives carry EdDSA signatures, and the app checks automatically once per day. The private key exists only in the local Keychain and the repository Actions secret. The current build is ad-hoc code signed for personal use; public distribution to unrelated machines would additionally require Developer ID signing and notarization.

## Building

macOS development requires macOS 26, Xcode 26, Go 1.24 or newer, and an installed Codex or ChatGPT application with an authenticated Codex CLI. The build prefers the Codex executable bundled in ChatGPT, then checks `PATH` and common local installation paths. `BREN_CODEX_PATH` is the explicit override.

```sh
make test
make build
open dist/Bren.app
```

`make test` runs Go tests and vet, fetches the checksum-pinned Sparkle 2.9.6 XCFramework, resolves the version-locked LaTeX renderer, and runs the Swift test suites. `make build` produces `dist/Bren.app`, embeds `bren-core`, Sparkle, and the local formula resources, sets the required runtime paths, and verifies the bundle structure. `make preview` renders the overlay without invoking a model.

The installed release is available from [GitHub Releases](https://github.com/WilletJiang/Bren/releases/latest). Development releases are created from semantic version tags by `.github/workflows/release.yml`; the workflow tests on macOS 26, builds a versioned archive, signs the Sparkle update, and publishes the archive with its appcast.

## Repository layout

`core` contains the platform-neutral Go process, with separate packages for the stable Bren protocol, transport, translation validation, and Codex app-server RPC. `platforms/macos` contains only macOS lifecycle, process transport, hotkey, selection, overlay, and update code. `docs` records the architecture, protocol, visual rules, and release notes. Shared behavior belongs in `core`; operating-system APIs stay under the corresponding platform directory.

The Windows client must preserve this boundary instead of translating the Swift implementation line by line. Its required architecture matrix is `win-x64` and `win-arm64`; 32-bit `win-x86` is not an initial target.
