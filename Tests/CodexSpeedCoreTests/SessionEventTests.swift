import Foundation
import CodexSpeedCore

func sessionEventTests() throws {
    let line = Data(#"{"timestamp":"2026-08-05T06:25:38.529Z","type":"event_msg","payload":{"type":"token_count","message":"private text must be ignored","info":{"last_token_usage":{"output_tokens":941},"total_token_usage":{"output_tokens":4525}}}}"#.utf8)
    let event = try require(SessionEvent.parse(line: line), "token_count event should parse")

    try expectEqual(event.recordType, "event_msg", "record type")
    try expectEqual(event.payloadType, "token_count", "payload type")
    try expectEqual(event.outputTokens, 941, "last output tokens")
    try expect(SessionEvent.parse(line: Data("not-json".utf8)) == nil, "malformed JSON should be ignored")

    let date = try require(
        ISO8601DateFormatter().date(from: "2026-08-05T06:25:38Z"),
        "fixture date should parse"
    )
    let toolOutput = SessionEvent(
        timestamp: date,
        recordType: "response_item",
        payloadType: "custom_tool_call_output"
    )
    try expect(!toolOutput.isModelOutput, "tool output must not extend model response time")
}
