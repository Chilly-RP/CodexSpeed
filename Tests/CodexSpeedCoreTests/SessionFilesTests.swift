import Foundation
import CodexSpeedCore

func sessionFilesTests() throws {
    let url = CodexSessionFiles.codexHome(environment: ["CODEX_HOME": "/tmp/codex-test-home"])
    try expectEqual(url.path, "/tmp/codex-test-home", "CODEX_HOME support")

    var buffer = JSONLineBuffer()
    try expectEqual(buffer.append(Data("one\ntw".utf8)).map(utf8), ["one"], "first partial append")
    try expectEqual(
        buffer.append(Data("o\nthree\n".utf8)).map(utf8),
        ["two", "three"],
        "completed partial append"
    )

    let replay = [
        #"{"timestamp":"2026-08-05T06:00:00.000Z","type":"event_msg","payload":{"type":"user_message"}}"#,
        #"{"timestamp":"2026-08-05T06:00:04.000Z","type":"response_item","payload":{"type":"message","role":"assistant"}}"#,
        #"{"timestamp":"2026-08-05T06:00:04.100Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"output_tokens":200}}}}"#,
    ].joined(separator: "\n") + "\n"
    let sample = try require(
        CodexSpeedProbe.latestSample(in: Data(replay.utf8)),
        "replay should produce a speed sample"
    )
    try expectEqual(sample.outputTokens, 200, "replay token count")
    try expectClose(sample.tokensPerSecond, 50, "replay speed")
}

private func utf8(_ data: Data) -> String {
    String(decoding: data, as: UTF8.self)
}
