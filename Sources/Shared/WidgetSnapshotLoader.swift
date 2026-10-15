import Foundation

enum WidgetSnapshotLoader {
    /// Only retrieves a sanitized snapshot. The widget never launches Codex.
    static func load() async -> UsageSnapshot {
        var snapshot = SnapshotCache.load()
        do {
            var request = URLRequest(url: SnapshotCache.endpoint)
            request.setValue(SnapshotRequest.clientValue, forHTTPHeaderField: SnapshotRequest.clientHeader)
            request.timeoutInterval = 3
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UsageError.invalidResponse }
            snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
            try SnapshotCache.save(snapshot)
        } catch { snapshot.isOffline = true }
        return snapshot
    }
}
