import Darwin
import Foundation

let tests: [(String, () throws -> Void)] = [
    ("SessionEvent", sessionEventTests),
    ("SpeedEstimator", speedEstimatorTests),
    ("SessionFiles", sessionFilesTests),
    ("SessionTitle", sessionTitleTests),
]

var failures = 0
for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures += 1
        fputs("FAIL \(name): \(error)\n", stderr)
    }
}

if failures > 0 {
    fputs("\(failures) test group(s) failed\n", stderr)
    exit(1)
}

print("PASS all \(tests.count) test groups")
