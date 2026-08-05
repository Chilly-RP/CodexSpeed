import Foundation

public enum CodexSessionTitles {
    public static func sessionID(in data: Data) -> String? {
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let root = object as? [String: Any],
                root["type"] as? String == "session_meta",
                let payload = root["payload"] as? [String: Any],
                let id = payload["id"] as? String,
                !id.isEmpty
            else {
                continue
            }

            return id
        }

        return nil
    }

    public static func sessionID(
        at sessionURL: URL,
        maximumBytes: Int = 256 * 1_024
    ) -> String? {
        guard maximumBytes > 0, let handle = try? FileHandle(forReadingFrom: sessionURL) else {
            return nil
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: maximumBytes) else {
            return nil
        }
        return sessionID(in: data)
    }

    public static func threadName(for sessionID: String, in data: Data) -> String? {
        var latestName: String?

        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)),
                let entry = object as? [String: Any],
                entry["id"] as? String == sessionID
            else {
                continue
            }

            latestName = entry["thread_name"] as? String
        }

        return latestName
    }

    public static func threadName(for sessionID: String, codexHome: URL) -> String? {
        let indexURL = codexHome.appendingPathComponent("session_index.jsonl")
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        return threadName(for: sessionID, in: data)
    }

    public static func menuDisplayName(
        threadName: String?,
        fallback: String,
        maximumLength: Int = 48
    ) -> String {
        let normalized = threadName?
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ") ?? ""
        let displayName = normalized.isEmpty ? fallback : normalized

        guard displayName.count > maximumLength else { return displayName }
        guard maximumLength > 1 else { return maximumLength == 1 ? "…" : "" }
        return String(displayName.prefix(maximumLength - 1)) + "…"
    }
}
