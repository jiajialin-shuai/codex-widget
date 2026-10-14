import AppKit
import SwiftUI
import WidgetKit

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()
    @Published var snapshot = SnapshotCache.load()
    @Published var refreshing = false
    @Published var bridgeError: String?
    @Published var desktopEnabled: Bool {
        didSet { UserDefaults.standard.set(desktopEnabled, forKey: "desktopEnabled") }
    }
    @Published var desktopSize: String {
        didSet { UserDefaults.standard.set(desktopSize, forKey: "desktopSize") }
    }
    @Published var desktopGlassStyle: String {
        didSet { UserDefaults.standard.set(desktopGlassStyle, forKey: "desktopGlassStyle") }
    }
    @Published var intervalMinutes: Int {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes"); schedule() }
    }
    @Published var customPath: String {
        didSet { UserDefaults.standard.set(customPath, forKey: "customPath") }
    }
    private var timer: Timer?
    private var sleeping = false
    private var failures = 0
    private var lastAttempt: Date?
    private let bridge = SnapshotBridge()
    private var observers: [NSObjectProtocol] = []

    init() {
        let stored = UserDefaults.standard.integer(forKey: "intervalMinutes")
        intervalMinutes = [15, 30, 60].contains(stored) ? stored : 15
        desktopEnabled = UserDefaults.standard.bool(forKey: "desktopEnabled")
        desktopSize = UserDefaults.standard.string(forKey: "desktopSize") ?? "small"
        desktopGlassStyle = UserDefaults.standard.string(forKey: "desktopGlassStyle") ?? "regular"
        customPath = UserDefaults.standard.string(forKey: "customPath") ?? ""
        snapshot.isOffline = true
        bridge.start(snapshot: snapshot) { [weak self] error in
            Task { @MainActor in self?.bridgeError = error }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = true; self?.timer?.invalidate() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sleeping = false; self?.refresh() }
        })
        refresh()
    }
    func opened() {
        if lastAttempt == nil || Date().timeIntervalSince(lastAttempt!) > 60 { refresh() }
    }
    func refresh() {
        guard !refreshing, !sleeping else { return }
        refreshing = true
        lastAttempt = Date()
        timer?.invalidate()
        let client = CodexClient(customPath: customPath)
        Task {
            let result = await Task.detached(priority: .utility) { () -> Result<UsageSnapshot, Error> in
                Result { try client.fetch() }
            }.value
            switch result {
            case .success(let value):
                snapshot = value; failures = 0
                if !snapshot.hasData { snapshot.error = "当前登录未提供周额度或五小时额度，请检查 Codex 账号。" }
            case .failure(let error):
                snapshot.error = (error as? UsageError)?.localizedDescription ?? "暂时无法读取额度，请稍后刷新。"
                failures += 1
            }
            do { try SnapshotCache.save(snapshot) }
            catch { snapshot.error = "缓存写入失败，小组件可能无法显示最新数据。" }
            bridge.update(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: "CodexBatteryWidget")
            refreshing = false
            schedule()
        }
    }
    private func schedule() {
        timer?.invalidate()
        guard !sleeping, !refreshing else { return }
        var delay = Double(intervalMinutes * 60)
        if failures > 0 { delay = max(delay, failures == 1 ? 1800 : 3600) }
        if failures == 0 {
            for reset in [snapshot.weekly?.resetsAt, snapshot.fiveHour?.resetsAt].compactMap({ $0 }) {
                let until = reset.timeIntervalSinceNow + 10
                if until > 0 { delay = min(delay, max(60, until)) }
            }
        }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = min(60, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
