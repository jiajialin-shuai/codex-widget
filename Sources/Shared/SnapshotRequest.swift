import Foundation

/// Browser isolation, not authentication: local native software can reproduce this request.
enum SnapshotRequest {
    static let clientHeader = "X-CodexBattery-Client"
    static let clientValue = "widget-v1"

    static func isAllowed(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8),
              let end = text.range(of: "\r\n\r\n"), end.upperBound == text.endIndex else { return false }
        let lines = text[..<end.lowerBound].components(separatedBy: "\r\n")
        guard let first = lines.first,
              ["GET /snapshot HTTP/1.1", "GET /snapshot HTTP/1.0"].contains(first) else { return false }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":"), !line.hasPrefix(" "), !line.hasPrefix("\t") else { return false }
            let name = String(line[..<colon]).lowercased()
            guard !name.isEmpty, !name.contains(where: { $0.isWhitespace }), headers[name] == nil else { return false }
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard headers["host"] == "127.0.0.1:49763",
              headers[clientHeader.lowercased()] == clientValue else { return false }
        // Reject browser contexts, including navigations and preflights; no CORS is granted.
        guard !headers.keys.contains(where: { ["origin", "referer", "forwarded", "transfer-encoding"].contains($0) || $0.hasPrefix("sec-fetch-") }),
              headers["content-length"] == nil || headers["content-length"] == "0" else { return false }
        return true
    }
}
