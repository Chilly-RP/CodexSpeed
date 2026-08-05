import Foundation

public enum CodexSessionFiles {
    public static func codexHome(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL {
        if let configured = environment["CODEX_HOME"], !configured.isEmpty {
            return URL(fileURLWithPath: configured, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    public static func latestSessionFile(
        codexHome: URL,
        now: Date = Date(),
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) -> URL? {
        let sessions = codexHome.appendingPathComponent("sessions", isDirectory: true)
        let candidates = [now, calendar.date(byAdding: .day, value: -1, to: now)].compactMap { $0 }

        for date in candidates {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard
                let year = components.year,
                let month = components.month,
                let day = components.day
            else {
                continue
            }

            let dayDirectory = sessions
                .appendingPathComponent(String(format: "%04d", year), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", month), isDirectory: true)
                .appendingPathComponent(String(format: "%02d", day), isDirectory: true)

            if let latest = latestJSONL(in: dayDirectory, fileManager: fileManager) {
                return latest
            }
        }

        return nil
    }

    public static func shortSessionName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        guard let suffix = base.split(separator: "-").last else { return base }
        return "…" + suffix.suffix(8)
    }

    private static func latestJSONL(in directory: URL, fileManager: FileManager) -> URL? {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (URL, Date)? in
                guard
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                    values.isRegularFile == true,
                    let modified = values.contentModificationDate
                else {
                    return nil
                }
                return (url, modified)
            }
            .max { $0.1 < $1.1 }?
            .0
    }
}

public struct JSONLineBuffer: Sendable {
    private var carry = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        carry.append(data)
        var lines: [Data] = []
        var lineStart = carry.startIndex

        for index in carry.indices where carry[index] == 0x0A {
            if index > lineStart {
                lines.append(carry.subdata(in: lineStart..<index))
            }
            lineStart = carry.index(after: index)
        }

        if lineStart > carry.startIndex {
            carry.removeSubrange(carry.startIndex..<lineStart)
        }
        return lines
    }

    public mutating func discardPartialPrefix() {
        guard let newline = carry.firstIndex(of: 0x0A) else {
            carry.removeAll(keepingCapacity: true)
            return
        }
        carry.removeSubrange(carry.startIndex...newline)
    }
}
