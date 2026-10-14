import Foundation
import Darwin

struct CodexClient: Sendable {
    var customPath: String = ""
    var timeout: TimeInterval = 25
    static func stopAll() { ActiveCodexProcesses.shared.stopAll() }

    func executableURL() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [customPath,
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"] +
            (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/codex" }
        if !customPath.isEmpty {
            guard FileManager.default.isExecutableFile(atPath: customPath) else { throw UsageError.cliMissing }
            return URL(fileURLWithPath: customPath)
        }
        guard let path = candidates.first(where: { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }) else { throw UsageError.cliMissing }
        return URL(fileURLWithPath: path)
    }

    func fetch() throws -> UsageSnapshot {
        let process = Process()
        process.executableURL = try executableURL()
        process.arguments = ["app-server", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: home)
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw UsageError.launch }
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                let limit = Date().addingTimeInterval(0.5)
                while process.isRunning && Date() < limit { Thread.sleep(forTimeInterval: 0.01) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit()
            ActiveCodexProcesses.shared.remove(process)
            try? output.fileHandleForReading.close()
        }
        guard ActiveCodexProcesses.shared.add(process) else { throw UsageError.launch }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var buffer = Data()
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func response(_ id: Int) throws -> Data {
            while ProcessInfo.processInfo.systemUptime < deadline {
                while let newline = buffer.firstIndex(of: 10) {
                    let line = Data(buffer.prefix(upTo: newline))
                    buffer.removeSubrange(...newline)
                    if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                       object["id"] as? Int == id {
                        if object["error"] != nil { throw UsageError.rpc }
                        return line
                    }
                }
                var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
                let wait = min(1000, max(1, Int((deadline - ProcessInfo.processInfo.systemUptime) * 1000)))
                let ready = poll(&descriptor, 1, Int32(wait))
                if ready < 0 { if errno == EINTR { continue }; throw UsageError.invalidResponse }
                if ready > 0 {
                    var bytes = [UInt8](repeating: 0, count: 8192)
                    let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
                    guard count > 0 else { throw UsageError.invalidResponse }
                    buffer.append(contentsOf: bytes.prefix(count))
                    guard buffer.count <= 4 * 1024 * 1024 else { throw UsageError.invalidResponse }
                }
            }
            throw UsageError.timeout
        }
        try send(["id": 1, "method": "initialize", "params": [
            "clientInfo": ["name": "codex_battery", "version": "0.1.0"],
            "capabilities": ["experimentalApi": true]]])
        _ = try response(1)
        try send(["method": "initialized", "params": [:]])
        try send(["id": 2, "method": "account/rateLimits/read", "params": [:]])
        return try UsageSnapshot.parse(response(2))
    }
}

private final class ActiveCodexProcesses: @unchecked Sendable {
    static let shared = ActiveCodexProcesses()
    private let lock = NSLock()
    private var processes: [Process] = []
    private var shuttingDown = false
    func add(_ process: Process) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !shuttingDown else { return false }
        processes.append(process)
        return true
    }
    func remove(_ process: Process) {
        lock.lock(); defer { lock.unlock() }
        processes.removeAll { $0 === process }
    }
    func stopAll() {
        lock.lock()
        shuttingDown = true
        let active = processes
        lock.unlock()
        for process in active where process.isRunning { process.terminate() }
        let deadline = Date().addingTimeInterval(0.5)
        while active.contains(where: { $0.isRunning }) && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        for process in active where process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
}
