import SwiftUI

enum BatteryLayout { case small, medium, large }

struct BatteryRing: View {
    let window: QuotaWindow?
    let title: String
    let symbol: String
    var diameter: CGFloat = 58
    var dimmed = false

    private var tint: Color {
        guard let remaining = window?.remaining else { return .secondary }
        if dimmed { return .secondary }
        if remaining <= 10 { return Color(nsColor: .systemRed) }
        if remaining <= 20 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .systemGreen)
    }
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().stroke(.primary.opacity(0.11), lineWidth: diameter * 0.075)
                if let remaining = window?.remaining, remaining > 0 {
                    Circle().trim(from: 0, to: remaining / 100)
                        .stroke(tint, style: StrokeStyle(lineWidth: diameter * 0.075, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Image(systemName: symbol)
                    .font(.system(size: diameter * 0.36, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(diameter * 0.05)
            .frame(width: diameter, height: diameter)
            Text(window?.percentage ?? "—")
                .font(.system(size: diameter > 70 ? 23 : 18, weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)，\(window.map { "剩余\($0.percentage)" } ?? "未提供")\(dimmed ? "，缓存数据" : "")")
    }
}

struct BatteryContent: View {
    let snapshot: UsageSnapshot
    let layout: BatteryLayout
    var date = Date()
    private var stale: Bool { snapshot.isStale(at: date) }

    var body: some View {
        switch layout {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }
    private var small: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 0) {
                ring(weekly: true, diameter: 57).frame(maxWidth: .infinity)
                ring(weekly: false, diameter: 57).frame(maxWidth: .infinity)
            }
            if stale {
                Text(snapshot.hasData ? "缓存 · 打开刷新" : "打开以获取额度")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var medium: some View {
        HStack(spacing: 20) {
            VStack(spacing: 6) {
                ring(weekly: true, diameter: 68)
                reset(snapshot.weekly).font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
            VStack(spacing: 6) {
                ring(weekly: false, diameter: 68)
                reset(snapshot.fiveHour).font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if stale { Image(systemName: "clock.badge.exclamationmark").font(.system(size: 11)).foregroundStyle(.secondary).accessibilityLabel("缓存数据") }
        }
    }
    private var large: some View {
        VStack(spacing: 13) {
            HStack {
                Text("Codex").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(snapshot.planLabel).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 32) {
                ring(weekly: true, diameter: 81).frame(maxWidth: .infinity)
                ring(weekly: false, diameter: 81).frame(maxWidth: .infinity)
            }
            VStack(spacing: 8) {
                info("周额度重置", value: resetLabel(snapshot.weekly?.resetsAt))
                info("五小时重置", value: resetLabel(snapshot.fiveHour?.resetsAt))
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("重置卡", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(snapshot.cardLabel).font(.system(size: 22, weight: .medium, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("最近到期").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(snapshot.resetCardExpirations.first.map { $0.formatted(.dateTime.month().day()) } ??
                         (snapshot.resetCardCount == 0 ? "无可用卡" : "未提供"))
                        .font(.system(size: 13, weight: .medium))
                    if let balance = snapshot.creditBalance {
                        Text("积分余额 \(balance)").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Circle().fill(stale ? Color.secondary : Color(nsColor: .systemGreen)).frame(width: 5, height: 5)
                Text(stale ? "缓存数据" : "已更新").font(.system(size: 10))
                if let updated = snapshot.updatedAt { Text(updated, style: .time).font(.system(size: 10)) }
                Spacer()
                Image(systemName: "battery.100percent").font(.system(size: 12))
            }.foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func ring(weekly: Bool, diameter: CGFloat) -> some View {
        BatteryRing(window: weekly ? snapshot.weekly : snapshot.fiveHour,
                    title: weekly ? "周额度" : "五小时", symbol: weekly ? "calendar" : "clock",
                    diameter: diameter, dimmed: stale)
    }
    private func info(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }.font(.system(size: 11))
    }
    private func reset(_ window: QuotaWindow?) -> some View {
        Text(resetLabel(window?.resetsAt))
    }
    private func resetLabel(_ reset: Date?) -> String {
        guard let reset else { return "未提供" }
        if reset <= date { return "等待更新" }
        let format: Date.FormatStyle = Calendar.current.isDate(reset, inSameDayAs: date)
            ? .dateTime.hour().minute() : .dateTime.month().day().hour().minute()
        return reset.formatted(format)
    }
}
