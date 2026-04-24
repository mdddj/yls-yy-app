import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum CodexMonitorWidgetBridge {
    static let appGroupIdentifier = "group.shop.itbug.yls-app"
    static let snapshotFilename = "codex-monitor-widget-snapshot.json"
    static let widgetKind = "YLSStatusWidget"

    static func snapshotURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(snapshotFilename)
    }

    static func writeSnapshot(_ data: Data) {
        guard let snapshotURL = snapshotURL() else { return }
        try? data.write(to: snapshotURL, options: [.atomic])

        #if canImport(WidgetKit)
        if #available(macOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
