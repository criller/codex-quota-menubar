# Codex Quota Menu Bar

轻量的 macOS 原生菜单栏应用，像电量百分比一样显示 **Codex 每周剩余额度**。使用 Swift 和 AppKit，无第三方库。

```text
菜单栏：Codex 68%

Codex 每周额度
本周剩余 68%
重置时间：…
上次更新：…
──────────────
立即刷新
开机启动
──────────────
退出 Codex 额度
```

以上为展示示例。百分比表示账号每周使用额度，不是剩余 Token 数量。本项目是独立开源工具。

## 下载与安装

1. 在 [Releases](https://github.com/criller/codex-quota-menubar/releases/latest) 下载 `Codex-Quota-v1.0.0-macos-arm64.zip`。
2. 解压后，将 `Codex Quota.app` 放到“应用程序”目录，也可以放到个人的 `~/Applications` 目录。
3. 在 Finder 中双击应用，菜单栏将出现 `Codex …`，读取成功后显示剩余百分比。

**运行条件：** Apple Silicon Mac（M1 及以上），macOS 14 及以上，并已在本机 Codex 中登录可用的 ChatGPT 账号。当前预编译包仅提供 arm64 版本；本次构建及真实额度读取在 Apple Silicon / macOS 27 上验证，旧系统尚未逐一实机验证。

发行包使用临时签名，尚无 Apple Developer ID 签名和公证。通过浏览器下载后，macOS 可能阻止首次运行；请先确认下载来源，再按系统提示自行批准，或选择从源码构建。

应用启动后会寻找 ChatGPT/Codex 客户端内的 Codex 可执行文件，回退到 Homebrew、`~/.local/bin` 或 nvm 安装的 Codex CLI。若额度无法读取，先确认本机 Codex 已登录，且其 `app-server` 支持额度查询。

## 功能

- 菜单栏直接显示每周剩余百分比。
- 正常每 5 分钟刷新，失败后每分钟重试；支持手动刷新和睡眠唤醒后刷新。
- 点击菜单查看重置时间（本机时区）和上次更新时间。
- 读取失败、超过 10 分钟未成功更新或已过重置时间时，旧百分比带 `!`，菜单标明“上次读取”。
- 初次读取失败显示 `Codex --`，不猜测额度。
- 支持通过菜单选择“开机启动”，默认关闭。

## 工作方式与数据

应用启动本机 Codex 的短时 `app-server --stdio` 进程，经 `initialize` / `initialized` 握手后，只调用 `account/rateLimits/read`，读取完即关闭。认证和联网查询由本机 Codex 处理，复用默认 Codex 登录状态。

小工具不运行模型任务，不读取会话内容，不自行读取或保存登录凭证，也没有自建服务端。需要联网和有效的 ChatGPT/Codex 登录；仅有 OpenAI API Key 不等同于 ChatGPT 订阅额度。

按 `windowDurationMins == 10080` 识别七天窗口，优先使用 `rateLimitsByLimitId.codex`，兼容旧的 `rateLimits`。每周窗口可能位于 primary 或 secondary。百分比采用 `100 - usedPercent`，小数向下取整。每周窗口缺失或返回数据已过重置时间时，显示不可用或待更新。

协议参考：[OpenAI Codex App Server](https://learn.chatgpt.com/docs/app-server)。Codex 的安装路径、登录方式或协议变化时，可能需要更新本工具。

## 从源码构建

需要 macOS Command Line Tools 和支持 Swift 5.9 及以上的 Swift 工具链。

```bash
git clone https://github.com/criller/codex-quota-menubar.git
cd codex-quota-menubar
bash build.sh
```

产物位于 `dist/Codex Quota.app`。构建脚本先运行核心回归测试，再编译 arm64 应用并进行临时签名及签名校验。

可以通过与菜单栏共用的额度读取逻辑进行只读诊断：

```bash
"dist/Codex Quota.app/Contents/MacOS/CodexQuota" --check
```

诊断仅输出剩余百分比和重置时间。请不要在公开 Issue 中附上凭证文件或未经检查的 Codex 日志。

生成发行压缩包及 SHA-256 校验文件：

```bash
bash package.sh
```

校验下载文件时，在压缩包和 `SHA256SUMS.txt` 所在目录运行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## 卸载

先关闭菜单中的“开机启动”，再退出应用，删除 `Codex Quota.app`。

## 许可证

[MIT](LICENSE) © 2026 criller
