import Foundation
import CodexSpeedCore

// User journey: As a Codex user, I want the menu to show the active
// conversation title so that I can recognize the task without decoding an ID.
func sessionTitleTests() throws {
    do {
        let data = Data([
            #"{"timestamp":"2026-08-05T06:00:00.000Z","type":"session_meta","payload":{"id":"session-123","cwd":"/private/project"}}"#,
            #"{"timestamp":"2026-08-05T06:00:01.000Z","type":"event_msg","payload":{"type":"task_started"}}"#,
        ].joined(separator: "\n").utf8)

        try expectEqual(
            CodexSessionTitles.sessionID(in: data),
            "session-123",
            "session metadata id"
        )
        try expect(
            CodexSessionTitles.sessionID(in: Data(#"{"type":"session_meta""#.utf8)) == nil,
            "partial session metadata should be retried later"
        )
    }

    do {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let codexHome = temporaryRoot.appendingPathComponent(".codex", isDirectory: true)
        let sessionURL = temporaryRoot.appendingPathComponent("session.jsonl")
        try FileManager.default.createDirectory(
            at: codexHome,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try Data(
            #"{"type":"session_meta","payload":{"id":"file-session"}}"#.utf8
        ).write(to: sessionURL)
        try Data(
            #"{"id":"file-session","thread_name":"文件中的标题","updated_at":"2026-08-05T06:00:00Z"}"#.utf8
        ).write(to: codexHome.appendingPathComponent("session_index.jsonl"))

        let sessionID = try require(
            CodexSessionTitles.sessionID(at: sessionURL),
            "session id should load from a session file"
        )
        try expectEqual(sessionID, "file-session", "file session id")
        try expectEqual(
            CodexSessionTitles.threadName(for: sessionID, codexHome: codexHome),
            "文件中的标题",
            "title should load from the Codex index file"
        )
        try expect(
            CodexSessionTitles.sessionID(
                at: temporaryRoot.appendingPathComponent("missing-session.jsonl")
            ) == nil,
            "missing session file should return nil"
        )
    }

    do {
        let index = Data([
            #"{"id":"session-123","thread_name":"旧标题","updated_at":"2026-08-05T06:00:00Z"}"#,
            "not-json",
            #"{"id":"another-session","thread_name":"其他会话","updated_at":"2026-08-05T06:01:00Z"}"#,
            #"{"id":"session-123","thread_name":"新的对话标题","updated_at":"2026-08-05T06:02:00Z"}"#,
        ].joined(separator: "\n").utf8)

        try expectEqual(
            CodexSessionTitles.threadName(for: "session-123", in: index),
            "新的对话标题",
            "latest matching conversation title"
        )
        try expect(
            CodexSessionTitles.threadName(for: "missing-session", in: index) == nil,
            "missing conversation title should return nil"
        )
    }

    do {
        try expectEqual(
            CodexSessionTitles.menuDisplayName(
                threadName: "  文件预览\n可靠性\t修复  ",
                fallback: "…71e5f8dd"
            ),
            "文件预览 可靠性 修复",
            "menu title whitespace normalization"
        )
        try expectEqual(
            CodexSessionTitles.menuDisplayName(
                threadName: "123456789",
                fallback: "…71e5f8dd",
                maximumLength: 6
            ),
            "12345…",
            "long menu title truncation"
        )
        try expectEqual(
            CodexSessionTitles.menuDisplayName(
                threadName: "  \n\t ",
                fallback: "…71e5f8dd"
            ),
            "…71e5f8dd",
            "empty menu title fallback"
        )
        try expectEqual(
            CodexSessionTitles.menuDisplayName(
                threadName: "过长标题",
                fallback: "…71e5f8dd",
                maximumLength: 1
            ),
            "…",
            "single-character menu title boundary"
        )
    }
}
