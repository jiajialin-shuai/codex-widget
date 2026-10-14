import AppKit
import SwiftUI
import ServiceManagement

@main
struct CodexBatteryApp: App {
    @StateObject private var store = UsageStore.shared
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra("Codex 额度", systemImage: "battery.100percent", isInserted: $showMenuBarIcon) {
            VStack(spacing: 12) {
                BatteryContent(snapshot: store.snapshot, layout: .large)
                    .frame(width: 285, height: 310)
                if let error = store.bridgeError ?? store.snapshot.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                HStack {
                    Button(store.refreshing ? "更新中…" : "刷新", systemImage: "arrow.clockwise") { store.refresh() }
                        .disabled(store.refreshing)
                    Spacer()
                    Button("设置…") { delegate.showWindow(store: store) }
                    Button("退出") { NSApp.terminate(nil) }
                }.font(.system(size: 12))
            }.padding(16).frame(width: 317)
                .onAppear { store.opened() }
        }.menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = UsageStore.shared // Refresh even when the menu bar item is hidden.
        // Main app menu remains available for a visible preview/settings window.
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Codex Battery")
        let quit = NSMenuItem(title: "退出 Codex Battery", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)
        appItem.submenu = appMenu; menu.addItem(appItem); NSApp.mainMenu = menu
        if CommandLine.arguments.contains("--preview") { showWindow(store: .shared) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(store: .shared)
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func showWindow(store: UsageStore) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Codex Battery"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.backgroundColor = .windowBackgroundColor
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        let store = UsageStore.shared
        store.refresh()
        showWindow(store: store)
    }
    func applicationWillTerminate(_ notification: Notification) { CodexClient.stopAll() }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @State private var loginError: String?
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Codex 电池").font(.system(size: 26, weight: .semibold))
                    Text("像看电量一样，看剩余额度。").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.refreshing ? "更新中…" : "刷新额度", systemImage: "arrow.clockwise") { store.refresh() }
                    .disabled(store.refreshing)
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    preview(.small, width: 158, height: 158, label: "小号")
                    preview(.medium, width: 338, height: 158, label: "中号")
                }
                preview(.large, width: 338, height: 354, label: "大号")
            }.frame(maxWidth: .infinity)
            Text("预览使用当前账号数据。添加到桌面：右键桌面 → 编辑小组件 → 搜索“Codex”。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 24) {
                Picker("刷新间隔", selection: $store.intervalMinutes) {
                    Text("15 分钟").tag(15); Text("30 分钟").tag(30); Text("60 分钟").tag(60)
                }.frame(width: 230)
                Toggle("登录时启动", isOn: $loginEnabled).onChange(of: loginEnabled) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch { loginError = "无法更改启动设置，请检查系统“登录项”。" }
                    loginEnabled = SMAppService.mainApp.status == .enabled
                }
                Spacer()
            }
            Toggle("显示菜单栏图标", isOn: $showMenuBarIcon)
                .font(.system(size: 12))
            HStack {
                Text("Codex 路径").font(.system(size: 12))
                TextField("自动查找（可留空）", text: $store.customPath).textFieldStyle(.roundedBorder)
                Button("选择…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true
                    if panel.runModal() == .OK, let path = panel.url?.path { store.customPath = path; store.refresh() }
                }
            }
            if let error = loginError ?? store.bridgeError ?? store.snapshot.error {
                Text(error).font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                Text("空闲时不运行 Codex 子进程；小组件由系统调度刷新。重置卡仅供查看。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.padding(28)
            .background(NativeMaterial(material: .windowBackground))
            .onAppear { store.opened() }
    }
    private func preview(_ layout: BatteryLayout, width: CGFloat, height: CGFloat, label: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            BatteryContent(snapshot: store.snapshot, layout: layout)
                .padding(16).frame(width: width, height: height)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(.primary.opacity(0.06), lineWidth: 1))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

/// App-only preview material. WidgetKit supplies its own desktop background.
struct NativeMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var cornerRadius: CGFloat = 0
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = cornerRadius > 0
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) { view.material = material }
}
