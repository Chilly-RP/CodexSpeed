import Foundation

public struct SessionEvent: Equatable, Sendable {
    public let timestamp: Date
    public let recordType: String
    public let payloadType: String
    public let role: String?
    public let outputTokens: Int?

    public init(
        timestamp: Date,
        recordType: String,
        payloadType: String,
        role: String? = nil,
        outputTokens: Int? = nil
    ) {
        self.timestamp = timestamp
        self.recordType = recordType
        self.payloadType = payloadType
        self.role = role
        self.outputTokens = outputTokens
    }

    public static func parse(line: Data) -> SessionEvent? {
        guard
            let object = try? JSONSerialization.jsonObject(with: line),
            let root = object as? [String: Any],
            let timestampText = root["timestamp"] as? String,
            let timestamp = SessionTimestamp.parse(timestampText),
            let recordType = root["type"] as? String,
            let payload = root["payload"] as? [String: Any],
            let payloadType = payload["type"] as? String
        else {
            return nil
        }

        let role = payload["role"] as? String
        let info = payload["info"] as? [String: Any]
        let lastUsage = info?["last_token_usage"] as? [String: Any]
        let outputTokens = (lastUsage?["output_tokens"] as? NSNumber)?.intValue

        return SessionEvent(
            timestamp: timestamp,
            recordType: recordType,
            payloadType: payloadType,
            role: role,
            outputTokens: outputTokens
        )
    }

    public var isModelOutput: Bool {
        guard recordType == "response_item" else { return false }
        guard role != "user", role != "system", role != "developer" else { return false }
        guard !payloadType.hasSuffix("_output") else { return false }
        return true
    }

    public var startsUserTurn: Bool {
        recordType == "event_msg" && payloadType == "user_message"
    }

    public var startsTask: Bool {
        recordType == "event_msg" && payloadType == "task_started"
    }

    public var completesTask: Bool {
        recordType == "event_msg" && payloadType == "task_complete"
    }

    public var isTokenCount: Bool {
        recordType == "event_msg" && payloadType == "token_count"
    }
}

private enum SessionTimestamp {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let wholeSeconds = ISO8601DateFormatter()
        wholeSeconds.formatOptions = [.withInternetDateTime]
        return wholeSeconds.date(from: value)
    }
}
