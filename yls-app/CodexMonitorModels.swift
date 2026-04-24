import Foundation
import SwiftUI

enum DefaultsKey {
    static let apiKey = "api_key"
    static let agiAPIKey = "agi_api_key"
    static let interval = "poll_interval_seconds"
    static let displayStyle = "status_display_style"
    static let mcpEnabled = "mcp_enabled"
    static let mcpPort = "mcp_port"
}

enum AppMeta {
    static let displayName = "伊莉丝Codex账户监控助手"
    static let endpoint = URL(string: "https://codex.ylsagi.com/codex/info")!   
    static let agiPackageEndpoint = URL(string: "https://api.ylsagi.com/user/package")!
    static let agiEnvironmentKey = "YLS_AGI_KEY"
    static let dashboardURL = URL(string: "https://code.ylsagi.com/user/dashboard")!
    static let pricingURL = URL(string: "https://code.ylsagi.com/pricing")!
    static let appcastURL = URL(string: "https://mdddj.github.io/yls-yy-app/appcast.xml")!
    static let mcpHost = "127.0.0.1"
    static let defaultMCPPort: UInt16 = 8765
    static let preferredPanelWidth: CGFloat = 316
    static let stackedStatusMinWidth: CGFloat = 44
    static let stackedStatusMaxWidth: CGFloat = 72
    static let stackedHorizontalPadding: CGFloat = 4
    static let stackedStatusHeight: CGFloat = 18
    static let stackedLineGap: CGFloat = 1
    static let stackedVerticalNudge: CGFloat = -0.5
    static let stackedTopFontSize: CGFloat = 9.5
    static let stackedBottomFontSize: CGFloat = 7.5
    static let circleMinWidth: CGFloat = 44
    static let circleMaxWidth: CGFloat = 76
    static let circleHorizontalPadding: CGFloat = 4
    static let circleBottomFontSize: CGFloat = 8
    static let circleLineGap: CGFloat = 1
    static let circleLineWidth: CGFloat = 1.8
    static let circleDiameter: CGFloat = 13
}

enum StatusDisplayStyle: Int, CaseIterable, Identifiable {
    case remaining = 0
    case usedPercent
    case remainingPercent
    case stackedUsedPercent
    case stackedRemainingPercent
    case circleProgress

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .remaining:
            "样式1: 余:xx.xx（默认）"
        case .usedPercent:
            "样式2: 用:xx.xx%"
        case .remainingPercent:
            "样式3: 剩:xx.xx%"
        case .stackedUsedPercent:
            "样式4: 上下-上用量% 下已使用"
        case .stackedRemainingPercent:
            "样式5: 上下-上剩余% 下剩余"
        case .circleProgress:
            "样式6: 上圆圈 下余量"
        }
    }

    var chipTitle: String {
        switch self {
        case .remaining:
            "余量"
        case .usedPercent:
            "用量%"
        case .remainingPercent:
            "剩余%"
        case .stackedUsedPercent:
            "上下用"
        case .stackedRemainingPercent:
            "上下剩"
        case .circleProgress:
            "圆环"
        }
    }

    var selectorSymbol: String {
        switch self {
        case .remaining:
            "text.alignleft"
        case .usedPercent:
            "chart.bar.fill"
        case .remainingPercent:
            "chart.bar.doc.horizontal"
        case .stackedUsedPercent:
            "rectangle.split.2x1"
        case .stackedRemainingPercent:
            "rectangle.split.2x1.fill"
        case .circleProgress:
            "gauge.with.dots.needle.bottom.50percent"
        }
    }

    var selectorPreview: String {
        switch self {
        case .remaining:
            "余: 90.47"
        case .usedPercent:
            "用: 14.06%"
        case .remainingPercent:
            "剩: 85.94%"
        case .stackedUsedPercent:
            "14.06% / 已使用"
        case .stackedRemainingPercent:
            "85.94% / 剩余"
        case .circleProgress:
            "圆环 + 余量"
        }
    }
}

enum MenuPanelMode {
    case statistics
    case settings

    var toggleSymbol: String {
        switch self {
        case .statistics:
            "gearshape"
        case .settings:
            "chart.bar.xaxis"
        }
    }

    var toggleHint: String {
        switch self {
        case .statistics:
            "打开设置"
        case .settings:
            "返回统计信息"
        }
    }
}

enum ConfigurationWindowKind: String, Identifiable, CaseIterable {
    case apiKey
    case agiKey
    case interval
    case mcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiKey:
            "设置 Codex Key"
        case .agiKey:
            "设置 AGI Key"
        case .interval:
            "设置轮询间隔"
        case .mcp:
            "MCP 服务设置"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .apiKey, .agiKey:
            CGSize(width: 420, height: 180)
        case .interval:
            CGSize(width: 340, height: 170)
        case .mcp:
            CGSize(width: 420, height: 240)
        }
    }
}

struct APIEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let state: APIState?
    let error: String?
    let details: String?
}

struct APIState: Decodable {
    let user: APIUser?
    let package: PackagePayload?
    let userPackgeUsageWeek: UsagePayload?
    let userPackgeUsage: UsagePayload?
    let remainingQuota: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case user
        case package
        case userPackgeUsageWeek = "userPackgeUsage_week"
        case userPackgeUsage
        case remainingQuota = "remaining_quota"
    }
}

struct APIUser: Decodable {
    let email: String?
}

struct UsagePayload: Decodable {
    let remainingQuota: FlexibleNumber?
    let usedPercentage: FlexibleNumber?
    let totalCost: FlexibleNumber?
    let totalQuota: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case remainingQuota = "remaining_quota"
        case usedPercentage = "used_percentage"
        case totalCost = "total_cost"
        case totalQuota = "total_quota"
    }
}

struct PackagePayload: Decodable {
    let totalQuota: FlexibleNumber?
    let weeklyQuota: FlexibleNumber?
    let packages: [PackageItem]?

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case weeklyQuota
        case packages
    }
}

struct PackageItem: Decodable {
    let packageType: String?
    let packageStatus: String?
    let startAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case packageType = "package_type"
        case packageStatus = "package_status"
        case startAt = "start_at"
        case expiresAt = "expires_at"
    }
}

struct AGIPackageEnvelope: Decodable {
    let code: Int?
    let message: String?
    let data: AGIPackageData?
}

struct AGIPackageData: Decodable {
    let packages: [AGIPackageItem]?
    let summary: AGIPackageSummary?
}

struct AGIPackageItem: Decodable {
    let pkgID: String?
    let orderClass: String?
    let level: Int?
    let byteTotal: FlexibleNumber?
    let byteRemaining: FlexibleNumber?
    let byteUsed: FlexibleNumber?
    let day: Int?
    let expireTime: String?
    let createTime: String?
    let reason: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case pkgID = "pkg_id"
        case orderClass = "order_class"
        case level
        case byteTotal = "byte_total"
        case byteRemaining = "byte_remaining"
        case byteUsed = "byte_used"
        case day
        case expireTime
        case createTime
        case reason
        case type
    }
}

struct AGIPackageSummary: Decodable {
    let pkgID: String?
    let totalPackages: Int?
    let totalByte: FlexibleNumber?
    let remainingByte: FlexibleNumber?
    let usedByte: FlexibleNumber?
    let highestLevel: Int?
    let userType: String?
    let latestExpireTime: String?

    enum CodingKeys: String, CodingKey {
        case pkgID = "pkg_id"
        case totalPackages = "total_packages"
        case totalByte = "total_byte"
        case remainingByte = "remaining_byte"
        case usedByte = "used_byte"
        case highestLevel = "highest_level"
        case userType = "user_type"
        case latestExpireTime = "latest_expire_time"
    }
}

enum FlexibleNumber: Decodable {
    case int(Int)
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            FlexibleNumber.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported number format")
        )
    }

    nonisolated var display: String {
        switch self {
        case .int(let value):
            "\(value)"
        case .double(let value):
            if value.rounded() == value {
                "\(Int(value))"
            } else {
                String(format: "%.2f", value)
            }
        case .string(let value):
            value
        }
    }

    nonisolated var doubleValue: Double? {
        switch self {
        case .int(let value):
            Double(value)
        case .double(let value):
            value
        case .string(let value):
            Double(value.replacingOccurrences(of: "%", with: ""))
        }
    }
}

enum SummaryStatusTone: Hashable {
    case neutral
    case success
    case warning
    case critical

    var textColor: Color {
        switch self {
        case .neutral:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        case .critical:
            .red
        }
    }

    var fillColor: Color {
        textColor.opacity(0.12)
    }

    var borderColor: Color {
        textColor.opacity(0.22)
    }
}

struct SummaryPackageItem: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeTone: SummaryStatusTone

    var id: String {
        "\(title)|\(subtitle)|\(badgeText)"
    }
}

struct MountedPackageModuleSummary: Identifiable, Hashable {
    let title: String
    let statusText: String
    let statusTone: SummaryStatusTone
    let usageLabel: String
    let usageValue: String
    let remainingLabel: String
    let remainingValue: String
    let renewalLabel: String
    let renewalValue: String
    let progressLabel: String
    let progressValue: String
    let progress: Double?
    let footerText: String
    let packageSectionTitle: String?
    let packageItems: [SummaryPackageItem]

    var id: String { title }
}

struct StatusSummaryViewModel {
    let title: String
    let statusText: String
    let statusTone: SummaryStatusTone
    let emailText: String
    let canToggleEmail: Bool
    let isEmailVisible: Bool
    let usageLabel: String
    let usageValue: String
    let remainingValue: String
    let renewalLabel: String
    let renewalValue: String
    let packageSectionTitle: String?
    let packageItems: [SummaryPackageItem]
    let progressLabel: String
    let progressPrefix: String?
    let progressValue: String
    let progress: Double?
    let footerText: String
    let hasAPIKey: Bool
    let hasAGIKey: Bool
    let pollIntervalText: String
    let displayStyle: StatusDisplayStyle
    let panelMode: MenuPanelMode
    let mcpStatusText: String
    let mountedModules: [MountedPackageModuleSummary]

    static let placeholder = StatusSummaryViewModel(
        title: AppMeta.displayName,
        statusText: "等待中",
        statusTone: .neutral,
        emailText: "--",
        canToggleEmail: false,
        isEmailVisible: false,
        usageLabel: "已用/总",
        usageValue: "--",
        remainingValue: "--",
        renewalLabel: "最近到期",
        renewalValue: "--",
        packageSectionTitle: nil,
        packageItems: [],
        progressLabel: "本周用量进度",
        progressPrefix: nil,
        progressValue: "--",
        progress: nil,
        footerText: "等待数据",
        hasAPIKey: false,
        hasAGIKey: false,
        pollIntervalText: "--",
        displayStyle: .remaining,
        panelMode: .statistics,
        mcpStatusText: "MCP 未启动",
        mountedModules: []
    )
}

struct StatusBarPresentation {
    let style: StatusDisplayStyle
    let fallbackText: String
    let remainingText: String
    let usageText: String
    let usedPercent: Double?

    var clampedUsedPercent: Double? {
        usedPercent.map { min(max($0, 0), 100) }
    }

    var remainingPercent: Double? {
        clampedUsedPercent.map { max(0, 100 - $0) }
    }
}

extension StatusSummaryViewModel {
    static let previewOnline = StatusSummaryViewModel(
        title: AppMeta.displayName,
        statusText: "在线",
        statusTone: .success,
        emailText: "dev@ylsagi.com",
        canToggleEmail: true,
        isEmailVisible: true,
        usageLabel: "已用/总",
        usageValue: "14.06/100.00",
        remainingValue: "85.94",
        renewalLabel: "最近到期",
        renewalValue: "04-30 23:59（7天后）",
        packageSectionTitle: "有效套餐（2）",
        packageItems: [
            SummaryPackageItem(
                title: "Codex Pro",
                subtitle: "生效 04-01 00:00  到期 04-30 23:59",
                badgeText: "剩7天",
                badgeTone: .warning
            ),
            SummaryPackageItem(
                title: "Extra Pack",
                subtitle: "生效 04-10 00:00  到期 05-10 23:59",
                badgeText: "剩17天",
                badgeTone: .success
            ),
        ],
        progressLabel: "本周用量进度",
        progressPrefix: "14.06/100.00",
        progressValue: "14.06%",
        progress: 0.1406,
        footerText: "更新时间: 16:18:20",
        hasAPIKey: true,
        hasAGIKey: true,
        pollIntervalText: "5 秒",
        displayStyle: .circleProgress,
        panelMode: .statistics,
        mcpStatusText: "http://127.0.0.1:8765/mcp/snapshot",
        mountedModules: [
            MountedPackageModuleSummary(
                title: "AGI 套餐",
                statusText: "已挂载",
                statusTone: .success,
                usageLabel: "已用/总字节",
                usageValue: "18,274 B / 8,000,000 B",
                remainingLabel: "剩余字节",
                remainingValue: "7,981,726 B",
                renewalLabel: "最近到期",
                renewalValue: "07-23 08:25（91天后）",
                progressLabel: "AGI 用量进度",
                progressValue: "0.23%",
                progress: 0.0023,
                footerText: "更新时间: 16:18:20",
                packageSectionTitle: "已挂载套餐（1）",
                packageItems: [
                    SummaryPackageItem(
                        title: "Pro Lv4",
                        subtitle: "开通 04-21 08:25  到期 07-23 08:25",
                        badgeText: "剩91天",
                        badgeTone: .success
                    ),
                ]
            ),
        ]
    )

    static let previewSettings = StatusSummaryViewModel(
        title: AppMeta.displayName,
        statusText: "在线",
        statusTone: .success,
        emailText: "***",
        canToggleEmail: true,
        isEmailVisible: false,
        usageLabel: "已用/总",
        usageValue: "14.06/100.00",
        remainingValue: "85.94",
        renewalLabel: "最近到期",
        renewalValue: "04-30 23:59（7天后）",
        packageSectionTitle: "当前套餐",
        packageItems: [
            SummaryPackageItem(
                title: "Codex Pro",
                subtitle: "生效 04-01 00:00  到期 04-30 23:59",
                badgeText: "剩7天",
                badgeTone: .warning
            ),
        ],
        progressLabel: "本周用量进度",
        progressPrefix: "14.06/100.00",
        progressValue: "14.06%",
        progress: 0.1406,
        footerText: "更新时间: 16:18:20",
        hasAPIKey: true,
        hasAGIKey: true,
        pollIntervalText: "5 秒",
        displayStyle: .stackedUsedPercent,
        panelMode: .settings,
        mcpStatusText: "http://127.0.0.1:8765/mcp/snapshot",
        mountedModules: [
            MountedPackageModuleSummary(
                title: "AGI 套餐",
                statusText: "已挂载",
                statusTone: .success,
                usageLabel: "已用/总字节",
                usageValue: "18,274 B / 8,000,000 B",
                remainingLabel: "剩余字节",
                remainingValue: "7,981,726 B",
                renewalLabel: "最近到期",
                renewalValue: "07-23 08:25（91天后）",
                progressLabel: "AGI 用量进度",
                progressValue: "0.23%",
                progress: 0.0023,
                footerText: "更新时间: 16:18:20",
                packageSectionTitle: "已挂载套餐（1）",
                packageItems: [
                    SummaryPackageItem(
                        title: "Pro Lv4",
                        subtitle: "开通 04-21 08:25  到期 07-23 08:25",
                        badgeText: "剩91天",
                        badgeTone: .success
                    ),
                ]
            ),
        ]
    )

    static let previewWarning = StatusSummaryViewModel(
        title: AppMeta.displayName,
        statusText: "未配置",
        statusTone: .warning,
        emailText: "--",
        canToggleEmail: false,
        isEmailVisible: false,
        usageLabel: "已用/总",
        usageValue: "--",
        remainingValue: "--",
        renewalLabel: "最近到期",
        renewalValue: "--",
        packageSectionTitle: nil,
        packageItems: [],
        progressLabel: "本周用量进度",
        progressPrefix: nil,
        progressValue: "--",
        progress: nil,
        footerText: "请先设置 API Key",
        hasAPIKey: false,
        hasAGIKey: false,
        pollIntervalText: "5 秒",
        displayStyle: .remaining,
        panelMode: .statistics,
        mcpStatusText: "已关闭",
        mountedModules: []
    )
}
