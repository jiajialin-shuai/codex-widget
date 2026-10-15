# Codex Battery

[简体中文](README.md) | English

A lightweight, native macOS menu bar app and desktop widget for checking your remaining Codex quota—as easily as checking your keyboard battery.

## Features

- **Small widget:** weekly and five-hour quota, with two battery-style rings and remaining percentages.
- **Medium widget:** quota rings and reset dates.
- **Large widget:** quota, reset times, available reset cards and their nearest expiry, credit balance, and subscription plan.
- Built with SwiftUI, AppKit, and WidgetKit, with no third-party runtime dependencies.
- Menu bar icon hidden by default. Click a widget or reopen the app to access settings; the icon can be enabled there.
- Refreshes every 15 minutes by default, with 30- and 60-minute options, sleep handling, and failure backoff.
- Starts a short-lived Codex app-server for each query and stops it afterward. No persistent Codex subprocess while idle.
- Widgets read only normalized display data; they do not access tokens or browser cookies.

## Download and install

Download the Universal ZIP from [GitHub Releases](https://github.com/jiajialin-shuai/codex-widget/releases), extract it, and move `CodexBattery.app` to `~/Applications`.

Install Codex and sign in first. Open Codex Battery, right-click the desktop, choose **Edit Widgets**, search for **Codex**, and add your preferred size. Keep the background app running to fetch updates. Clicking a widget opens settings and requests a refresh.

Requires macOS 14 or later. The Universal binary includes Apple Silicon and Intel support. Runtime testing has been performed on Apple Silicon with macOS 27; Intel and macOS 14/15 hardware testing is still pending.

**Preview builds are ad-hoc signed and have not been Developer ID signed or notarized by Apple.** Gatekeeper may block the first launch. Building from source is also available. Verify downloaded packages against the included `SHA256SUMS` file.

Only native WidgetKit widgets added through the system widget gallery are provided. There are no separate desktop panels or overlays. Matching the translucent background of Apple's Batteries widget remains under investigation; see the [background research notes](docs/WIDGET_BACKGROUND_RESEARCH.md) (Chinese).

## Build from source

The verified build environment uses full Xcode 27, including the macOS 27 SDK, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). You also need Codex CLI, or the Codex executable bundled with the desktop app, signed in with a ChatGPT account. API-key-only authentication may not expose subscription quota.

```bash
brew install xcodegen
./scripts/check.sh           # Offline parsing and process cleanup checks
./scripts/check.sh --live    # Query the local account without saving raw responses
./scripts/build.sh
./scripts/install.sh        # Installs into ~/Applications by default
./scripts/check-widget.sh   # Check sandboxed widget reads while the app is running
./scripts/package.sh        # Scan the bundle and generate ZIP + SHA-256
```

To select a specific Xcode installation:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build.sh
```

The build script removes debug maps and local symbols containing builder paths, then re-signs the app and extension. Packaging checks the bundle for local user paths and selected sensitive file types before generating the archive.

## Understanding the data

Rings and percentages show **remaining quota**, calculated as `100 - usedPercent`. Five-hour and weekly windows are identified by `windowDurationMins`, rather than assuming a fixed response-field order. Missing data is shown as unavailable, never replaced with a fabricated zero.

Old values are marked as cached after a reset deadline or a failed fetch. WidgetKit controls when widgets actually update: the 15-minute interval is a refresh request, not a real-time guarantee. Reset cards are display-only; the app never consumes them.

Real timeline entries are separate from loading placeholders and retain system privacy redaction. The installation script restarts this project's widget extension so updates do not keep running the old executable; it does not remove desktop widgets or their layout.

## Privacy and local access

The background app calls `account/rateLimits/read` through the local `codex app-server`. It retains only quota percentages, dates, plan, credit balance, reset-card count and expiry dates, update time, and fixed error messages. It does not store raw RPC responses, account IDs, email addresses, card IDs, or authentication tokens. Codex manages its own authentication and token refresh.

There is no telemetry, advertising SDK, crash reporting, or developer-operated data server. Codex itself uses its network connection to retrieve quota.

The widget reads a normalized snapshot from a read-only service bound exclusively to `127.0.0.1:49763`. The service rejects browser-origin requests and has no mutation endpoint. **It does not authenticate local clients: other native programs, including programs run by other users on the same Mac, may still read the quota summary.** The client marker is not a secret. This design assumes a trusted personal computer and does not require an App Group or a paid developer account.

Cache directories use `0700` permissions and files use `0600`. The widget retains a labeled offline copy when the background app exits. Displayed quota can be visible in screenshots or screen sharing. See [PRIVACY.md](PRIVACY.md) (Chinese) for the full data flow, local-access boundaries, and deletion instructions.

## Project layout

- `Sources/Shared`: normalized data, cache, request validation, and battery UI.
- `Sources/App`: menu bar, settings, CLI queries, and the read-only snapshot bridge.
- `Sources/Widget`: WidgetKit timelines.
- `Tests`: parsing, missing fields, quota pools, expiry, cache serialization, browser isolation, and subprocess cleanup.
- [Design](docs/DESIGN.md), [verification](docs/VERIFICATION.md), and [widget background research](docs/WIDGET_BACKGROUND_RESEARCH.md) (Chinese).

## License and acknowledgments

Released under the [MIT License](LICENSE). This is an independent project and is not an official OpenAI product.

[CodexBar](https://github.com/steipete/CodexBar) and [Codex Usage Bar](https://github.com/CMMUU/codex-usage-bar) informed the information layout and local RPC approach. Their code was not copied.

This English README documents the app; it does not add an English localization to the application UI.
