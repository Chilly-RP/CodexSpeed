import Darwin
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
        return latestJSONL(in: sessions, fileManager: fileManager)
    }

    public static func shortSessionName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        guard let suffix = base.split(separator: "-").last else { return base }
        return "…" + suffix.suffix(8)
    }

    private static func latestJSONL(in directory: URL, fileManager: FileManager) -> URL? {
        guard let enumerator = fileManager.enumerator(atPath: directory.path) else {
            return nil
        }

        var latest: (url: URL, modifiedAt: timespec)?
        while let relativePath = enumerator.nextObject() as? String {
            guard relativePath.hasSuffix(".jsonl") else { continue }

            let path = directory.appendingPathComponent(relativePath).path
            var fileInfo = stat()
            guard
                lstat(path, &fileInfo) == 0,
                fileInfo.st_mode & S_IFMT == S_IFREG
            else {
                continue
            }

            let modifiedAt = fileInfo.st_mtimespec
            if latest == nil || isLater(modifiedAt, than: latest!.modifiedAt) {
                latest = (URL(fileURLWithPath: path), modifiedAt)
            }
        }
        return latest?.url
    }

    private static func isLater(_ lhs: timespec, than rhs: timespec) -> Bool {
        lhs.tv_sec > rhs.tv_sec || (lhs.tv_sec == rhs.tv_sec && lhs.tv_nsec > rhs.tv_nsec)
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
