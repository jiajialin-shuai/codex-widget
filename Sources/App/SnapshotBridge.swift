import Foundation
import Network

/// A sleeping, read-only loopback bridge. No authentication material is served.
final class SnapshotBridge: @unchecked Sendable {
    private let queue = DispatchQueue(label: "CodexBattery.snapshot", qos: .utility)
    private var listener: NWListener?
    private var data = Data()

    func start(snapshot: UsageSnapshot, failure: @escaping @Sendable (String) -> Void) {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 49763)
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: params)
            self.listener = listener
            data = try JSONEncoder().encode(snapshot)
            listener.stateUpdateHandler = { state in
                if case .failed = state { failure("小组件缓存服务未启动，端口 49763 可能已被占用。") }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
            listener.start(queue: queue)
        } catch { failure("无法启动小组件缓存服务。") }
    }
    func update(_ snapshot: UsageSnapshot) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        queue.async { self.data = encoded }
    }
    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 3) { connection.cancel() }
        receive(connection, buffer: Data())
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] chunk, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = buffer
            if let chunk { request.append(chunk) }
            guard request.count <= 8192, error == nil else { connection.cancel(); return }
            if request.range(of: Data("\r\n\r\n".utf8)) == nil {
                if complete { connection.cancel() } else { self.receive(connection, buffer: request) }
                return
            }
            let valid = SnapshotRequest.isAllowed(request)
            let body = valid ? self.data : Data()
            let status = valid ? "200 OK" : "404 Not Found"
            var response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nCross-Origin-Resource-Policy: same-origin\r\nContent-Security-Policy: default-src 'none'; frame-ancestors 'none'\r\nConnection: close\r\n\r\n".utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
