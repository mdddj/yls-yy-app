import AppKit
import Foundation
import Network
import SwiftUI

private enum DefaultsKey {
    static let apiKey = "api_key"
    static let interval = "poll_interval_seconds"
    static let displayStyle = "status_display_style"
    static let mcpEnabled = "mcp_enabled"
    static let mcpPort = "mcp_port"
}

private enum AppMeta {
    static let displayName = "伊莉丝Codex账户监控助手"
    static let dashboardURL = "https://code.ylsagi.com/user/dashboard"
    static let pricingURL = "https://code.ylsagi.com/pricing"
    static let mcpHost = "127.0.0.1"
    static let defaultMCPPort: UInt16 = 8765
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

private enum StatusDisplayStyle: Int, CaseIterable {
    case remaining = 0
    case usedPercent
    case remainingPercent
    case stackedUsedPercent
    case stackedRemainingPercent
    case circleProgress

    var title: String {
        switch self {
        case .remaining:
            return "样式1: 余:xx.xx（默认）"
        case .usedPercent:
            return "样式2: 用:xx.xx%"
        case .remainingPercent:
            return "样式3: 剩:xx.xx%"
        case .stackedUsedPercent:
            return "样式4: 上下-上用量% 下已使用"
        case .stackedRemainingPercent:
            return "样式5: 上下-上剩余% 下剩余"
        case .circleProgress:
            return "样式6: 上圆圈 下余量"
        }
    }

    var chipTitle: String {
        switch self {
        case .remaining:
            return "余量"
        case .usedPercent:
            return "用量%"
        case .remainingPercent:
            return "剩余%"
        case .stackedUsedPercent:
            return "上下用"
        case .stackedRemainingPercent:
            return "上下剩"
        case .circleProgress:
            return "圆环"
        }
    }

    var selectorSymbol: String {
        switch self {
        case .remaining:
            return "text.alignleft"
        case .usedPercent:
            return "chart.bar.fill"
        case .remainingPercent:
            return "chart.bar.doc.horizontal"
        case .stackedUsedPercent:
            return "rectangle.split.2x1"
        case .stackedRemainingPercent:
            return "rectangle.split.2x1.fill"
        case .circleProgress:
            return "gauge.with.dots.needle.bottom.50percent"
        }
    }

    var selectorPreview: String {
        switch self {
        case .remaining:
            return "余: 90.47"
        case .usedPercent:
            return "用: 14.06%"
        case .remainingPercent:
            return "剩: 85.94%"
        case .stackedUsedPercent:
            return "14.06% / 已使用"
        case .stackedRemainingPercent:
            return "85.94% / 剩余"
        case .circleProgress:
            return "圆环 + 余量"
        }
    }
}

private enum MenuPanelMode {
    case statistics
    case settings

    var toggleSymbol: String {
        switch self {
        case .statistics:
            return "gearshape"
        case .settings:
            return "chart.bar.xaxis"
        }
    }

    var toggleHint: String {
        switch self {
        case .statistics:
            return "打开设置"
        case .settings:
            return "返回统计信息"
        }
    }
}

private struct APIEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let state: APIState?
    let error: String?
    let details: String?
}

private struct APIState: Decodable {
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

private struct APIUser: Decodable {
    let email: String?
}

private struct UsagePayload: Decodable {
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

private struct PackagePayload: Decodable {
    let totalQuota: FlexibleNumber?
    let weeklyQuota: FlexibleNumber?
    let packages: [PackageItem]?

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case weeklyQuota
        case packages
    }
}

private struct PackageItem: Decodable {
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

private enum FlexibleNumber: Decodable {
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
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported number format"
            )
        )
    }

    var display: String {
        switch self {
        case .int(let value):
            return "\(value)"
        case .double(let value):
            if value.rounded() == value {
                return "\(Int(value))"
            }
            return String(format: "%.2f", value)
        case .string(let value):
            return value
        }
    }

    var doubleValue: Double? {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        case .string(let value):
            return Double(value.replacingOccurrences(of: "%", with: ""))
        }
    }
}

private enum SummaryStatusTone {
    case neutral
    case success
    case warning
    case critical

    var textColor: NSColor {
        switch self {
        case .neutral:
            return .secondaryLabelColor
        case .success:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    var fillColor: NSColor {
        textColor.withAlphaComponent(0.12)
    }

    var borderColor: NSColor {
        textColor.withAlphaComponent(0.22)
    }
}

private struct StatusSummaryViewModel {
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
    let pollIntervalText: String
    let displayStyle: StatusDisplayStyle
    let panelMode: MenuPanelMode
    let mcpStatusText: String
}

private struct SummaryPackageItem {
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeTone: SummaryStatusTone
}

private extension SummaryStatusTone {
    var swiftUIColor: Color { Color(nsColor: textColor) }
    var swiftUIFillColor: Color { Color(nsColor: fillColor) }
    var swiftUIBorderColor: Color { Color(nsColor: borderColor) }
}

private extension StatusSummaryViewModel {
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
        pollIntervalText: "--",
        displayStyle: .remaining,
        panelMode: .statistics,
        mcpStatusText: "MCP 未启动"
    )
}

private extension View {
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self
                .background {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular, in: Capsule())
                }
                .overlay {
                    Capsule().stroke(.quaternary, lineWidth: 0.8)
                }
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().stroke(.quaternary, lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    func compactSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self
                .background {
                    ZStack {
                        Rectangle()
                            .fill(.clear)
                            .glassEffect(.regular, in: shape)
                        shape
                            .fill(tint)
                    }
                }
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 0.8)
                }
        } else {
            self
                .background {
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial)
                        shape
                            .fill(tint)
                    }
                }
                .overlay {
                    shape.stroke(.quaternary, lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    func contentMaterialSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        self
            .background {
                ZStack {
                    shape
                        .fill(.regularMaterial)
                    shape
                        .fill(tint)
                }
            }
            .overlay {
                shape.stroke(.quaternary, lineWidth: 0.65)
            }
    }
}

private struct MenuActionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let shortcut: String?
    let prominent: Bool
    let action: (() -> Void)?
    let useInfoCardBackground: Bool

    @State private var isHovered = false

    init(
        title: String,
        subtitle: String?,
        systemImage: String,
        shortcut: String?,
        prominent: Bool,
        action: (() -> Void)?,
        useInfoCardBackground: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.prominent = prominent
        self.action = action
        self.useInfoCardBackground = useInfoCardBackground
    }

    private var compactTint: Color {
        prominent
            ? (isHovered ? .secondary.opacity(0.14) : .secondary.opacity(0.08))
            : (isHovered ? .primary.opacity(0.10) : .primary.opacity(0.04))
    }

    @ViewBuilder
    private func applySurface<Content: View>(to content: Content) -> some View {
        if useInfoCardBackground {
            content
                .contentMaterialSurface(cornerRadius: 15)
        } else {
            content
                .compactSurface(
                    cornerRadius: 15,
                    tint: compactTint
                )
        }
    }

    var body: some View {
        Button(action: { action?() }) {
            applySurface(
                to: HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(prominent ? .primary : .secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(.thinMaterial)
                        )

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)

                    if let shortcut {
                        Text(shortcut)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .overlay {
                if prominent, !useInfoCardBackground {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.tertiary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct StyleChipButton: View {
    let style: StatusDisplayStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: style.selectorSymbol)
                        .font(.system(size: 11, weight: .semibold))
                    Text(style.chipTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .foregroundStyle(isSelected ? .primary : .secondary)

                Text(style.selectorPreview)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentMaterialSurface(
                cornerRadius: 13,
                tint: isSelected
                    ? .secondary.opacity(0.16)
                    : (isHovered ? .primary.opacity(0.08) : .clear)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.tertiary, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct LiquidGlassSummaryPanel: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSetAPIKey: (() -> Void)?
    let onSetInterval: (() -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onConfigureMCP: (() -> Void)?
    let onQuit: (() -> Void)?

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            headerRow
            if model.panelMode == .statistics {
                statisticsPage
            } else {
                settingsPage
            }
        }
        .padding(12)
        .frame(width: StatusSummaryView.preferredWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statisticsPage: some View {
        VStack(alignment: .leading, spacing: 9) {
            metaRow
            contentPanel
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 9) {
            settingsHeaderBanner
            settingsActionPanel
        }
    }

    private var settingsHeaderBanner: some View {
        HStack(spacing: 10) {
            Label("设置模式", systemImage: "slider.horizontal.3")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 6)

            Text("点击右上角图标返回统计")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.92)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(
            cornerRadius: 14,
            tint: .secondary.opacity(0.12)
        )
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            heroPanel
            packageSection
            progressSection
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(model.title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Text(model.statusText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(model.statusTone.swiftUIColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(model.statusTone.swiftUIFillColor)
                    .overlay {
                        Capsule().stroke(model.statusTone.swiftUIBorderColor, lineWidth: 0.8)
                    }
                    .clipShape(Capsule())

                if shouldShowHeaderPanelToggle {
                    Button(action: togglePanelMode) {
                        Image(systemName: model.panelMode.toggleSymbol)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .modifier(GlassCapsuleModifier(glassNamespace: glassNamespace, id: "panel-mode-toggle"))
                }
            }
        }
    }

    private var shouldShowHeaderPanelToggle: Bool {
        model.panelMode == .settings || !model.canToggleEmail
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(model.footerText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            if model.canToggleEmail {
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 6) {
                        emailControls
                    }
                } else {
                    emailControls
                }
            }
        }
    }

    private var emailControls: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: { onOpenDashboard?() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(model.emailText)
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)

                Button(action: { onToggleEmail?() }) {
                    Image(systemName: model.isEmailVisible ? "eye.slash" : "eye")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .fixedSize(horizontal: true, vertical: false)
            .modifier(GlassCapsuleModifier(glassNamespace: glassNamespace, id: "email-pill"))

            Button(action: togglePanelMode) {
                Image(systemName: model.panelMode.toggleSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier(glassNamespace: glassNamespace, id: "email-panel-toggle"))
        }
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("套餐剩余额度")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(model.remainingValue)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            HStack(alignment: .top, spacing: 8) {
                compactMetric(
                    title: model.usageLabel,
                    value: model.usageValue,
                    alignment: .leading
                )
                .frame(width: 94, alignment: .leading)

                renewalMetricCard
                .layoutPriority(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 18)
    }

    @ViewBuilder
    private var packageSection: some View {
        if let title = model.packageSectionTitle, !model.packageItems.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 6)

                    Text("\(model.packageItems.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.packageItems.enumerated()), id: \.offset) { _, item in
                        packageRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func packageRow(_ item: SummaryPackageItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(item.badgeText)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(item.badgeTone.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.badgeTone.swiftUIFillColor)
                        .overlay {
                            Capsule().stroke(item.badgeTone.swiftUIBorderColor, lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }

                Text(item.subtitle)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 15)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(model.progressLabel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if let progressPrefix = model.progressPrefix {
                        Text(progressPrefix)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                    }

                    Text(model.progressValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }

            GeometryReader { proxy in
                let value = model.progress ?? 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .accentColor.opacity(0.72),
                                    .accentColor.opacity(0.34)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 15)
    }

    @ViewBuilder
    private var settingsActionPanel: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                settingsControls
            }
            .padding(.top, 2)
        } else {
            settingsControls
                .padding(.top, 2)
        }
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.bottom, 2)

            MenuActionButton(
                title: "API Key",
                subtitle: model.hasAPIKey ? "已配置" : "未配置",
                systemImage: "key.horizontal",
                shortcut: "⌘K",
                prominent: false,
                action: onSetAPIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "轮询间隔",
                subtitle: model.pollIntervalText,
                systemImage: "timer",
                shortcut: "⌘I",
                prominent: false,
                action: onSetInterval,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "MCP 服务",
                subtitle: model.mcpStatusText,
                systemImage: "server.rack",
                shortcut: nil,
                prominent: false,
                action: onConfigureMCP,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "立即刷新",
                subtitle: nil,
                systemImage: "arrow.clockwise",
                shortcut: "⌘R",
                prominent: true,
                action: onRefresh,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "打开伊莉丝控制台",
                subtitle: nil,
                systemImage: "safari",
                shortcut: "⌘D",
                prominent: false,
                action: onOpenDashboard,
                useInfoCardBackground: true
            )

            displayStyleSection

            MenuActionButton(
                title: "退出",
                subtitle: nil,
                systemImage: "power",
                shortcut: "⌘Q",
                prominent: false,
                action: onQuit,
                useInfoCardBackground: true
            )
        }
    }

    private var displayStyleSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("状态栏样式")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Text(model.displayStyle.chipTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(StatusDisplayStyle.allCases, id: \.rawValue) { style in
                    StyleChipButton(
                        style: style,
                        isSelected: style == model.displayStyle
                    ) {
                        applyDisplayStyle(style)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 16)
    }

    private func applyDisplayStyle(_ style: StatusDisplayStyle) {
        guard style != model.displayStyle else { return }
        if reduceMotion {
            onSelectDisplayStyle?(style)
            return
        }
        withAnimation(.spring(duration: 0.32, bounce: 0.20)) {
            onSelectDisplayStyle?(style)
        }
    }

    private func togglePanelMode() {
        if reduceMotion {
            onTogglePanelMode?()
            return
        }
        withAnimation(.spring(duration: 0.28, bounce: 0.15)) {
            onTogglePanelMode?()
        }
    }

    private func compactMetric(
        title: String,
        value: String,
        alignment: HorizontalAlignment,
        valueFontSize: CGFloat = 12,
        valueLineLimit: Int = 1,
        valueMinimumScaleFactor: CGFloat = 0.72
    ) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(valueLineLimit)
                .minimumScaleFactor(valueMinimumScaleFactor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 14)
    }

    private var renewalMetricCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.renewalLabel)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Button(action: { onOpenPricing?() }) {
                    Text("去续费")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Text(model.renewalValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 14)
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    let glassNamespace: Namespace.ID
    let id: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectID(id, in: glassNamespace)
        } else {
            content
                .liquidGlassCapsule()
        }
    }
}

private final class StatusSummaryView: NSView {
    static let preferredWidth: CGFloat = 316

    var onTogglePanelMode: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onToggleEmail: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onRefresh: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetAPIKey: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetInterval: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenDashboard: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenPricing: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)? {
        didSet { updateRootView() }
    }
    var onConfigureMCP: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onQuit: (() -> Void)? {
        didSet { updateRootView() }
    }

    private var model = StatusSummaryViewModel.placeholder
    private let hostingView: NSHostingView<LiquidGlassSummaryPanel>

    override var intrinsicContentSize: NSSize {
        let size = hostingView.fittingSize
        return NSSize(width: Self.preferredWidth, height: max(230, size.height))
    }

    override init(frame frameRect: NSRect) {
        hostingView = NSHostingView(
            rootView: LiquidGlassSummaryPanel(
                model: .placeholder,
                onTogglePanelMode: nil,
                onToggleEmail: nil,
                onRefresh: nil,
                onSetAPIKey: nil,
                onSetInterval: nil,
                onOpenDashboard: nil,
                onOpenPricing: nil,
                onSelectDisplayStyle: nil,
                onConfigureMCP: nil,
                onQuit: nil
            )
        )
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ model: StatusSummaryViewModel) {
        self.model = model
        updateRootView()
    }

    private func updateRootView() {
        hostingView.rootView = LiquidGlassSummaryPanel(
            model: model,
            onTogglePanelMode: onTogglePanelMode,
            onToggleEmail: onToggleEmail,
            onRefresh: onRefresh,
            onSetAPIKey: onSetAPIKey,
            onSetInterval: onSetInterval,
            onOpenDashboard: onOpenDashboard,
            onOpenPricing: onOpenPricing,
            onSelectDisplayStyle: onSelectDisplayStyle,
            onConfigureMCP: onConfigureMCP,
            onQuit: onQuit
        )
        layoutSubtreeIfNeeded()
        invalidateIntrinsicContentSize()
    }
}

private struct MCPServerSnapshot: Encodable {
    let generatedAt: String
    let displayName: String
    let dashboardURL: String
    let pricingURL: String
    let statusText: String
    let latestMessage: String
    let remaining: String
    let usage: String
    let renewal: String
    let progressLabel: String
    let progressPrefix: String?
    let usedPercent: Double?
    let email: String?
    let hasAPIKey: Bool
    let pollIntervalSeconds: Double
    let displayStyle: String
    let packageItems: [MCPPackageItem]
}

private struct MCPPackageItem: Encodable {
    let title: String
    let subtitle: String
    let badgeText: String
}

private final class MCPSnapshotStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.yls.codex-monitor.mcp-snapshot-store")
    private var data = Data("{}".utf8)

    func get() -> Data {
        queue.sync { data }
    }

    func set(_ newData: Data) {
        queue.sync {
            data = newData
        }
    }
}

private final class MCPHTTPServer: @unchecked Sendable {
    private let stateProvider: @Sendable () -> Data
    private let resourceURI = "yls://codex-monitor/snapshot"
    private let toolName = "get_codex_monitor_snapshot"
    private let queue = DispatchQueue(label: "com.yls.codex-monitor.mcp-server")
    private var listener: NWListener?
    private(set) var port: UInt16
    private(set) var isRunning = false
    var lastError: String?

    init(port: UInt16, stateProvider: @escaping @Sendable () -> Data) {
        self.port = port
        self.stateProvider = stateProvider
    }

    func updatePort(_ newPort: UInt16) throws {
        if newPort == port {
            if !isRunning {
                try start()
            }
            return
        }
        stop()
        port = newPort
        try start()
    }

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isRunning = true
                self?.lastError = nil
            case .failed(let error):
                self?.isRunning = false
                self?.lastError = error.localizedDescription
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, accumulated: Data())
    }

    private func receiveRequest(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.lastError = error.localizedDescription
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if let request = self.parseHTTPRequest(from: buffer) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete {
                let response = self.makeJSONResponse([
                    "ok": false,
                    "error": "bad_request"
                ], status: "400 Bad Request")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            self.receiveRequest(on: connection, accumulated: buffer)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        let response: Data

        switch request.path {
        case "/", "/health":
            response = makeJSONResponse([
                "ok": true,
                "service": "yls-codex-monitor-mcp",
                "port": Int(port),
                "endpoints": ["/health", "/snapshot", "/mcp/snapshot", "/mcp"],
                "tool": toolName,
                "resource": resourceURI
            ])
        case "/snapshot", "/mcp/snapshot":
            response = makeRawJSONResponse(stateProvider())
        case "/mcp":
            response = handleMCPRequest(body: request.body)
        default:
            response = makeJSONResponse([
                "ok": false,
                "error": "not_found",
                "path": request.path
            ], status: "404 Not Found")
        }

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private struct HTTPRequest {
        let path: String
        let body: Data?
    }

    private func parseHTTPRequest(from requestData: Data) -> HTTPRequest? {
        guard let requestText = String(data: requestData, encoding: .utf8) else { return nil }
        let separator = "\r\n\r\n"
        let fallbackSeparator = "\n\n"

        let parts: [String]
        let headerBodySeparator: String
        if requestText.contains(separator) {
            parts = requestText.components(separatedBy: separator)
            headerBodySeparator = separator
        } else if requestText.contains(fallbackSeparator) {
            parts = requestText.components(separatedBy: fallbackSeparator)
            headerBodySeparator = fallbackSeparator
        } else {
            return nil
        }

        let header = parts.first ?? ""
        let bodyString = parts.dropFirst().joined(separator: headerBodySeparator)
        let firstLine = header.split(whereSeparator: \ .isNewline).first.map(String.init) ?? ""
        let components = firstLine.split(separator: " ")
        let path = components.count >= 2 ? String(components[1]).components(separatedBy: "?").first ?? "/" : "/"

        let contentLength = contentLengthFromHeader(header)
        let bodyData = Data(bodyString.utf8)
        if bodyData.count < contentLength {
            return nil
        }

        let finalBody = contentLength > 0 ? bodyData.prefix(contentLength) : Data()
        return HTTPRequest(path: path, body: finalBody.isEmpty ? nil : Data(finalBody))
    }

    private func contentLengthFromHeader(_ header: String) -> Int {
        for line in header.split(whereSeparator: \ .isNewline) {
            let raw = String(line)
            if raw.lowercased().hasPrefix("content-length:") {
                let value = raw.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private func handleMCPRequest(body: Data?) -> Data {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32700,
                    "message": "Parse error"
                ],
                "id": NSNull()
            ])
        }

        let method = object["method"] as? String ?? ""
        let id = object["id"] ?? NSNull()
        let params = object["params"] as? [String: Any] ?? [:]
        let snapshotString = String(data: stateProvider(), encoding: .utf8) ?? "{}"

        let result: Any
        switch method {
        case "initialize":
            result = [
                "protocolVersion": "2024-11-05",
                "capabilities": [
                    "tools": [:],
                    "resources": [:]
                ],
                "serverInfo": [
                    "name": "yls-codex-monitor-mcp",
                    "version": "0.2.0"
                ]
            ]
        case "notifications/initialized":
            result = [:]
        case "tools/list":
            result = [
                "tools": [[
                    "name": toolName,
                    "description": "获取伊莉丝 Codex 账户监控应用的最新本地快照数据",
                    "inputSchema": [
                        "type": "object",
                        "properties": [:]
                    ]
                ]]
            ]
        case "tools/call":
            let tool = params["name"] as? String ?? ""
            if tool == toolName {
                result = [
                    "content": [[
                        "type": "text",
                        "text": snapshotString
                    ]]
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32601,
                        "message": "Unknown tool: \(tool)"
                    ],
                    "id": id
                ])
            }
        case "resources/list":
            result = [
                "resources": [[
                    "uri": resourceURI,
                    "name": "Codex Monitor Snapshot",
                    "description": "伊莉丝 Codex 账户监控的最新本地快照",
                    "mimeType": "application/json"
                ]]
            ]
        case "resources/read":
            let uri = params["uri"] as? String ?? ""
            if uri == resourceURI {
                result = [
                    "contents": [[
                        "uri": resourceURI,
                        "mimeType": "application/json",
                        "text": snapshotString
                    ]]
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32602,
                        "message": "Unknown resource: \(uri)"
                    ],
                    "id": id
                ])
            }
        default:
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32601,
                    "message": "Method not found: \(method)"
                ],
                "id": id
            ])
        }

        return makeJSONResponse([
            "jsonrpc": "2.0",
            "result": result,
            "id": id
        ])
    }

    private func makeJSONResponse(_ object: [String: Any], status: String = "200 OK") -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])) ?? Data("{}".utf8)
        return makeRawJSONResponse(body, status: status)
    }

    private func makeRawJSONResponse(_ body: Data, status: String = "200 OK") -> Data {
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Access-Control-Allow-Origin: *",
            "Content-Length: \(body.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, @unchecked Sendable {
    private let endpoint = URL(string: "https://codex.ylsagi.com/codex/info")!
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let mcpSnapshotStore = MCPSnapshotStore()

    private let menu = NSMenu()
    private let summaryMenuItem = NSMenuItem()
    private let summaryView = StatusSummaryView(frame: NSRect(x: 0, y: 0, width: StatusSummaryView.preferredWidth, height: 246))

    private var timer: Timer?
    private var apiKey: String = ""
    private var pollInterval: TimeInterval = 5
    private var displayStyle: StatusDisplayStyle = .remaining
    private var panelMode: MenuPanelMode = .statistics
    private var statusFallbackText = "余额: --"
    private var mcpEnabled = true
    private var mcpPort: UInt16 = AppMeta.defaultMCPPort
    private lazy var mcpServer = MCPHTTPServer(port: mcpPort) { [weak self] in
        guard let self else { return Data("{}".utf8) }
        return self.mcpSnapshotStore.get()
    }
    private var latestUsage = "--"
    private var latestRemaining = "--"
    private var latestRenewal = "--"
    private var latestMessage = "等待数据"
    private var latestUsageLabel = "已用/总"
    private var latestProgressLabel = "用量进度"
    private var latestProgressPrefix: String?
    private var latestEmail: String?
    private var latestPackageItems: [SummaryPackageItem] = []
    private var latestUsedPercent: Double?
    private var isEmailVisible = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        loadConfiguration()
        mcpSnapshotStore.set(makeMCPSnapshotData())
        setupMenu()
        setupStatusButton()
        startPolling()
        startMCPIfNeeded()
        refreshNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        mcpServer.stop()
    }

    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        apiKey = defaults.string(forKey: DefaultsKey.apiKey) ?? ""
        let interval = defaults.double(forKey: DefaultsKey.interval)
        if interval >= 1 {
            pollInterval = interval
        }
        let rawStyle = defaults.integer(forKey: DefaultsKey.displayStyle)
        displayStyle = StatusDisplayStyle(rawValue: rawStyle) ?? .remaining
        if defaults.object(forKey: DefaultsKey.mcpEnabled) != nil {
            mcpEnabled = defaults.bool(forKey: DefaultsKey.mcpEnabled)
        }
        let savedPort = defaults.integer(forKey: DefaultsKey.mcpPort)
        if let validPort = UInt16(exactly: savedPort), validPort > 0 {
            mcpPort = validPort
        }
    }

    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: DefaultsKey.apiKey)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
        defaults.set(displayStyle.rawValue, forKey: DefaultsKey.displayStyle)
        defaults.set(mcpEnabled, forKey: DefaultsKey.mcpEnabled)
        defaults.set(Int(mcpPort), forKey: DefaultsKey.mcpPort)
    }

    private func setupStatusButton() {
        if apiKey.isEmpty {
            statusFallbackText = "余额: 未配置Key"
        } else {
            statusFallbackText = "余额: 加载中..."
        }
        renderSummaryView()
        renderStatusBar()
    }

    private func setupMenu() {
        menu.delegate = self
        summaryView.onTogglePanelMode = { [weak self] in
            self?.togglePanelMode()
        }
        summaryView.onToggleEmail = { [weak self] in
            self?.handleToggleEmailVisibility()
        }
        summaryView.onRefresh = { [weak self] in
            self?.performMenuAction {
                self?.refreshNow()
            }
        }
        summaryView.onSetAPIKey = { [weak self] in
            self?.performMenuAction {
                self?.handleSetAPIKey()
            }
        }
        summaryView.onSetInterval = { [weak self] in
            self?.performMenuAction {
                self?.handleSetInterval()
            }
        }
        summaryView.onOpenDashboard = { [weak self] in
            self?.performMenuAction {
                self?.handleOpenDashboard()
            }
        }
        summaryView.onOpenPricing = { [weak self] in
            self?.performMenuAction {
                self?.handleOpenPricing()
            }
        }
        summaryView.onSelectDisplayStyle = { [weak self] style in
            self?.selectDisplayStyle(style)
        }
        summaryView.onConfigureMCP = { [weak self] in
            self?.performMenuAction {
                self?.handleConfigureMCP()
            }
        }
        summaryView.onQuit = { [weak self] in
            self?.performMenuAction {
                self?.handleQuit()
            }
        }
        summaryMenuItem.view = summaryView
        menu.addItem(summaryMenuItem)
        statusItem.menu = menu
        renderSummaryView()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard isEmailVisible else { return }
        isEmailVisible = false
        renderSummaryView()
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
    }

    @objc private func handleTimerTick() {
        refreshNow()
    }

    private func handleToggleEmailVisibility() {
        guard latestEmail?.isEmpty == false else { return }
        isEmailVisible.toggle()
        renderSummaryView()
    }

    @objc private func handleSetAPIKey() {
        let alert = NSAlert()
        alert.messageText = "设置 API Key"
        alert.informativeText = "请输入 Bearer Token（只填 token 本体）"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = apiKey
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        apiKey = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        saveConfiguration()
        setupStatusButton()
        refreshNow()
    }

    @objc private func handleSetInterval() {
        let alert = NSAlert()
        alert.messageText = "设置轮询间隔（秒）"
        alert.informativeText = "建议 >= 3 秒"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 160, height: 24))
        input.placeholderString = "例如 5"
        input.stringValue = String(Int(pollInterval))
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let value = Double(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard value >= 1 else {
            showError("轮询间隔必须 >= 1 秒")
            return
        }

        pollInterval = value
        saveConfiguration()
        startPolling()
        refreshNow()
    }

    @objc private func handleOpenDashboard() {
        guard let url = URL(string: AppMeta.dashboardURL) else {
            showError("控制台链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func handleConfigureMCP() {
        let alert = NSAlert()
        alert.messageText = "MCP 服务设置"
        alert.informativeText = "启动应用时自动在本机启动一个 HTTP MCP 快照服务，供 AI 连接读取最新数据。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 82))

        let checkbox = NSButton(checkboxWithTitle: "启用 MCP 本地服务", target: nil, action: nil)
        checkbox.frame = NSRect(x: 0, y: 56, width: 220, height: 20)
        checkbox.state = mcpEnabled ? .on : .off
        container.addSubview(checkbox)

        let label = NSTextField(labelWithString: "端口")
        label.frame = NSRect(x: 0, y: 28, width: 40, height: 22)
        container.addSubview(label)

        let input = NSTextField(frame: NSRect(x: 44, y: 24, width: 120, height: 24))
        input.stringValue = String(mcpPort)
        container.addSubview(input)

        let hint = NSTextField(labelWithString: "示例地址: http://\(AppMeta.mcpHost):\(mcpPort)/mcp/snapshot")
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 0, y: 0, width: 340, height: 22)
        container.addSubview(hint)

        alert.accessoryView = container

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let enabled = checkbox.state == .on
        let parsedPort = UInt16(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard parsedPort > 0 else {
            showError("MCP 端口必须是 1-65535 之间的数字")
            return
        }

        mcpEnabled = enabled
        mcpPort = parsedPort
        saveConfiguration()
        restartMCPIfNeeded()
        renderSummaryView()
    }

    @objc private func handleOpenPricing() {
        guard let url = URL(string: AppMeta.pricingURL) else {
            showError("续费链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func selectDisplayStyle(_ style: StatusDisplayStyle) {
        displayStyle = style
        saveConfiguration()
        renderSummaryView()
        renderStatusBar()
    }

    private func togglePanelMode() {
        panelMode = panelMode == .statistics ? .settings : .statistics
        renderSummaryView()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    private func startMCPIfNeeded() {
        guard mcpEnabled else {
            mcpServer.stop()
            return
        }
        do {
            try mcpServer.updatePort(mcpPort)
        } catch {
            mcpServer.stop()
            mcpServer.lastError = error.localizedDescription
        }
    }

    private func restartMCPIfNeeded() {
        mcpServer.stop()
        startMCPIfNeeded()
    }

    private func currentMCPStatusText() -> String {
        if !mcpEnabled {
            return "已关闭"
        }
        if mcpServer.isRunning {
            return "http://\(AppMeta.mcpHost):\(mcpPort)/mcp/snapshot"
        }
        if let error = mcpServer.lastError, !error.isEmpty {
            return "启动失败: \(error)"
        }
        return "启动中..."
    }

    private func makeMCPSnapshotData() -> Data {
        let snapshot = MCPServerSnapshot(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            displayName: AppMeta.displayName,
            dashboardURL: AppMeta.dashboardURL,
            pricingURL: AppMeta.pricingURL,
            statusText: currentSummaryStatus().0,
            latestMessage: latestMessage,
            remaining: latestRemaining,
            usage: latestUsage,
            renewal: latestRenewal,
            progressLabel: latestProgressLabel,
            progressPrefix: latestProgressPrefix,
            usedPercent: latestUsedPercent,
            email: latestEmail,
            hasAPIKey: !apiKey.isEmpty,
            pollIntervalSeconds: pollInterval,
            displayStyle: displayStyle.title,
            packageItems: latestPackageItems.map {
                MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
            }
        )
        return (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8)
    }

    private func refreshNow() {
        guard !apiKey.isEmpty else {
            updateStatusBar(text: "余额: 未配置Key")
            updateMenu(usage: "--", remaining: "--", message: "请先设置 API Key", usedPercent: nil, email: nil)
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: 请求失败")
                    self.updateMenu(usage: "--", remaining: "--", message: "网络错误: \(error.localizedDescription)", usedPercent: nil, email: nil)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: 响应异常")
                    self.updateMenu(usage: "--", remaining: "--", message: "无效响应", usedPercent: nil, email: nil)
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: HTTP \(httpResponse.statusCode)")
                    self.updateMenu(usage: "--", remaining: "--", message: "接口返回 HTTP \(httpResponse.statusCode)", usedPercent: nil, email: nil)
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(APIEnvelope.self, from: data)
                if let code = decoded.code, code != 200 {
                    let apiMessage = decoded.msg ?? decoded.error ?? decoded.details ?? "接口返回业务错误"
                    DispatchQueue.main.async {
                        self.updateStatusBar(text: "余额: 业务错误")
                        self.updateMenu(
                            usage: "--",
                            remaining: "--",
                            message: "错误码 \(code): \(apiMessage)",
                            usedPercent: nil,
                            email: nil
                        )
                    }
                    return
                }

                if let errorText = decoded.error {
                    let details = decoded.details ?? decoded.msg ?? errorText
                    DispatchQueue.main.async {
                        self.updateStatusBar(text: "余额: 授权错误")
                        self.updateMenu(usage: "--", remaining: "--", message: details, usedPercent: nil, email: nil)
                    }
                    return
                }

                guard let state = decoded.state else {
                    let text = decoded.msg ?? decoded.details ?? "响应里缺少 state 字段"
                    DispatchQueue.main.async {
                        self.updateStatusBar(text: "余额: 响应异常")
                        self.updateMenu(usage: "--", remaining: "--", message: text, usedPercent: nil, email: nil)
                    }
                    return
                }

                let packageUsagePayload = state.userPackgeUsage
                let weeklyUsagePayload = state.userPackgeUsageWeek
                let displayUsagePayload = weeklyUsagePayload ?? packageUsagePayload

                guard let remainingNumber = packageUsagePayload?.remainingQuota ?? state.remainingQuota ?? displayUsagePayload?.remainingQuota else {
                    throw NSError(
                        domain: "BalanceParse",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "缺少 remaining_quota 字段"]
                    )
                }

                let remaining = remainingNumber.display
                let usageRemainingNumber = displayUsagePayload?.remainingQuota ?? remainingNumber
                let packageRemainingNumber = packageUsagePayload?.remainingQuota ?? remainingNumber
                let usedPercent = Self.resolveUsedPercentage(usage: displayUsagePayload, remaining: usageRemainingNumber)
                let usageQuotaPair = Self.resolveUsageQuotaPair(usage: displayUsagePayload, remaining: usageRemainingNumber)
                let dailyUsagePair = Self.resolveUsageQuotaPair(usage: packageUsagePayload, remaining: packageRemainingNumber)
                let renewal = Self.resolveRenewalText(package: state.package)
                let packageItems = Self.buildPackageSummaryItems(package: state.package)
                let usageLabel = "已用/总"
                let progressLabel = weeklyUsagePayload == nil ? "用量进度" : "本周用量进度"
                let progressPrefix = usageQuotaPair.map { "\($0.used)/\($0.total)" }
                let usage: String
                if let dailyUsagePair {
                    usage = "\(dailyUsagePair.used)/\(dailyUsagePair.total)"
                } else if let usageQuotaPair {
                    usage = "\(usageQuotaPair.used)/\(usageQuotaPair.total)"
                } else if let usedPercent {
                    usage = String(format: "%.2f%%", usedPercent)
                } else if let totalCost = displayUsagePayload?.totalCost?.display {
                    usage = "总消费: \(totalCost)"
                } else {
                    usage = "--"
                }
                let now = Date()

                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余: \(remaining)")
                    self.updateMenu(
                        usage: usage,
                        remaining: remaining,
                        message: "更新时间: \(Self.timeFormatter.string(from: now))",
                        usedPercent: usedPercent,
                        email: state.user?.email,
                        renewal: renewal ?? "--",
                        packageItems: packageItems,
                        usageLabel: usageLabel,
                        progressLabel: progressLabel,
                        progressPrefix: progressPrefix
                    )
                }
            } catch {
                let rawSnippet = String(data: data, encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(120) ?? "无法读取响应内容"
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: 解析失败")
                    self.updateMenu(
                        usage: "--",
                        remaining: "--",
                        message: "解析错误: \(error.localizedDescription) | \(rawSnippet)",
                        usedPercent: nil,
                        email: nil
                    )
                }
            }
        }.resume()
    }

    private func updateStatusBar(text: String) {
        statusFallbackText = text
        renderSummaryView()
        renderStatusBar()
    }

    private func updateMenu(
        usage: String,
        remaining: String,
        message: String,
        usedPercent: Double?,
        email: String?,
        renewal: String = "--",
        packageItems: [SummaryPackageItem] = [],
        usageLabel: String = "已用/总",
        progressLabel: String = "用量进度",
        progressPrefix: String? = nil
    ) {
        latestUsage = usage
        latestRemaining = remaining
        latestRenewal = renewal
        latestMessage = message
        latestUsageLabel = usageLabel
        latestProgressLabel = progressLabel
        latestProgressPrefix = progressPrefix
        latestEmail = email
        latestPackageItems = packageItems
        latestUsedPercent = usedPercent

        renderSummaryView()
        renderStatusBar()
    }

    private func renderSummaryView() {
        let progressValue: String
        if let latestUsedPercent {
            progressValue = String(format: "%.2f%%", max(0, min(100, latestUsedPercent)))
        } else {
            progressValue = "--"
        }

        let displayEmail: String
        if let latestEmail, !latestEmail.isEmpty {
            displayEmail = isEmailVisible ? latestEmail : "***"
        } else {
            displayEmail = "--"
        }

        let (statusText, statusTone) = currentSummaryStatus()
        let renewalLabel = latestPackageItems.count > 1 ? "最近到期" : "下次续费 / 到期"
        let packageSectionTitle: String? = if latestPackageItems.isEmpty {
            nil
        } else if latestPackageItems.count == 1 {
            "当前套餐"
        } else {
            "有效套餐（\(latestPackageItems.count)）"
        }
        summaryView.apply(
            StatusSummaryViewModel(
                title: AppMeta.displayName,
                statusText: statusText,
                statusTone: statusTone,
                emailText: displayEmail,
                canToggleEmail: latestEmail?.isEmpty == false,
                isEmailVisible: isEmailVisible,
                usageLabel: latestUsageLabel,
                usageValue: latestUsage,
                remainingValue: latestRemaining,
                renewalLabel: renewalLabel,
                renewalValue: latestRenewal,
                packageSectionTitle: packageSectionTitle,
                packageItems: latestPackageItems,
                progressLabel: latestProgressLabel,
                progressPrefix: latestProgressPrefix,
                progressValue: progressValue,
                progress: latestUsedPercent.map { max(0, min(100, $0)) / 100 },
                footerText: latestMessage,
                hasAPIKey: !apiKey.isEmpty,
                pollIntervalText: "\(Int(pollInterval)) 秒",
                displayStyle: displayStyle,
                panelMode: panelMode,
                mcpStatusText: currentMCPStatusText()
            )
        )
        summaryView.frame = NSRect(origin: .zero, size: summaryView.intrinsicContentSize)
        mcpSnapshotStore.set(makeMCPSnapshotData())
    }

    private func currentSummaryStatus() -> (String, SummaryStatusTone) {
        if latestRemaining != "--" {
            return ("在线", .success)
        }
        if statusFallbackText.contains("未配置") || latestMessage.contains("请先设置 API Key") {
            return ("未配置", .warning)
        }
        if statusFallbackText.contains("加载中") {
            return ("加载中", .neutral)
        }
        if statusFallbackText.contains("请求失败")
            || statusFallbackText.contains("授权错误")
            || statusFallbackText.contains("HTTP")
            || statusFallbackText.contains("解析失败")
            || statusFallbackText.contains("业务错误")
            || statusFallbackText.contains("响应异常") {
            return ("异常", .critical)
        }
        return ("等待中", .neutral)
    }

    private func performMenuAction(_ action: @escaping () -> Void) {
        menu.cancelTracking()
        DispatchQueue.main.async {
            action()
        }
    }

    private func renderStatusBar() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage

        // 当接口数据不可用时，优先展示错误/未配置等状态文案。
        guard latestRemaining != "--" else {
            applySingleLineTitle(statusFallbackText)
            return
        }

        let clampedUsed = latestUsedPercent.map { max(0, min(100, $0)) }
        let remainingPercent = clampedUsed.map { max(0, 100 - $0) }

        switch displayStyle {
        case .remaining:
            applySingleLineTitle("余: \(latestRemaining)")
        case .usedPercent:
            if let clampedUsed {
                applySingleLineTitle(String(format: "用: %.2f%%", clampedUsed))
            } else {
                applySingleLineTitle("用: \(latestUsage)")
            }
        case .remainingPercent:
            if let remainingPercent {
                applySingleLineTitle(String(format: "剩: %.2f%%", remainingPercent))
            } else {
                applySingleLineTitle("剩: --")
            }
        case .stackedUsedPercent:
            let top = clampedUsed.map { String(format: "%.2f%%", $0) } ?? "--"
            applyTwoLineImage(top: top, bottom: "已使用")
        case .stackedRemainingPercent:
            let top = remainingPercent.map { String(format: "%.2f%%", $0) } ?? "--"
            applyTwoLineImage(top: top, bottom: "剩余")
        case .circleProgress:
            applyCircleProgressWithRemaining(progress: clampedUsed.map { $0 / 100 }, remainingText: "余: \(latestRemaining)")
        }
    }

    private func applySingleLineTitle(_ text: String, size: CGFloat = 12) {
        guard let button = statusItem.button else { return }
        statusItem.length = NSStatusItem.variableLength
        button.alignment = .center
        button.cell?.wraps = false
        button.cell?.lineBreakMode = .byClipping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    private func applyTwoLineImage(top: String, bottom: String) {
        guard let button = statusItem.button else { return }
        let targetWidth = makeStackedTargetWidth(top: top, bottom: bottom)
        statusItem.length = targetWidth
        button.attributedTitle = NSAttributedString(string: "")
        let targetHeight = max(AppMeta.stackedStatusHeight, floor(button.bounds.height))
        button.image = makeStackedTextImage(top: top, bottom: bottom, targetWidth: targetWidth, targetHeight: targetHeight)
        button.imagePosition = .imageOnly
    }

    private func makeStackedTargetWidth(top: String, bottom: String) -> CGFloat {
        let topFont = NSFont.systemFont(ofSize: AppMeta.stackedTopFontSize, weight: .semibold)
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.stackedBottomFontSize, weight: .medium)
        let topWidth = ceil((top as NSString).size(withAttributes: [.font: topFont]).width)
        let bottomWidth = ceil((bottom as NSString).size(withAttributes: [.font: bottomFont]).width)
        let contentWidth = max(topWidth, bottomWidth)
        let target = contentWidth + AppMeta.stackedHorizontalPadding * 2
        return max(AppMeta.stackedStatusMinWidth, min(AppMeta.stackedStatusMaxWidth, target))
    }

    private func makeStackedTextImage(top: String, bottom: String, targetWidth: CGFloat, targetHeight: CGFloat) -> NSImage {
        let size = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        let topFont = NSFont.systemFont(ofSize: AppMeta.stackedTopFontSize, weight: .semibold)
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.stackedBottomFontSize, weight: .medium)

        let topAttrs: [NSAttributedString.Key: Any] = [
            .font: topFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: bottomFont,
            .foregroundColor: NSColor.labelColor.withAlphaComponent(0.68),
            .paragraphStyle: paragraph
        ]

        let topText = NSAttributedString(string: top, attributes: topAttrs)
        let bottomText = NSAttributedString(string: bottom, attributes: bottomAttrs)
        let topHeight = ceil(topFont.ascender - topFont.descender)
        let bottomHeight = ceil(bottomFont.ascender - bottomFont.descender)
        let contentHeight = topHeight + AppMeta.stackedLineGap + bottomHeight
        let baseY = floor((size.height - contentHeight) / 2 + AppMeta.stackedVerticalNudge)

        let bottomY = baseY
        let topY = bottomY + bottomHeight + AppMeta.stackedLineGap

        topText.draw(in: NSRect(x: 0, y: topY, width: size.width, height: topHeight))
        bottomText.draw(in: NSRect(x: 0, y: bottomY, width: size.width, height: bottomHeight))

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func applyCircleProgressWithRemaining(progress: Double?, remainingText: String) {
        guard let button = statusItem.button else { return }
        let targetWidth = makeCircleTargetWidth(bottomText: remainingText)
        statusItem.length = targetWidth
        button.attributedTitle = NSAttributedString(string: "")
        let targetHeight = max(AppMeta.stackedStatusHeight, floor(button.bounds.height))
        button.image = makeCircleWithBottomTextImage(
            progress: progress ?? 0,
            bottomText: remainingText,
            targetWidth: targetWidth,
            targetHeight: targetHeight
        )
        button.imagePosition = .imageOnly
    }

    private func makeCircleTargetWidth(bottomText: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: AppMeta.circleBottomFontSize, weight: .medium)
        let textWidth = ceil((bottomText as NSString).size(withAttributes: [.font: font]).width)
        let contentWidth = max(AppMeta.circleDiameter, textWidth)
        let target = contentWidth + AppMeta.circleHorizontalPadding * 2
        return max(AppMeta.circleMinWidth, min(AppMeta.circleMaxWidth, target))
    }

    private func makeCircleWithBottomTextImage(progress: Double, bottomText: String, targetWidth: CGFloat, targetHeight: CGFloat) -> NSImage {
        let size = NSSize(width: targetWidth, height: targetHeight)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true

        let clamped = max(0, min(1, progress))
        let bottomFont = NSFont.systemFont(ofSize: AppMeta.circleBottomFontSize, weight: .medium)
        let textHeight = ceil(bottomFont.ascender - bottomFont.descender)
        let circleSize = AppMeta.circleDiameter
        let contentHeight = circleSize + AppMeta.circleLineGap + textHeight
        let baseY = floor((size.height - contentHeight) / 2 + AppMeta.stackedVerticalNudge)
        let textY = baseY
        let circleY = textY + textHeight + AppMeta.circleLineGap
        let center = NSPoint(x: floor(size.width / 2), y: circleY + circleSize / 2)
        let radius = AppMeta.circleDiameter / 2
        let startAngle: CGFloat = 90
        let endAngle = startAngle - CGFloat(clamped * 360)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        NSAttributedString(
            string: bottomText,
            attributes: [
                .font: bottomFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.68),
                .paragraphStyle: paragraph
            ]
        ).draw(in: NSRect(x: 0, y: textY, width: size.width, height: textHeight))

        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        bgPath.lineWidth = AppMeta.circleLineWidth
        NSColor.tertiaryLabelColor.setStroke()
        bgPath.stroke()

        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        fgPath.lineWidth = AppMeta.circleLineWidth
        NSColor.systemGreen.setStroke()
        fgPath.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    nonisolated private static func resolveUsedPercentage(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
        if let fromAPI = usage?.usedPercentage?.doubleValue {
            return fromAPI
        }
        guard
            let totalQuota = usage?.totalQuota?.doubleValue,
            totalQuota > 0,
            let remainingQuota = remaining.doubleValue
        else {
            return nil
        }
        return (1 - (remainingQuota / totalQuota)) * 100
    }

    nonisolated private static func resolveUsageQuotaPair(
        usage: UsagePayload?,
        remaining: FlexibleNumber
    ) -> (used: String, total: String)? {
        guard let usedQuota = resolveUsedQuota(usage: usage, remaining: remaining),
              let totalQuota = usage?.totalQuota?.doubleValue else {
            return nil
        }
        return (
            used: formatQuotaValue(usedQuota),
            total: formatQuotaValue(totalQuota)
        )
    }

    nonisolated private static func resolveUsedQuota(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
        guard
            let totalQuota = usage?.totalQuota?.doubleValue,
            totalQuota > 0,
            let remainingQuota = remaining.doubleValue
        else {
            return nil
        }
        return max(0, totalQuota - remainingQuota)
    }

    nonisolated private static func formatQuotaValue(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.005 {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", value)
    }

    nonisolated private static func resolveRenewalText(package: PackagePayload?) -> String? {
        guard let package = selectDisplayPackage(from: package?.packages),
              let expiresAt = package.expiresAt,
              let expiresDate = parseAPIDate(expiresAt)
        else {
            return nil
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let renewalYear = calendar.component(.year, from: expiresDate)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = Locale(identifier: "zh_CN")
        absoluteFormatter.timeZone = .current
        absoluteFormatter.dateFormat = renewalYear == currentYear ? "MM-dd HH:mm" : "yyyy-MM-dd HH:mm"

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = Locale(identifier: "zh_CN")
        relativeFormatter.unitsStyle = .short

        let absolute = absoluteFormatter.string(from: expiresDate)
        let relative = relativeFormatter.localizedString(for: expiresDate, relativeTo: Date())
        return "\(absolute)（\(relative)）"
    }

    nonisolated private static func buildPackageSummaryItems(package: PackagePayload?) -> [SummaryPackageItem] {
        activePackages(from: package?.packages).map { item, expiresDate in
            let startText = parseAPIDate(item.startAt ?? "").map { compactDateFormatter.string(from: $0) } ?? "--"
            let expireText = compactDateFormatter.string(from: expiresDate)
            let daysRemaining = max(
                0,
                Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: Date()),
                    to: Calendar.current.startOfDay(for: expiresDate)
                ).day ?? 0
            )

            let badgeTone: SummaryStatusTone
            if daysRemaining <= 1 {
                badgeTone = .critical
            } else if daysRemaining <= 7 {
                badgeTone = .warning
            } else {
                badgeTone = .success
            }

            return SummaryPackageItem(
                title: normalizePackageTitle(item.packageType),
                subtitle: "生效 \(startText)  到期 \(expireText)",
                badgeText: daysRemaining == 0 ? "今天到期" : "剩\(daysRemaining)天",
                badgeTone: badgeTone
            )
        }
    }

    nonisolated private static func selectDisplayPackage(from packages: [PackageItem]?) -> PackageItem? {
        let now = Date()
        let candidates = activePackages(from: packages)

        if let upcoming = candidates
            .filter({ $0.1 >= now })
            .min(by: { $0.1 < $1.1 }) {
            return upcoming.0
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    nonisolated private static func activePackages(from packages: [PackageItem]?) -> [(PackageItem, Date)] {
        guard let packages, !packages.isEmpty else { return [] }

        let datedPackages = packages.compactMap { item -> (PackageItem, Date)? in
            guard let expiresAt = item.expiresAt, let expiresDate = parseAPIDate(expiresAt) else {
                return nil
            }
            return (item, expiresDate)
        }

        let activePackages = datedPackages.filter { ($0.0.packageStatus ?? "").lowercased() == "active" }
        let candidates = activePackages.isEmpty ? datedPackages : activePackages
        return candidates.sorted(by: { $0.1 < $1.1 })
    }

    nonisolated private static func parseAPIDate(_ rawValue: String) -> Date? {
        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }

    nonisolated private static func normalizePackageTitle(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "未知套餐" }
        return rawValue
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func maskEmail(_ email: String?) -> String? {
        guard let email, !email.isEmpty else { return nil }
        let parts = email.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return maskPlainText(email) }

        let local = parts[0]
        let domain = parts[1]

        let maskedLocal: String
        if local.count <= 2 {
            maskedLocal = String(local.prefix(1)) + "***"
        } else {
            maskedLocal = String(local.prefix(2)) + "***" + String(local.suffix(1))
        }

        let domainParts = domain.split(separator: ".").map(String.init)
        if domainParts.count >= 2 {
            let host = domainParts.dropLast().joined(separator: ".")
            let tld = domainParts.last ?? "com"
            let maskedHost = host.count <= 1 ? "*" : String(host.prefix(1)) + "***"
            return "\(maskedLocal)@\(maskedHost).\(tld)"
        }

        let maskedDomain = domain.count <= 1 ? "*" : String(domain.prefix(1)) + "***"
        return "\(maskedLocal)@\(maskedDomain)"
    }

    nonisolated private static func maskPlainText(_ text: String) -> String {
        guard text.count > 2 else { return "***" }
        return String(text.prefix(2)) + "***" + String(text.suffix(1))
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "配置错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    nonisolated private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}

@main
struct YLSStatusBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
