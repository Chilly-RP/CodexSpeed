# CodexSpeed

[![CI](https://github.com/Chilly-RP/CodexSpeed/actions/workflows/ci.yml/badge.svg)](https://github.com/Chilly-RP/CodexSpeed/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Chilly-RP/CodexSpeed)](https://github.com/Chilly-RP/CodexSpeed/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

CodexSpeed 是一个轻量的原生 macOS 菜单栏应用，用于显示最近活跃 Codex 任务的模型输出速度：`xx.x tokens/s`。

## 界面预览

![CodexSpeed 菜单栏输出速度](docs/images/codexspeed-menubar.png)

## 安装

1. 从 [Releases](https://github.com/Chilly-RP/CodexSpeed/releases/latest) 下载 `CodexSpeed-v0.1.0-macOS-arm64.zip`。
2. 解压后将 `CodexSpeed.app` 拖入“应用程序”目录。
3. 首次启动时，在 Finder 中右键点击应用并选择“打开”。

当前发布包支持 Apple Silicon（arm64）和 macOS 13 及以上版本。应用使用临时签名，尚未进行 Apple Developer ID 签名与公证，因此不适用于免提示的商业分发。

## 功能

- 自动跟随最近有写入的 Codex 本地任务。
- 显示最近活跃任务的 Codex 对话标题，标题不可用时回退到任务短标识。
- 使用 Codex 记录的精确 `last_token_usage.output_tokens`，不以字符数估算 token。
- 每 250 ms 检查会话增量，并在模型 usage 落盘后刷新菜单栏。
- 测量模型响应的墙钟时间，排除工具执行耗时和两轮之间的空闲时间。
- 提供 `--probe` 只读诊断模式，便于检查本机实际会话兼容性。
- 无网络依赖，不修改 Codex 配置。

## 测量口径与限制

CodexSpeed 显示的是最近一次模型响应的平均输出速度：

```text
tokens/s = last_token_usage.output_tokens / model_response_duration
```

Codex 桌面应用目前不会把逐 token delta 写入本地会话 JSONL，因此本应用不会伪装成逐 token 瞬时测速。数值会在一次模型响应的精确 usage 写入会话后更新。

如果同时运行多个 Codex 任务，应用会跟随最近修改的会话文件。

## 隐私

应用只提取本地会话事件中的类型、时间戳、角色和 token 计数，以及本地会话索引中的对话标题。标题只显示在本机菜单中；应用不会提取、展示、保存或上传提示词、回复正文、工具参数和工具输出，也不会修改 `~/.codex/config.toml`。

## 系统要求

- macOS 13 或更高版本
- Swift 5.10 或兼容工具链
- 本地 Codex 会话目录（默认 `~/.codex/sessions`，同时支持 `CODEX_HOME`）

## 开发

运行零第三方依赖的核心测试：

```sh
swift run CodexSpeedCoreTests
```

构建 Release 二进制：

```sh
swift build -c release --product CodexSpeed
```

打包本机架构的临时签名 `.app`：

```sh
./scripts/package.sh ./dist
open ./dist/CodexSpeed.app
```

对当前真实 Codex 会话运行只读探针：

```sh
./dist/CodexSpeed.app/Contents/MacOS/CodexSpeed --probe
```

探针只输出任务短标识、token 数、耗时和速度，不输出会话正文。

## 项目结构

```text
Sources/CodexSpeedApp/       macOS 菜单栏界面与文件增量监测
Sources/CodexSpeedCore/      JSONL 解析、速度计算和只读探针
Tests/CodexSpeedCoreTests/   无外部测试框架的核心测试
Resources/                   App bundle 元数据
scripts/package.sh           Release 构建与本地签名打包
```

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
