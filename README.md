# Codex Quota Menu Bar

See your remaining **weekly Codex allowance** in the macOS menu bar, just like a battery percentage. Native Swift and AppKit. No third-party libraries.

[English](README.md) · [简体中文](README.zh-CN.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

![Weekly Codex allowance and the expanded menu](docs/media/screenshot.png)

## Demo

https://github.com/user-attachments/assets/a06aa77e-f319-4634-bfe9-c256333c639c

Recorded from the running macOS app: open the menu, refresh, and check the reset time. The background is isolated; quota values reflect the recording time.

[Download the MP4 recording](docs/media/demo.mp4)

The app interface is currently in Chinese. Documentation is available in English, Chinese, French, and German. This is an independent open-source project.

## Download and install

1. Download `Codex-Quota-v1.0.0-macos-arm64.zip` from [Releases](https://github.com/criller/codex-quota-menubar/releases/latest).
2. Unzip it and move `Codex Quota.app` to Applications, or to your personal `~/Applications` folder.
3. Open the app in Finder. The menu bar shows `Codex …` while loading, then the remaining percentage.

**Requirements:** an Apple Silicon Mac (M1 or later), macOS 14 or later, and a local Codex installation signed in with a ChatGPT account. The prebuilt app is arm64 only. Builds and live quota reads have been verified on Apple Silicon with macOS 27; older macOS versions have not been tested individually.

The download is ad-hoc signed, without an Apple Developer ID signature or notarization. macOS may block the first launch. Verify the source, then follow the system's approval instructions, or build from source.

## What it does

- Shows the remaining weekly allowance directly in the menu bar.
- Refreshes every five minutes, retries every minute after a failure, and refreshes after wake.
- Offers manual refresh, reset time in your local time zone, and the last update time.
- Marks an old percentage with `!` after a failed read, ten minutes without a successful update, or an expired quota window.
- Shows `Codex --` when no quota has been read. Missing quota data is never treated as 100% remaining.
- Offers optional launch at login, disabled by default.

The percentage describes the account's weekly allowance, **not a number of remaining tokens**. The app does not control or reset your quota.

## How it works

The app starts a short-lived local `codex app-server --stdio` process. After the `initialize` / `initialized` handshake, it calls only `account/rateLimits/read` and closes the process.

Authentication and network requests are handled by your installed Codex. The app uses the default local Codex login. It does not run model turns, read conversations, or copy credentials. There is no project-operated server. An OpenAI API key alone does not provide a ChatGPT subscription quota.

The app looks for Codex bundled with ChatGPT/Codex, then checks Homebrew, `~/.local/bin`, and nvm installations. A seven-day window is identified by `windowDurationMins == 10080`, in either primary or secondary. It prefers `rateLimitsByLimitId.codex` and supports the legacy `rateLimits` response. Remaining usage is `100 - usedPercent`, rounded down.

See the [OpenAI Codex App Server protocol](https://learn.chatgpt.com/docs/app-server). Changes to Codex authentication, installation paths, or the protocol may require an update.

## Build from source

Install macOS Command Line Tools and a Swift toolchain supporting Swift 5.9 or later.

```bash
git clone https://github.com/criller/codex-quota-menubar.git
cd codex-quota-menubar
bash build.sh
```

The output is `dist/Codex Quota.app`. The script runs the core regression tests, builds the arm64 app, and applies and verifies an ad-hoc signature.

Run a read-only check using the same quota client as the menu bar:

```bash
"dist/Codex Quota.app/Contents/MacOS/CodexQuota" --check
```

This prints only the remaining percentage and reset time. Do not post credential files or unchecked Codex logs in public issues.

Create a release archive and its SHA-256 checksum:

```bash
bash package.sh
```

Verify a download from the directory containing the ZIP and `SHA256SUMS.txt`:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## Troubleshooting

- **Codex not found:** install or update Codex locally. A supported `app-server` executable must be available.
- **Sign-in required:** sign in to Codex with your ChatGPT account, then refresh.
- **`!` or `Codex --`:** open the menu for the error and last update time. Check your connection and refresh again.
- **Launch at login needs approval:** approve the app in macOS Login Items settings.

## Uninstall

Disable launch at login in the app menu, quit the app, and delete `Codex Quota.app`.

## License

[MIT](LICENSE) © 2026 criller
