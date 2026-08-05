import Foundation

public struct CodexSpeedProbeResult: Sendable {
    public let sessionURL: URL
    public let sample: SpeedSample

    public init(sessionURL: URL, sample: SpeedSample) {
        self.sessionURL = sessionURL
        self.sample = sample
    }
}

public enum CodexSpeedProbe {
    public static func latest(
        codexHome: URL = CodexSessionFiles.codexHome(),
        maximumReplayBytes: Int = 8 * 1_024 * 1_024
    ) throws -> CodexSpeedProbeResult? {
        guard let sessionURL = CodexSessionFiles.latestSessionFile(codexHome: codexHome) else {
            return nil
        }

        let values = try sessionURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0
        let replayStart = max(0, fileSize - maximumReplayBytes)
        let handle = try FileHandle(forReadingFrom: sessionURL)
        defer { try? handle.close() }

        try handle.seek(toOffset: UInt64(replayStart))
        var data = try handle.readToEnd() ?? Data()
        if replayStart > 0 {
            guard let newline = data.firstIndex(of: 0x0A) else { return nil }
            data = data.subdata(in: data.index(after: newline)..<data.endIndex)
        }

        guard let sample = latestSample(in: data) else { return nil }
        return CodexSpeedProbeResult(sessionURL: sessionURL, sample: sample)
    }

    public static func latestSample(in data: Data) -> SpeedSample? {
        var buffer = JSONLineBuffer()
        var estimator = SpeedEstimator()
        var latest: SpeedSample?

        for line in buffer.append(data) {
            guard let event = SessionEvent.parse(line: line) else { continue }
            if let sample = estimator.consume(event) {
                latest = sample
            }
        }
        return latest
    }
}
