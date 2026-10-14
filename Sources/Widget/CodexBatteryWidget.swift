import Foundation
import SwiftUI
import WidgetKit
import OSLog

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    var isPlaceholder = false
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: Date(), snapshot: .sample, isPlaceholder: true) }
    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        let snapshot = context.isPreview ? UsageSnapshot.sample : SnapshotCache.load()
        completion(BatteryEntry(date: Date(), snapshot: snapshot))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSnapshotLoader.load()
            let now = Date()
            var next = now.addingTimeInterval(900)
            for reset in [snapshot.weekly?.resetsAt, snapshot.fiveHour?.resetsAt].compactMap({ $0 }) {
                if reset > now { next = min(next, reset.addingTimeInterval(15)) }
            }
            var entries = [BatteryEntry(date: now, snapshot: snapshot)]
            // Mark old/expired values through an existing timeline entry, without another network request.
            let staleDates = [snapshot.updatedAt?.addingTimeInterval(3601), snapshot.weekly?.resetsAt,
                              snapshot.fiveHour?.resetsAt].compactMap { $0 }.filter { $0 > now }
            if let staleDate = staleDates.min(), !snapshot.isStale(at: now) {
                entries.append(BatteryEntry(date: staleDate, snapshot: snapshot))
            }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    private static let logger = Logger(subsystem: "com.jiajialin.codexbattery.widget", category: "Rendering")
    var body: some View {
        let _ = Self.logger.info("placeholder=\(entry.isPlaceholder, privacy: .public) hasData=\(entry.snapshot.hasData, privacy: .public) redaction=\(redactionReasons.rawValue, privacy: .public) mode=\(renderingMode.description, privacy: .public) background=\(showsBackground, privacy: .public)")
        BatteryContent(snapshot: entry.snapshot,
                       layout: family == .systemSmall ? .small : family == .systemMedium ? .medium : .large,
                       date: entry.date)
            // A real entry must not inherit a stuck loading mask. Retain any privacy redaction.
            .environment(\.redactionReasons, entry.isPlaceholder ? redactionReasons : redactionReasons.subtracting(.placeholder))
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "codexbattery://refresh"))
    }
}

@main
struct CodexBatteryWidget: Widget {
    let kind = "CodexBatteryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryProvider()) { entry in BatteryWidgetView(entry: entry) }
            .configurationDisplayName("Codex 电池")
            .description("查看周额度和五小时额度，了解重置时间与重置卡。")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .containerBackgroundRemovable(true)
    }
}
