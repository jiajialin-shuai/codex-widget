import Foundation

@main
struct WidgetProbe {
    static func main() async throws {
        let snapshot = await WidgetSnapshotLoader.load()
        let offline = CommandLine.arguments.contains("--offline")
        guard snapshot.hasData, snapshot.isOffline == offline,
              offline || SnapshotCache.load() == snapshot else {
            fputs("FAIL: sandboxed widget could not fetch and cache real data\n", stderr)
            exit(1)
        }
        print(offline ? "PASS: sandboxed widget falls back to labeled offline cache" :
              "PASS: same widget loader, sandbox + network.client + ATS, real data fetch and cache")
    }
}
