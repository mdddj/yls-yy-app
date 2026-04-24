import SwiftUI
import WidgetKit

private enum YLSStatusWidgetMeta {
    static let kind = "YLSStatusWidget"
    static let appGroupIdentifier = "group.shop.itbug.yls-app"
    static let snapshotFilename = "codex-monitor-widget-snapshot.json"
}

private struct WidgetSnapshotPayload: Decodable {
    let generatedAt: String?
    let displayName: String?
    let statusText: String?
    let latestMessage: String?
    let remaining: String?
    let usedPercent: Double?
    let hasAPIKey: Bool?
    let hasAGIKey: Bool?
    let mcpStatusText: String?
    let mountedModules: [WidgetMountedModule]?

    var codexRemainingFraction: Double? {
        guard let usedPercent else { return nil }
        return max(0, min(1, 1 - (usedPercent / 100)))
    }

    var primaryModule: WidgetMountedModule? {
        mountedModules?.first
    }

    var agiRemainingFraction: Double? {
        guard let progressFraction = primaryModule?.progressFraction else { return nil }
        return max(0, min(1, 1 - progressFraction))
    }

    var keysFraction: Double {
        let codex = (hasAPIKey ?? false) ? 0.5 : 0
        let agi = (hasAGIKey ?? false) ? 0.5 : 0
        return codex + agi
    }

    var mcpFraction: Double {
        guard let status = mcpStatusText?.lowercased() else { return 0 }
        if status.contains("http://") || status.contains("https://") {
            return 1
        }
        if status.contains("启动中") {
            return 0.5
        }
        return 0
    }

    var mcpDisplayText: String {
        let status = mcpStatusText ?? "未启动"
        if status.contains("http://") || status.contains("https://") {
            return "在线"
        }
        return status
    }

    var codexRemainingPercentDisplay: String {
        Self.percentString(codexRemainingFraction) ?? "--"
    }

    var agiRemainingPercentDisplay: String {
        Self.percentString(agiRemainingFraction) ?? "--"
    }

    private static func percentString(_ fraction: Double?) -> String? {
        guard let fraction, fraction.isFinite else {
            return nil
        }
        return String(format: "%.2f%%", max(0, min(1, fraction)) * 100)
    }

    static let sample = WidgetSnapshotPayload(
        generatedAt: "2026-04-24T10:00:00Z",
        displayName: "伊莉丝Codex账户监控助手",
        statusText: "在线",
        latestMessage: "更新时间: 10:00:00",
        remaining: "85.94",
        usedPercent: 14.06,
        hasAPIKey: true,
        hasAGIKey: true,
        mcpStatusText: "http://127.0.0.1:8765/mcp/snapshot",
        mountedModules: [
            WidgetMountedModule(
                title: "AGI 套餐",
                statusText: "已挂载",
                remaining: "7,981,726 B",
                usage: "18,274 B / 8,000,000 B",
                renewal: "07-23 08:25（91天后）",
                progressValue: "0.23%",
                progressFraction: 0.0023,
                packageItems: []
            ),
        ]
    )
}

private struct WidgetMountedModule: Decodable {
    let title: String?
    let statusText: String?
    let remaining: String?
    let usage: String?
    let renewal: String?
    let progressValue: String?
    let progressFraction: Double?
    let packageItems: [WidgetPackageItem]?
}

private struct WidgetPackageItem: Decodable {
    let title: String?
    let subtitle: String?
    let badgeText: String?
}

private struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotPayload?
}

private enum WidgetSnapshotStore {
    static func load() -> WidgetSnapshotPayload? {
        guard let snapshotURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: YLSStatusWidgetMeta.appGroupIdentifier)?
            .appendingPathComponent(YLSStatusWidgetMeta.snapshotFilename),
              let data = try? Data(contentsOf: snapshotURL)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetSnapshotPayload.self, from: data)
    }
}

private struct YLSStatusWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshotPayload.sample : WidgetSnapshotStore.load()
        completion(WidgetSnapshotEntry(date: .now, snapshot: snapshot ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let entry = WidgetSnapshotEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .sample)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 10, to: .now) ?? .now.addingTimeInterval(600)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

private struct RingTileModel {
    let title: String
    let value: String
    let symbol: String
    let progress: Double
    let tint: Color
}

private struct YLSStatusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WidgetSnapshotEntry

    private var snapshot: WidgetSnapshotPayload {
        entry.snapshot ?? .sample
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                YLSStatusSmallWidgetView(snapshot: snapshot)
            default:
                YLSStatusMediumWidgetView(snapshot: snapshot)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct YLSStatusSmallWidgetView: View {
    let snapshot: WidgetSnapshotPayload

    var body: some View {
        ZStack {
            PercentRingBadge(
                progress: snapshot.codexRemainingFraction ?? 0,
                tint: .green,
                value: snapshot.codexRemainingPercentDisplay,
                size: 134,
                lineWidth: 15
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

private struct YLSStatusMediumWidgetView: View {
    let snapshot: WidgetSnapshotPayload

    private var tiles: [RingTileModel] {
        [
            RingTileModel(
                title: "Codex",
                value: snapshot.codexRemainingPercentDisplay,
                symbol: "cpu",
                progress: snapshot.codexRemainingFraction ?? 0,
                tint: .green
            ),
            RingTileModel(
                title: "AGI",
                value: snapshot.agiRemainingPercentDisplay,
                symbol: "shippingbox",
                progress: snapshot.agiRemainingFraction ?? 0,
                tint: .cyan
            ),
            RingTileModel(
                title: "Keys",
                value: "\(Int(snapshot.keysFraction * 2))/2",
                symbol: "key.horizontal",
                progress: snapshot.keysFraction,
                tint: .orange
            ),
            RingTileModel(
                title: "MCP",
                value: snapshot.mcpDisplayText,
                symbol: "server.rack",
                progress: snapshot.mcpFraction,
                tint: .purple
            ),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                    RingMetricTile(tile: tile)
                }
            }
        }
        .padding(14)
    }
}

private struct RingMetricTile: View {
    let tile: RingTileModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                RingBadge(
                    symbol: tile.symbol,
                    progress: tile.progress,
                    tint: tile.tint,
                    size: 44,
                    lineWidth: 6,
                    symbolSize: 13
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    ViewThatFits(in: .horizontal) {
                        Text(tile.value)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text(tile.value)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

private struct RingBadge: View {
    let symbol: String
    let progress: Double
    let tint: Color
    var size: CGFloat = 48
    var lineWidth: CGFloat = 7
    var symbolSize: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size, height: size)
    }
}

private struct PercentRingBadge: View {
    let progress: Double
    let tint: Color
    let value: String
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.04, min(progress, 1)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            ViewThatFits(in: .horizontal) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(value)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 20)
        }
        .frame(width: size, height: size)
    }
}

struct YLSStatusWidget: Widget {
    let kind: String = YLSStatusWidgetMeta.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YLSStatusWidgetProvider()) { entry in
            YLSStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("YLS 状态")
        .description("查看 Codex、AGI、Keys 和 MCP 的即时概览。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct YLSStatusWidgetBundle: WidgetBundle {
    var body: some Widget {
        YLSStatusWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    YLSStatusWidget()
} timeline: {
    WidgetSnapshotEntry(date: .now, snapshot: .sample)
}

#Preview("Medium", as: .systemMedium) {
    YLSStatusWidget()
} timeline: {
    WidgetSnapshotEntry(date: .now, snapshot: .sample)
}
