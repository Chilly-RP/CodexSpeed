import Foundation

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw TestFailure(description: message) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    try expect(actual == expected, "\(message): expected \(expected), got \(actual)")
}

func expectClose(
    _ actual: Double,
    _ expected: Double,
    _ message: String,
    accuracy: Double = 0.001
) throws {
    try expect(abs(actual - expected) <= accuracy, "\(message): expected \(expected), got \(actual)")
}

func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(description: message) }
    return value
}
