import Foundation

public struct SpeedSample: Equatable, Sendable {
    public let outputTokens: Int
    public let duration: TimeInterval
    public let measuredAt: Date

    public init(outputTokens: Int, duration: TimeInterval, measuredAt: Date) {
        self.outputTokens = outputTokens
        self.duration = duration
        self.measuredAt = measuredAt
    }

    public var tokensPerSecond: Double {
        Double(outputTokens) / duration
    }
}

public struct SpeedEstimator: Sendable {
    private var requestStartedAt: Date?
    private var lastModelOutputAt: Date?

    public init() {}

    @discardableResult
    public mutating func consume(_ event: SessionEvent) -> SpeedSample? {
        if event.startsTask, requestStartedAt == nil {
            requestStartedAt = event.timestamp
        }

        if event.startsUserTurn {
            requestStartedAt = event.timestamp
            lastModelOutputAt = nil
            return nil
        }

        if event.isModelOutput {
            if requestStartedAt != nil {
                lastModelOutputAt = event.timestamp
            }
            return nil
        }

        if event.completesTask {
            requestStartedAt = nil
            lastModelOutputAt = nil
            return nil
        }

        guard event.isTokenCount else { return nil }

        defer {
            // When a tool just finished, the next model request starts immediately
            // after this usage event. A later user_message overrides this boundary.
            requestStartedAt = event.timestamp
            lastModelOutputAt = nil
        }

        guard
            let outputTokens = event.outputTokens,
            outputTokens > 0,
            let start = requestStartedAt
        else {
            return nil
        }

        let end = lastModelOutputAt ?? event.timestamp
        let duration = end.timeIntervalSince(start)
        guard duration > 0.05 else { return nil }

        return SpeedSample(
            outputTokens: outputTokens,
            duration: duration,
            measuredAt: event.timestamp
        )
    }
}
