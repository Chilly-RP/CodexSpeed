import Foundation
import CodexSpeedCore

func speedEstimatorTests() throws {
    do {
        var estimator = SpeedEstimator()
        let start = Date(timeIntervalSince1970: 1_000)

        _ = estimator.consume(event(at: start, type: "event_msg", payload: "user_message"))
        _ = estimator.consume(event(at: start.addingTimeInterval(8), type: "response_item", payload: "reasoning"))
        _ = estimator.consume(event(at: start.addingTimeInterval(10), type: "response_item", payload: "custom_tool_call"))
        _ = estimator.consume(event(at: start.addingTimeInterval(14), type: "response_item", payload: "custom_tool_call_output"))

        let sample = try require(estimator.consume(
            event(at: start.addingTimeInterval(14), type: "event_msg", payload: "token_count", tokens: 500)
        ), "first speed sample")

        try expectEqual(sample.outputTokens, 500, "exact output tokens")
        try expectClose(sample.duration, 10, "model duration")
        try expectClose(sample.tokensPerSecond, 50, "tokens per second")
    }

    do {
        var estimator = SpeedEstimator()
        let start = Date(timeIntervalSince1970: 2_000)
        _ = estimator.consume(event(at: start, type: "event_msg", payload: "user_message"))
        _ = estimator.consume(event(at: start.addingTimeInterval(4), type: "response_item", payload: "custom_tool_call"))
        _ = estimator.consume(event(at: start.addingTimeInterval(20), type: "response_item", payload: "custom_tool_call_output"))
        _ = estimator.consume(event(at: start.addingTimeInterval(20), type: "event_msg", payload: "token_count", tokens: 80))

        _ = estimator.consume(event(at: start.addingTimeInterval(25), type: "response_item", payload: "message"))
        let second = try require(estimator.consume(
            event(at: start.addingTimeInterval(25.5), type: "event_msg", payload: "token_count", tokens: 250)
        ), "second speed sample")

        try expectClose(second.duration, 5, "tool time exclusion")
        try expectClose(second.tokensPerSecond, 50, "post-tool speed")
    }

    do {
        var estimator = SpeedEstimator()
        let start = Date(timeIntervalSince1970: 3_000)
        _ = estimator.consume(event(at: start, type: "event_msg", payload: "user_message"))
        _ = estimator.consume(event(at: start.addingTimeInterval(2), type: "response_item", payload: "message"))
        _ = estimator.consume(event(at: start.addingTimeInterval(2), type: "event_msg", payload: "token_count", tokens: 100))
        _ = estimator.consume(event(at: start.addingTimeInterval(2.1), type: "event_msg", payload: "task_complete"))

        _ = estimator.consume(event(at: start.addingTimeInterval(100), type: "event_msg", payload: "user_message"))
        _ = estimator.consume(event(at: start.addingTimeInterval(104), type: "response_item", payload: "message"))
        let sample = try require(estimator.consume(
            event(at: start.addingTimeInterval(104.1), type: "event_msg", payload: "token_count", tokens: 200)
        ), "new user turn sample")

        try expectClose(sample.duration, 4, "idle time exclusion")
    }
}

private func event(
    at date: Date,
    type: String,
    payload: String,
    tokens: Int? = nil
) -> SessionEvent {
    SessionEvent(
        timestamp: date,
        recordType: type,
        payloadType: payload,
        outputTokens: tokens
    )
}
