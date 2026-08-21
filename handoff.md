# Windows implementation handoff

This document is the implementation contract for the native Windows client. The target is behavioral parity with the macOS application, not a source-level port of SwiftUI and AppKit. Keep `bren-core`, Bren JSONL v1, translation semantics, cancellation, and model configuration shared. Rebuild selection capture, the global shortcut, direct text input, the overlay, formula rendering, installation, and updating with Windows-native APIs.

The first Windows release is mandatory for both `win-x64` and `win-arm64`. In casual usage “x86 Windows” often refers to the x86 family while the actual desktop target is 64-bit x64. Do not ship only ARM64, and do not add 32-bit `win-x86` to the initial matrix. A future 32-bit build is mechanically possible only after the Codex dependency and every native package are verified on 32-bit Windows; it is not a substitute for x64.

## Ownership boundary

Most work is in the platform application, but it is not merely a different view layer. Windows needs its own text-selection adapter, shortcut registration, direct-input focus path, HWND behavior, monitor and DPI calculations, formula renderer, tray lifecycle, packaging, and updater. The Go core is already portable and should remain the only code that understands Codex app-server. A small platform-neutral core change is acceptable when Windows exposes a real portability defect, such as executable discovery, but do not fork the protocol or duplicate app-server RPC in C#.

The process graph must remain:

```text
Bren.App.exe
    ├── redirected stdin/stdout/stderr
    └── Helpers/bren-core.exe
            └── codex.exe app-server
```

The Windows client sends and receives Bren JSONL v1 exactly as documented in [docs/protocol.md](docs/protocol.md). It must not call OpenAI over HTTP, parse Codex app-server notifications, or embed credentials. Authentication remains the responsibility of the locally installed Codex client.

## Toolchain and project shape

Use C# and WinUI 3 on Windows 11. The baseline toolchain is Visual Studio 2026, .NET 10, Developer Mode, and the current stable Windows App SDK. At the time of this handoff that stable line is 2.3.1; lock the exact package version in source control and upgrade deliberately. Microsoft documents the current SDK and runtime matrix on the [Windows App SDK downloads page](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads).

Create one solution under `platforms/windows` and preserve the repository boundary instead of placing Windows files at the root:

```text
platforms/windows/
    Bren.Windows.sln
    Directory.Build.props
    src/
        Bren.App/
            App.xaml
            App.xaml.cs
            Bren.App.csproj
            Application/
            Core/
            HotKey/
            Interop/
            Overlay/
            Selection/
            Updates/
    tests/
        Bren.App.Tests/
    scripts/
```

Keep each directory narrow. `Application` owns startup, single-instance behavior, tray lifecycle, and shutdown. `Core` owns the child process and JSONL state machine. `HotKey` owns `RegisterHotKey` and its message window. `Interop` contains small typed P/Invoke declarations grouped by subsystem, not a universal `NativeMethods.cs`. `Overlay` owns window composition, geometry, input, motion, and formula rendering. `Selection` owns UI Automation and the clipboard transaction. `Updates` is the only package allowed to know the updater library. Tests mirror those responsibilities.

Use an unpackaged, self-contained WinUI deployment for the first release. This gives Bren a conventional per-user installer and avoids requiring a separately installed Windows App SDK runtime. The application project should carry the equivalent of:

```xml
<PropertyGroup>
  <OutputType>WinExe</OutputType>
  <TargetFramework>net10.0-windows10.0.26100.0</TargetFramework>
  <RuntimeIdentifiers>win-x64;win-arm64</RuntimeIdentifiers>
  <Platforms>x64;ARM64</Platforms>
  <WindowsPackageType>None</WindowsPackageType>
  <WindowsAppSDKSelfContained>true</WindowsAppSDKSelfContained>
  <SelfContained>true</SelfContained>
  <PublishTrimmed>false</PublishTrimmed>
</PropertyGroup>
```

Do not enable trimming or single-file publishing initially. WinUI, COM, UI Automation, and updater integrations rely on reflection and native assets, and the minor disk saving is not worth opaque release-only failures. Publish the two architectures independently, following Microsoft’s [unpackaged WinUI deployment guidance](https://learn.microsoft.com/windows/apps/package-and-deploy/unpackage-winui-app) and [deployment overview](https://learn.microsoft.com/windows/apps/package-and-deploy/deploy-overview).

## Native core process

Build a native helper for each application architecture. `win-x64` contains a core compiled with `GOOS=windows GOARCH=amd64`; `win-arm64` contains one compiled with `GOOS=windows GOARCH=arm64`. Place it at a deterministic path such as `Helpers\bren-core.exe` next to the application files. Never mix an x64 UI package with an ARM64 helper or rely on emulation when a native build is available.

At startup, launch one long-lived core with `UseShellExecute = false`, redirected stdin, stdout, and stderr, no console window, and UTF-8 without a byte-order mark. Read stdout and stderr concurrently from the moment the process starts. Stdout is protocol-only; stderr is diagnostics and must never be fed into the decoder. A full stderr pipe can deadlock a child process, so draining it is required even when logs are discarded.

Run a continuous `StreamReader.ReadLineAsync(CancellationToken)` loop as soon as the process starts; do not use `ReadToEndAsync`, wait for EOF, or buffer the entire response. A dedicated `StreamReader` correctly preserves fragmented lines and split UTF-8 sequences while returning each completed JSONL record immediately. Parse every returned line before awaiting the next one, and dispatch UI changes through the WinUI dispatcher without blocking either pipe reader. Unit tests must still cover a JSON object split at every byte boundary, multiple objects written in one burst, multibyte Unicode split across writes, CRLF, malformed input, and EOF with an incomplete line.

The client waits for the process-level `ready` event before accepting translation requests. It generates a unique request ID, registers the request state before writing, then sends one complete line and flushes. A translation follows `started`, zero or more `delta` events, and exactly one `completed`, `cancelled`, or `error` terminal event. Ignore unknown fields and unknown events for forward compatibility. Events with an unknown ID are diagnostic noise, never content for the visible request.

The UI has separate deadlines: 20 seconds for the core to accept the request and emit `started`, then 15 seconds for the first non-empty `delta`. The core applies its own 30-second translation deadline. A timeout changes the overlay to an explicit retryable error and cancels the request; it must not submit the same selected text silently. Starting a new translation cancels the currently visible request before registering the new one. Closing an unpinned overlay also sends `cancel` when work is active.

Use an internal state machine rather than scattered booleans. A suitable sequence is `Hidden → Capturing → Input | Starting → Streaming → Completed`, with `Failed` and `Dismissing` as explicit states. Only the state owner may mutate current request ID, input draft, accumulated text, watchdogs, and visibility. Coalesce streamed UI updates to the display cadence instead of measuring and resizing for every token.

Respect `BREN_CORE_PATH` as a development override if it is introduced consistently across clients. Continue to respect `BREN_CODEX_PATH` in the core. Before adding Windows-specific Codex search locations, inspect actual supported installations on x64 and ARM64 Windows; prefer an explicit override and `PATH` to guessed directories. A minimal shared update to `ResolveCodexPath` is correct if verified paths are missing. Hard-coded paths copied from macOS are not.

## Selection capture

Selection must finish before the overlay appears. Showing or activating Bren first changes the focused element and destroys the text selection it is supposed to translate.

The primary path uses UI Automation from an STA-capable component. Resolve the focused element, try `TextPattern2` and `TextPattern`, call `GetSelection`, concatenate non-empty ranges in document order, and trim only outer whitespace. Do not normalize line breaks or punctuation. Cap the result at the core protocol limit of 12,000 Unicode code points and surface a clear error when it exceeds the limit.

Applications that do not expose selection through UI Automation require an active-copy fallback. Treat this as a clipboard transaction, not as a clipboard read:

1. Record `GetClipboardSequenceNumber` and snapshot the complete current clipboard `IDataObject`, including formats that can be restored safely.
2. Send a real `Ctrl+C` input sequence to the already focused application with `SendInput`.
3. Wait up to 750 milliseconds for the clipboard sequence number to change while pumping the STA dispatcher.
4. Read `CF_UNICODETEXT` only after a confirmed change. If the sequence is unchanged, return “no readable selection”; never translate the pre-existing clipboard text.
5. Restore the original clipboard object on a short delayed retry loop because another process may temporarily hold the clipboard.

Keep the transaction serialized so two shortcut presses cannot race. Never clear the user clipboard as an intermediate step. If the active application writes delayed-rendered clipboard formats, preserve what can be restored and document the limitation in a diagnostic log without exposing clipboard contents. When neither UI Automation nor the active-copy transaction yields new text, the same shortcut opens the direct-input panel instead of showing a selection error. Return submits, Shift-Return inserts a line break, and an empty draft cannot be submitted.

Windows integrity levels impose a real boundary: a normal Bren process cannot reliably automate or inspect an elevated application. Do not run Bren as administrator by default, because that broadens risk and causes drag-and-drop and startup problems. When the foreground process is elevated, report that the selected text cannot be read and leave its content untouched.

## Shortcut and process lifecycle

Register only `Alt+D` with Win32 `RegisterHotKey` on a dedicated hidden or message-only HWND. Handle `WM_HOTKEY` on that window and unregister on shutdown. It translates a readable selection and otherwise opens direct input; do not add a second multi-modifier shortcut. Registration failure must be visible in logs and in the tray menu, because another application may own the combination. Do not install a global keyboard hook for a shortcut that `RegisterHotKey` can handle.

Use Windows App SDK `AppInstance` redirection or an equivalent named mutex plus activation handoff to guarantee one running instance. A second launch should signal the resident instance and exit. Bren is a tray utility and must not present a normal main window on startup. Use `Shell_NotifyIcon` directly or a small maintained wrapper for a notification-area icon with Translate, Check for Updates, and Quit commands. Shutdown unregisters the hotkey, removes temporary hooks, cancels the current request, closes core stdin, waits briefly, kills only the owned child if necessary, and removes the tray icon.

## Overlay window and native material

Create the overlay as a WinUI 3 `Window`, obtain its HWND through `WindowNative`, and use `AppWindow` for placement. It must be borderless, absent from Alt-Tab, and topmost while visible. Selection translation is shown without activation by applying `WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE`, `SetWindowPos(HWND_TOPMOST, …, SWP_NOACTIVATE)`, and `ShowWindow(SW_SHOWNOACTIVATE)`. Direct input is the one intentional exception: after selection capture has failed, remove the no-activate behavior for that presentation, focus the editor, and restore the nonactivating style when the request is submitted or dismissed.

Use `DesktopAcrylicBackdrop` as the window-level material, following Microsoft’s [Acrylic guidance](https://learn.microsoft.com/windows/apps/develop/ui/in-app-acrylic). Overlay it with one monochrome black gradient whose opacity stays between 0.70 and 0.82, then use pure white foreground content. Do not screen-capture the desktop, request capture permission, or attempt adaptive black/white switching: the previous macOS implementation sampled its own visible glass and therefore did not measure the underlying background. Do not add cold/warm colors, fake refraction, or a second glass layer. Acrylic still supplies the native backdrop; the gradient is only a deterministic contrast surface.

The panel contains no Bren wordmark, source text, model name, language labels, or permanent status copy. Loading is a 44 × 44 DIP orb. A completed or streaming result is a compact capsule with 15–16 DIP internal padding, approximately 220–420 DIP automatic width and 76–220 DIP automatic height, and a 24 DIP radius. Native edge resizing must allow the user to override that geometry up to 720 × 560 DIP; subsequent deltas preserve the manual size. Show pin, copy, and close only when useful; keep their visual weight below the translation. Copy writes the completed or currently accumulated translation, never the original selection.

Use a small top-center drag handle backed by `WM_NCLBUTTONDOWN` with `HTCAPTION`, leaving selectable output, the editor, buttons, and resize borders interactive. Handle `WM_NCHITTEST` for native edge and corner resizing. Preserve the user’s chosen position and dimensions when streamed content changes. After every resize or drag, clamp the full window to the current monitor work area.

For initial placement, take the physical cursor point, resolve its monitor with `MonitorFromPoint`, read the work area with `GetMonitorInfo`, and place the loading orb slightly below and to the right unless that would clip. Use per-monitor-v2 DPI awareness and convert WinUI DIPs to physical pixels at the target monitor’s scale. On `WM_DPICHANGED`, accept the recommended rectangle and recompute constraints. Test a mixed 100%/150% dual-monitor arrangement with the secondary monitor to the left of the primary, because negative desktop coordinates expose most positioning mistakes.

When unpinned, clicking elsewhere dismisses the overlay with a short dissipating transition. `Deactivated` alone is insufficient because a no-activate window may never become active. Install a temporary low-level mouse hook only while the overlay is visible and combine it with a foreground-window event hook; dismiss when a pointer-down occurs outside the overlay and its menus. Remove hooks immediately after dismissal. Pinned state disables outside-click dismissal but not the close button or Escape routed from tray actions. Do not poll the entire desktop continuously.

Motion should communicate state, not decorate it. The loading orb appears with a short opacity and scale settle. The first real delta morphs the orb into the result capsule. Subsequent text growth adjusts size with a critically damped spring or a 140–220 ms ease-out while opacity stays stable, unless the user has resized the panel. Dismissal combines opacity, slight scale reduction, and a small blur or translation over roughly 180–260 ms, then hides the HWND only after the composition completes. Honor Windows reduced-motion settings by replacing transforms with short fades. Never block the UI thread for animation, clipboard waits, formula rendering, or core I/O.

## Plain text and formulas

Do not implement Markdown. Treat the response as ordinary selectable text and recognize only LaTeX math delimited by `$…$`, `$$…$$`, `\(…\)`, `\[…\]`, or standard equation environments. Bundle KaTeX locally and render formulas in WebView2, or choose an equivalently deterministic local renderer; escape all non-formula text, disable navigation and remote resource loading, and never inject the model output as trusted HTML. Incomplete or invalid formulas remain visible as their original source while streaming. Rendering must be asynchronous and cached so ordinary translations do not wait for the math engine.

## Installation and automatic updates

Sparkle is macOS-only. Use Velopack for the unpackaged Windows client, lock the exact current stable package version, and follow its [integration documentation](https://docs.velopack.io/). `VelopackApp.Build().Run()` must be the first application statement so install, update, and uninstall hooks run before WinUI initialization. Store settings, logs, and cached state under `%LocalAppData%\Bren`, never beside the executable, because the installed application directory is replaced during an update.

Package each self-contained publish output separately. Velopack requires distinct channels for different architectures, so use `win-x64` and `win-arm64`; never allow an x64 client to consume an ARM64 package. Configure `GithubSource` against `WilletJiang/Bren`, check periodically without interrupting translation, download in the background, and offer an explicit restart after the package is ready. An update failure is non-fatal and must not prevent translation.

The existing tag workflow currently owns one GitHub Release and macOS `appcast.xml`. Do not add two independent Windows release jobs that race to create the same tag. Refactor `.github/workflows/release.yml` into build jobs and one final publish job. The macOS job produces its signed ZIP and appcast. A Windows matrix job produces x64 and ARM64 publish folders and Velopack assets. The final job downloads every artifact, creates one release, and attaches all macOS and Windows assets without changing the existing Sparkle filenames or signatures.

A suitable build matrix is:

| Release identity | .NET RID | Go target | Velopack channel |
| --- | --- | --- | --- |
| Windows x64 | `win-x64` | `GOOS=windows GOARCH=amd64` | `win-x64` |
| Windows ARM64 | `win-arm64` | `GOOS=windows GOARCH=arm64` | `win-arm64` |

The Windows job should run on a current Windows runner, install .NET 10 and Go 1.24, restore locked NuGet dependencies, execute .NET and Go tests, build the matching core, publish self-contained output, package it, and verify that `bren-core.exe` has the expected PE machine type before upload. A release is incomplete if either architecture is missing. Keep code-signing hooks in the workflow even if the first personal build is unsigned; broader distribution later requires an Authenticode certificate and reputation-building, but that must not be simulated with an untrusted test certificate.

## Verification contract

Pure tests must cover JSONL framing, event decoding, request state transitions, direct-input submission, cancellation, automatic and manual geometry, monitor clamping, formula delimiter handling, and invalid-formula fallback. A fake core process must emit fragmented JSONL, multiple records per write, Unicode deltas, delayed `started`, delayed first token, cancellation, error, and abrupt EOF. These tests are required before connecting the real Codex backend because they separate frontend correctness from account and network latency.

Run Windows interaction tests for UI Automation selection, active-copy fallback, restoration of a rich clipboard, unchanged clipboard opening direct input, Return and Shift-Return behavior, hotkey conflicts, no focus theft during selection translation, deliberate focus in input mode, formula rendering, native resizing, draggable regions, pinning, outside-click dismissal, reduced motion, high contrast, multiple monitors, mixed DPI, and core termination. Exercise the installed x64 package on x64 Windows and the installed ARM64 package on ARM64 Windows; compiling both is not sufficient evidence that both update paths work.

The implementation is ready to merge only when all of the following are true: `Alt+D` translates the selection from common native and Chromium applications without changing focus; when no selection exists the same shortcut accepts typed Chinese or English; stale clipboard text can never be translated; deltas visibly stream; a replacement request cancels the old one; formulas render without interpreting Markdown; the Acrylic panel retains its monochrome black gradient, white text, drag behavior, user size, and outside-click dismissal unless pinned; both architectures install and update from their own channel; application exit leaves no hotkey, hook, tray icon, or child process behind.

Implement in dependency order. First land the solution, architecture matrix, fake core, and CI. Then complete the JSONL transport and state machine, followed by selection, direct input, and shortcut capture, then the resizable overlay and formula renderer, then real `bren-core` integration, and finally Velopack and the unified release workflow. Do not tune animation against a live backend: the fake core must make every visual state deterministic and fast to reproduce.
