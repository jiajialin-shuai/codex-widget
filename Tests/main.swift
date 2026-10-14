import Foundation
import Darwin

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func parse(_ text: String) throws -> UsageSnapshot { try UsageSnapshot.parse(Data(text.utf8), now: Date(timeIntervalSince1970: 1)) }

let swapped = try parse("""
{"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":41.5,"windowDurationMins":10080,"resetsAt":1000},"secondary":{"usedPercent":100,"windowDurationMins":300},"planType":"plus"},"rateLimitResetCredits":{"availableCount":2,"credits":[{"expiresAt":900,"status":"available","resetType":"codexRateLimits"},{"expiresAt":800,"status":"used","resetType":"codexRateLimits"}]}}}
""")
check(swapped.weekly?.remaining == 58.5, "duration selects weekly despite swapped slots")
check(swapped.weekly?.percentage == "58%", "remaining rounds down")
check(swapped.fiveHour?.remaining == 0, "exhausted is real zero")
check(swapped.resetCardCount == 2 && swapped.resetCardExpirations.count == 1, "available cards only")
let absent = try parse("{\"result\":{\"rateLimits\":null}}")
check(absent.weekly == nil && absent.fiveHour == nil && absent.resetCardCount == nil, "missing is not zero")
let invalid = try parse("{\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":-1,\"windowDurationMins\":300}}}}")
check(invalid.fiveHour == nil, "invalid percent cannot look full")
let otherPool = try parse("{\"result\":{\"rateLimits\":{\"limitId\":\"other\",\"primary\":{\"usedPercent\":20,\"windowDurationMins\":300}}}}")
check(otherPool.fiveHour == nil, "other pool not Codex")
let map = try parse("{\"result\":{\"rateLimitsByLimitId\":{\"codex\":{\"secondary\":{\"usedPercent\":10,\"windowDurationMins\":300}}}}}")
check(map.fiveHour?.remaining == 90, "map fallback")
check(swapped.isStale(at: Date(timeIntervalSince1970: 1100)), "expired quota is stale")
do { _ = try parse("{\"error\":{\"code\":-1}}"); check(false, "RPC error") } catch { }
do { _ = try parse("{}"); check(false, "empty response") } catch { }
let roundTrip = try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(swapped))
check(roundTrip == swapped, "cache round trip")

// A silent helper must be killed at the deadline, not left resident.
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("codex-battery-test-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let helper = temporary.appendingPathComponent("silent-codex")
let pidFile = temporary.appendingPathComponent("pid")
try "#!/bin/sh\necho $$ > '\(pidFile.path)'\nexec /bin/sleep 30\n".write(to: helper, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
let start = Date()
do { _ = try CodexClient(customPath: helper.path, timeout: 2).fetch(); check(false, "silent process times out") }
catch UsageError.timeout { }
catch { check(false, "expected timeout, got \(error)") }
check(Date().timeIntervalSince(start) < 4, "timeout cleanup bounded")
let childPID = Int32(try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
check(kill(childPID, 0) == -1 && errno == ESRCH, "timed-out child reaped")
print("PASS: parsing, cache, expired data, timeout and child cleanup")

if CommandLine.arguments.contains("--live") {
    let start = Date()
    let snapshot = try CodexClient().fetch()
    check(snapshot.hasData, "live account exposes quota")
    // No account identifiers or raw RPC output are written.
    print("LIVE PASS: weekly=\(snapshot.weekly?.percentage ?? "missing"), fiveHour=\(snapshot.fiveHour?.percentage ?? "missing"), cards=\(snapshot.cardLabel), query=\(String(format: "%.2f", Date().timeIntervalSince(start)))s")
}

// Quit while a refresh is in flight: only our own child is cancelled and reaped.
try FileManager.default.removeItem(at: pidFile)
let finished = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .utility).async {
    _ = try? CodexClient(customPath: helper.path, timeout: 10).fetch()
    finished.signal()
}
let launchDeadline = Date().addingTimeInterval(4)
while !FileManager.default.fileExists(atPath: pidFile.path) && Date() < launchDeadline { Thread.sleep(forTimeInterval: 0.02) }
check(FileManager.default.fileExists(atPath: pidFile.path), "shutdown helper launched")
let shutdownPID = Int32(try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
CodexClient.stopAll()
check(finished.wait(timeout: .now() + 2) == .success, "quit cancels in-flight query")
check(kill(shutdownPID, 0) == -1 && errno == ESRCH, "quit child reaped")
print("PASS: quit during refresh cleans up child")
