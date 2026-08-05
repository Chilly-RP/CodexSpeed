import AppKit
import CodexSpeedCore
import Darwin
import Foundation

@main
enum CodexSpeedMain {
    static func main() {
        if CommandLine.arguments.dropFirst().contains("--probe") {
            runProbeAndExit()
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }

    private static func runProbeAndExit() -> Never {
        do {
            guard let result = try CodexSpeedProbe.latest() else {
                fputs("No completed Codex response was found in the latest session.\n", stderr)
                exit(2)
            }

            let sample = result.sample
            print(String(
                format: "session=%@ output_tokens=%d duration_seconds=%.3f tokens_per_second=%.3f",
                CodexSessionFiles.shortSessionName(for: result.sessionURL),
                sample.outputTokens,
                sample.duration,
                sample.tokensPerSecond
            ))
            exit(0)
        } catch {
            fputs("Probe failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let codexHome = CodexSessionFiles.codexHome()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let speedItem = NSMenuItem(title: "最近响应：等待数据", action: nil, keyEquivalent: "")
    private let detailItem = NSMenuItem(title: "输出：—", action: nil, keyEquivalent: "")
    private let sessionItem = NSMenuItem(title: "任务：—", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "更新：—", action: nil, keyEquivalent: "")

    private var timer: Timer?
    private var ticks = 0
    private var currentSessionURL: URL?
    private var fileOffset: UInt64 = 0
    private var lineBuffer = JSONLineBuffer()
    private var estimator = SpeedEstimator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureMenu()
        poll()
        timer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = "— tokens/s"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        button.toolTip = "Codex 最近一次模型响应的平均输出速度"
    }

    private func configureMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: "Codex 输出速度", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        for item in [speedItem, detailItem, sessionItem, updatedItem] {
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let scope = NSMenuItem(
            title: "口径：精确 output tokens ÷ 模型响应时间",
            action: nil,
            keyEquivalent: ""
        )
        scope.isEnabled = false
        menu.addItem(scope)

        let privacy = NSMenuItem(
            title: "隐私：只解析事件类型、时间和 token 计数",
            action: nil,
            keyEquivalent: ""
        )
        privacy.isEnabled = false
        menu.addItem(privacy)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "在 Finder 中显示当前会话",
            action: #selector(revealCurrentSession),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "立即刷新",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出 CodexSpeed",
            action: #selector(quit),
            keyEquivalent: "q"
        ).target = self

        statusItem.menu = menu
    }

    @objc private func timerFired() {
        poll()
    }

    @objc private func refreshNow() {
        ticks = 0
        poll()
    }

    @objc private func revealCurrentSession() {
        guard let currentSessionURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([currentSessionURL])
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func poll() {
        defer {
            ticks += 1
        }

        if currentSessionURL == nil || ticks % 4 == 0 {
            let latest = CodexSessionFiles.latestSessionFile(codexHome: codexHome)
            if latest != currentSessionURL {
                switchToSession(latest)
            }
        }

        guard let currentSessionURL else {
            sessionItem.title = "任务：未找到今天的 Codex 会话"
            return
        }

        readAppendedData(from: currentSessionURL)
    }

    private func switchToSession(_ url: URL?) {
        currentSessionURL = url
        fileOffset = 0
        lineBuffer = JSONLineBuffer()
        estimator = SpeedEstimator()

        guard let url else { return }
        sessionItem.title = "任务：\(CodexSessionFiles.shortSessionName(for: url))"

        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let maximumReplayBytes = 8 * 1_024 * 1_024
        let replayStart = max(0, fileSize - maximumReplayBytes)

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: UInt64(replayStart))
            let data = try handle.readToEnd() ?? Data()
            fileOffset = UInt64(fileSize)
            if replayStart > 0, let newline = data.firstIndex(of: 0x0A) {
                consume(data.subdata(in: data.index(after: newline)..<data.endIndex))
            } else if replayStart == 0 {
                consume(data)
            }
        } catch {
            fileOffset = 0
        }
    }

    private func readAppendedData(from url: URL) {
        guard
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size >= 0
        else {
            return
        }

        if UInt64(size) < fileOffset {
            switchToSession(url)
            return
        }
        guard UInt64(size) > fileOffset else { return }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: fileOffset)
            let data = try handle.readToEnd() ?? Data()
            fileOffset = UInt64(size)
            consume(data)
        } catch {
            return
        }
    }

    private func consume(_ data: Data) {
        for line in lineBuffer.append(data) {
            guard let event = SessionEvent.parse(line: line) else { continue }
            if let sample = estimator.consume(event) {
                display(sample)
            }
        }
    }

    private func display(_ sample: SpeedSample) {
        let speed = sample.tokensPerSecond
        statusItem.button?.title = String(format: "%.1f tokens/s", speed)
        speedItem.title = String(format: "最近响应：%.1f tokens/s", speed)
        detailItem.title = String(
            format: "输出：%d tokens · %.1f 秒",
            sample.outputTokens,
            sample.duration
        )

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        updatedItem.title = "更新：\(formatter.string(from: sample.measuredAt))"
    }
}
