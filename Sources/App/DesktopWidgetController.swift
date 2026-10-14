import AppKit
import SwiftUI
import Combine

@MainActor
final class DesktopWidgetController: NSObject, NSWindowDelegate {
    private let store: UsageStore
    private let openSettings: () -> Void
    private var panel: NSPanel?
    private var preview: NSWindow?
    private var subscription: AnyCancellable?
    private var currentSize = ""

    init(store: UsageStore, openSettings: @escaping () -> Void) {
        self.store = store; self.openSettings = openSettings
        super.init()
        subscription = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.update() }
        }
        update()
    }
    private var size: CGSize {
        switch store.desktopSize {
        case "medium": CGSize(width: 338, height: 158)
        case "large": CGSize(width: 338, height: 354)
        default: CGSize(width: 158, height: 158)
        }
    }
    private func update() {
        guard store.desktopEnabled else {
            panel?.close(); panel?.contentView = nil; panel = nil
            return
        }
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Codex 透明桌面组件"
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isMovableByWindowBackground = true
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.delegate = self
            let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let saved = UserDefaults.standard.string(forKey: "desktopOrigin").map(NSPointFromString)
            let suggested = saved ?? NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 30)
            panel.setFrameOrigin(NSPoint(x: max(visible.minX, min(suggested.x, visible.maxX - size.width)),
                                         y: max(visible.minY, min(suggested.y, visible.maxY - size.height))))
            panel.contentView = surface(openSettings: openSettings)
            self.panel = panel
            currentSize = store.desktopSize
        }
        if currentSize != store.desktopSize {
            panel?.setContentSize(size)
            currentSize = store.desktopSize
        }
        if #available(macOS 26, *), let glass = panel?.contentView as? NSGlassEffectView {
            glass.style = store.desktopGlassStyle == "clear" ? .clear : .regular
        }
        panel?.orderFrontRegardless()
    }
    private func surface(openSettings: @escaping () -> Void) -> NSView {
        let host = TransparentHostingView(rootView: DesktopBatteryView(store: store, openSettings: openSettings))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: host.frame)
            glass.cornerRadius = 23
            glass.style = store.desktopGlassStyle == "clear" ? .clear : .regular
            glass.contentView = host
            if #available(macOS 27, *) { glass.effectIsInteractive = false }
            return glass
        }
        let material = NSVisualEffectView(frame: host.frame)
        material.material = .popover; material.blendingMode = .behindWindow; material.state = .active
        material.wantsLayer = true; material.layer?.cornerRadius = 23; material.layer?.masksToBounds = true
        material.addSubview(host)
        return material
    }
    func windowDidMove(_ notification: Notification) {
        if let panel { UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: "desktopOrigin") }
    }
    func showPreview() {
        if preview == nil {
            let preview = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
            preview.title = "Codex 透明材质预览"
            preview.isOpaque = false; preview.backgroundColor = .clear
            preview.hasShadow = true; preview.isReleasedWhenClosed = false
            preview.isMovableByWindowBackground = true
            preview.contentView = surface(openSettings: { [weak self] in
                self?.preview?.close(); self?.preview?.contentView = nil; self?.preview = nil
                self?.openSettings()
            })
            preview.center()
            self.preview = preview
        }
        NSApp.activate(ignoringOtherApps: true)
        preview?.makeKeyAndOrderFront(nil)
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { true }
}

private struct DesktopBatteryView: View {
    @ObservedObject var store: UsageStore
    let openSettings: () -> Void
    var body: some View {
        BatteryContent(snapshot: store.snapshot,
                       layout: store.desktopSize == "small" ? .small : store.desktopSize == "medium" ? .medium : .large)
            .padding(16)
            .clipShape(RoundedRectangle(cornerRadius: 23))
            .contentShape(RoundedRectangle(cornerRadius: 23))
            .onTapGesture(count: 2, perform: openSettings)
            .contextMenu {
                Button("刷新额度") { store.refresh() }
                Button("设置…", action: openSettings)
                Button("隐藏桌面组件") { store.desktopEnabled = false }
            }
            .accessibilityLabel("Codex 透明桌面组件，双击打开设置")
    }
}
