import AppKit
import Foundation
import QuartzCore

private enum DefaultsKey {
    static let apiKey = "api_key"
    static let interval = "poll_interval_seconds"
    static let displayStyle = "status_display_style"
}

private enum AppMeta {
    static let displayName = "伊莉丝Codex账户监控助手"
    static let dashboardURL = "https://code.ylsagi.com/user/dashboard"
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
    let progressValue: String
    let progress: Double?
    let footerText: String
}

private struct SummaryPackageItem {
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeTone: SummaryStatusTone
}

private func makeSymbolImage(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
}

private final class SummaryMetricCardView: NSView {
    private let captionLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.86).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.28).cgColor

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.maximumNumberOfLines = 2
        valueLabel.lineBreakMode = .byTruncatingTail

        addSubview(captionLabel)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            valueLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 6),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(caption: String, value: String, valueFontSize: CGFloat = 16, valueWeight: NSFont.Weight = .semibold) {
        captionLabel.stringValue = caption
        valueLabel.stringValue = value
        valueLabel.font = NSFont.systemFont(ofSize: valueFontSize, weight: valueWeight)
    }
}

private final class SummaryInlineMetricView: NSView {
    private let captionLabel = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = .labelColor
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1

        addSubview(captionLabel)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            valueLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(caption: String, value: String, valueFont: NSFont? = nil) {
        captionLabel.stringValue = caption
        valueLabel.stringValue = value
        if let valueFont {
            valueLabel.font = valueFont
        }
    }
}

private final class SummaryPackageRowView: NSView {
    private let accentView = NSView()
    private let containerView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let badgeContainer = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        accentView.translatesAutoresizingMaskIntoConstraints = false
        accentView.wantsLayer = true
        accentView.layer?.cornerRadius = 2
        accentView.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.72).cgColor

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.74).cgColor
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.14).cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 999
        badgeContainer.layer?.borderWidth = 1

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .semibold)
        badgeContainer.addSubview(badgeLabel)

        let titleSpacer = NSView()
        titleSpacer.translatesAutoresizingMaskIntoConstraints = false
        titleSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleRow = NSStackView(views: [titleLabel, titleSpacer, badgeContainer])
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 8

        containerView.addSubview(titleRow)
        containerView.addSubview(subtitleLabel)
        addSubview(containerView)
        addSubview(accentView)

        NSLayoutConstraint.activate([
            accentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            accentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            accentView.widthAnchor.constraint(equalToConstant: 4),

            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: accentView.trailingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleRow.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            titleRow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleRow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4),

            subtitleLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            subtitleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ item: SummaryPackageItem) {
        titleLabel.stringValue = item.title
        subtitleLabel.stringValue = item.subtitle
        badgeLabel.stringValue = item.badgeText
        badgeLabel.textColor = item.badgeTone.textColor
        badgeContainer.layer?.backgroundColor = item.badgeTone.fillColor.cgColor
        badgeContainer.layer?.borderColor = item.badgeTone.borderColor.cgColor
        accentView.layer?.backgroundColor = item.badgeTone.textColor.withAlphaComponent(0.72).cgColor
    }
}

private final class SummaryProgressBarView: NSView {
    var progress: Double? {
        didSet { needsLayout = true }
    }

    private let trackLayer = CALayer()
    private let fillLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = false

        trackLayer.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.34).cgColor
        fillLayer.colors = [
            NSColor.systemTeal.withAlphaComponent(0.95).cgColor,
            NSColor.systemGreen.withAlphaComponent(0.95).cgColor
        ]
        fillLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.endPoint = CGPoint(x: 1, y: 0.5)

        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let bounds = self.bounds.insetBy(dx: 0.5, dy: 0.5)
        trackLayer.frame = bounds
        trackLayer.cornerRadius = bounds.height / 2

        guard let progress, progress > 0 else {
            fillLayer.isHidden = true
            return
        }

        let clamped = max(0, min(1, progress))
        let fillWidth = max(bounds.height, bounds.width * clamped)
        let fillRect = CGRect(x: bounds.minX, y: bounds.minY, width: min(bounds.width, fillWidth), height: bounds.height)
        fillLayer.isHidden = false
        fillLayer.frame = fillRect
        fillLayer.cornerRadius = bounds.height / 2
    }
}

private final class StatusSummaryView: NSView {
    static let preferredWidth: CGFloat = 388

    var onToggleEmail: (() -> Void)?
    private var preferredHeight: CGFloat = 276

    private let cardView = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let statusBadgeContainer = NSView()
    private let statusBadgeLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let emailPillContainer = NSView()
    private let emailCaptionLabel = NSTextField(labelWithString: "邮箱")
    private let emailValueLabel = NSTextField(labelWithString: "")
    private let emailToggleButton = NSButton()
    private let heroContainer = NSView()
    private let balanceCaptionLabel = NSTextField(labelWithString: "套餐剩余额度")
    private let balanceValueLabel = NSTextField(labelWithString: "")
    private let heroDivider = NSBox()
    private let usageMetricView = SummaryInlineMetricView(frame: .zero)
    private let renewalMetricView = SummaryInlineMetricView(frame: .zero)
    private let packageSectionTitleLabel = NSTextField(labelWithString: "")
    private let packageStack = NSStackView()
    private let progressLabel = NSTextField(labelWithString: "")
    private let progressValueLabel = NSTextField(labelWithString: "")
    private let progressBarView = SummaryProgressBarView(frame: .zero)

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.preferredWidth, height: preferredHeight)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 18
        cardView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.12).cgColor
        addSubview(cardView)

        let contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 12
        cardView.addSubview(contentStack)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        statusBadgeContainer.translatesAutoresizingMaskIntoConstraints = false
        statusBadgeContainer.wantsLayer = true
        statusBadgeContainer.layer?.cornerRadius = 999
        statusBadgeContainer.layer?.borderWidth = 1

        statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        statusBadgeContainer.addSubview(statusBadgeLabel)

        let titleSpacer = NSView()
        titleSpacer.translatesAutoresizingMaskIntoConstraints = false
        titleSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleRow = NSStackView(views: [titleLabel, titleSpacer, statusBadgeContainer])
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10
        contentStack.addArrangedSubview(titleRow)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.lineBreakMode = .byTruncatingTail

        emailPillContainer.translatesAutoresizingMaskIntoConstraints = false
        emailPillContainer.wantsLayer = true
        emailPillContainer.layer?.cornerRadius = 999
        emailPillContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor
        emailPillContainer.layer?.borderWidth = 1
        emailPillContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.12).cgColor

        emailCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        emailCaptionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        emailCaptionLabel.textColor = .secondaryLabelColor

        emailValueLabel.translatesAutoresizingMaskIntoConstraints = false
        emailValueLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        emailValueLabel.textColor = .labelColor
        emailValueLabel.lineBreakMode = .byTruncatingMiddle
        emailValueLabel.maximumNumberOfLines = 1

        emailToggleButton.translatesAutoresizingMaskIntoConstraints = false
        emailToggleButton.isBordered = false
        emailToggleButton.bezelStyle = .regularSquare
        emailToggleButton.imagePosition = .imageOnly
        emailToggleButton.contentTintColor = .secondaryLabelColor
        emailToggleButton.target = self
        emailToggleButton.action = #selector(handleToggleEmail)

        emailPillContainer.addSubview(emailCaptionLabel)
        emailPillContainer.addSubview(emailValueLabel)
        emailPillContainer.addSubview(emailToggleButton)

        let metaSpacer = NSView()
        metaSpacer.translatesAutoresizingMaskIntoConstraints = false
        metaSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let metaRow = NSStackView(views: [metaLabel, metaSpacer, emailPillContainer])
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.orientation = .horizontal
        metaRow.alignment = .centerY
        metaRow.spacing = 10
        contentStack.addArrangedSubview(metaRow)

        heroContainer.translatesAutoresizingMaskIntoConstraints = false
        heroContainer.wantsLayer = true
        heroContainer.layer?.cornerRadius = 16
        heroContainer.layer?.backgroundColor = NSColor.systemTeal.withAlphaComponent(0.055).cgColor
        heroContainer.layer?.borderWidth = 1
        heroContainer.layer?.borderColor = NSColor.systemTeal.withAlphaComponent(0.12).cgColor

        balanceCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceCaptionLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        balanceCaptionLabel.textColor = .secondaryLabelColor

        balanceValueLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .bold)
        balanceValueLabel.textColor = .labelColor

        heroDivider.translatesAutoresizingMaskIntoConstraints = false
        heroDivider.boxType = .separator

        let insightStack = NSStackView(views: [usageMetricView, renewalMetricView])
        insightStack.translatesAutoresizingMaskIntoConstraints = false
        insightStack.orientation = .vertical
        insightStack.spacing = 10
        insightStack.alignment = .leading

        heroContainer.addSubview(balanceCaptionLabel)
        heroContainer.addSubview(balanceValueLabel)
        heroContainer.addSubview(heroDivider)
        heroContainer.addSubview(insightStack)
        contentStack.addArrangedSubview(heroContainer)

        packageSectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        packageSectionTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        packageSectionTitleLabel.textColor = .secondaryLabelColor
        contentStack.addArrangedSubview(packageSectionTitleLabel)

        packageStack.translatesAutoresizingMaskIntoConstraints = false
        packageStack.orientation = .vertical
        packageStack.spacing = 10
        contentStack.addArrangedSubview(packageStack)

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = .secondaryLabelColor

        progressValueLabel.translatesAutoresizingMaskIntoConstraints = false
        progressValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        progressValueLabel.textColor = .labelColor

        let progressSpacer = NSView()
        progressSpacer.translatesAutoresizingMaskIntoConstraints = false
        progressSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let progressHeaderRow = NSStackView(views: [progressLabel, progressSpacer, progressValueLabel])
        progressHeaderRow.translatesAutoresizingMaskIntoConstraints = false
        progressHeaderRow.orientation = .horizontal
        progressHeaderRow.alignment = .centerY

        contentStack.addArrangedSubview(progressHeaderRow)
        contentStack.addArrangedSubview(progressBarView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            titleRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            metaRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            heroContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            packageSectionTitleLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            packageStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            progressHeaderRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            progressBarView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            statusBadgeLabel.topAnchor.constraint(equalTo: statusBadgeContainer.topAnchor, constant: 4),
            statusBadgeLabel.leadingAnchor.constraint(equalTo: statusBadgeContainer.leadingAnchor, constant: 8),
            statusBadgeLabel.trailingAnchor.constraint(equalTo: statusBadgeContainer.trailingAnchor, constant: -8),
            statusBadgeLabel.bottomAnchor.constraint(equalTo: statusBadgeContainer.bottomAnchor, constant: -4),

            emailCaptionLabel.leadingAnchor.constraint(equalTo: emailPillContainer.leadingAnchor, constant: 10),
            emailCaptionLabel.centerYAnchor.constraint(equalTo: emailPillContainer.centerYAnchor),
            emailValueLabel.leadingAnchor.constraint(equalTo: emailCaptionLabel.trailingAnchor, constant: 6),
            emailValueLabel.centerYAnchor.constraint(equalTo: emailPillContainer.centerYAnchor),
            emailToggleButton.leadingAnchor.constraint(equalTo: emailValueLabel.trailingAnchor, constant: 6),
            emailToggleButton.trailingAnchor.constraint(equalTo: emailPillContainer.trailingAnchor, constant: -8),
            emailToggleButton.centerYAnchor.constraint(equalTo: emailPillContainer.centerYAnchor),
            emailToggleButton.widthAnchor.constraint(equalToConstant: 16),
            emailToggleButton.heightAnchor.constraint(equalToConstant: 16),
            emailPillContainer.heightAnchor.constraint(equalToConstant: 28),

            balanceCaptionLabel.topAnchor.constraint(equalTo: heroContainer.topAnchor, constant: 16),
            balanceCaptionLabel.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor, constant: 16),
            balanceCaptionLabel.trailingAnchor.constraint(equalTo: heroDivider.leadingAnchor, constant: -16),

            balanceValueLabel.topAnchor.constraint(equalTo: balanceCaptionLabel.bottomAnchor, constant: 6),
            balanceValueLabel.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor, constant: 16),
            balanceValueLabel.trailingAnchor.constraint(equalTo: heroDivider.leadingAnchor, constant: -16),
            balanceValueLabel.bottomAnchor.constraint(lessThanOrEqualTo: heroContainer.bottomAnchor, constant: -16),

            heroDivider.topAnchor.constraint(equalTo: heroContainer.topAnchor, constant: 16),
            heroDivider.bottomAnchor.constraint(equalTo: heroContainer.bottomAnchor, constant: -16),
            heroDivider.widthAnchor.constraint(equalToConstant: 1),
            heroDivider.centerXAnchor.constraint(equalTo: heroContainer.centerXAnchor, constant: -20),

            insightStack.topAnchor.constraint(equalTo: heroContainer.topAnchor, constant: 16),
            insightStack.leadingAnchor.constraint(equalTo: heroDivider.trailingAnchor, constant: 16),
            insightStack.trailingAnchor.constraint(equalTo: heroContainer.trailingAnchor, constant: -16),
            insightStack.bottomAnchor.constraint(lessThanOrEqualTo: heroContainer.bottomAnchor, constant: -16),
            insightStack.centerYAnchor.constraint(equalTo: heroContainer.centerYAnchor),

            heroContainer.heightAnchor.constraint(equalToConstant: 114),
            progressBarView.heightAnchor.constraint(equalToConstant: 8),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ model: StatusSummaryViewModel) {
        titleLabel.stringValue = model.title
        statusBadgeLabel.stringValue = model.statusText
        statusBadgeLabel.textColor = model.statusTone.textColor
        statusBadgeContainer.layer?.backgroundColor = model.statusTone.fillColor.cgColor
        statusBadgeContainer.layer?.borderColor = model.statusTone.borderColor.cgColor

        metaLabel.stringValue = model.footerText

        emailValueLabel.stringValue = model.emailText
        emailPillContainer.isHidden = !model.canToggleEmail
        emailToggleButton.image = makeSymbolImage(
            model.isEmailVisible ? "eye.slash" : "eye",
            pointSize: 12,
            weight: .medium
        )
        emailToggleButton.toolTip = model.isEmailVisible ? "隐藏邮箱" : "显示邮箱"

        balanceValueLabel.stringValue = model.remainingValue
        usageMetricView.apply(
            caption: model.usageLabel,
            value: model.usageValue,
            valueFont: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        )
        renewalMetricView.apply(
            caption: model.renewalLabel,
            value: model.renewalValue,
            valueFont: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        )

        packageSectionTitleLabel.isHidden = model.packageItems.isEmpty
        packageSectionTitleLabel.stringValue = model.packageSectionTitle ?? "有效套餐"
        packageStack.arrangedSubviews.forEach { view in
            packageStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for item in model.packageItems {
            let rowView = SummaryPackageRowView(frame: .zero)
            rowView.apply(item)
            packageStack.addArrangedSubview(rowView)
            rowView.widthAnchor.constraint(equalTo: packageStack.widthAnchor).isActive = true
        }

        progressLabel.stringValue = model.progressLabel
        progressValueLabel.stringValue = model.progressValue
        progressBarView.progress = model.progress

        layoutSubtreeIfNeeded()
        preferredHeight = max(276, cardView.fittingSize.height + 16)
        invalidateIntrinsicContentSize()
    }

    @objc private func handleToggleEmail() {
        onToggleEmail?()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, @unchecked Sendable {
    private let endpoint = URL(string: "https://codex.ylsagi.com/codex/info")!
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let menu = NSMenu()
    private let summaryMenuItem = NSMenuItem()
    private let summaryView = StatusSummaryView(frame: NSRect(x: 0, y: 0, width: StatusSummaryView.preferredWidth, height: 246))

    private var timer: Timer?
    private var apiKey: String = ""
    private var pollInterval: TimeInterval = 5
    private var displayStyle: StatusDisplayStyle = .remaining
    private var displayStyleMenuItems: [StatusDisplayStyle: NSMenuItem] = [:]
    private var statusFallbackText = "余额: --"
    private var latestUsage = "--"
    private var latestRemaining = "--"
    private var latestRenewal = "--"
    private var latestMessage = "等待数据"
    private var latestUsageLabel = "套餐用量(已用)"
    private var latestProgressLabel = "用量进度"
    private var latestEmail: String?
    private var latestPackageItems: [SummaryPackageItem] = []
    private var latestUsedPercent: Double?
    private var isEmailVisible = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        loadConfiguration()
        setupMenu()
        setupStatusButton()
        startPolling()
        refreshNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
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
    }

    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: DefaultsKey.apiKey)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
        defaults.set(displayStyle.rawValue, forKey: DefaultsKey.displayStyle)
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
        summaryView.onToggleEmail = { [weak self] in
            self?.handleToggleEmailVisibility()
        }
        summaryMenuItem.view = summaryView
        menu.addItem(summaryMenuItem)
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let apiKeyItem = NSMenuItem(title: "设置 API Key...", action: #selector(handleSetAPIKey), keyEquivalent: "k")
        apiKeyItem.target = self
        menu.addItem(apiKeyItem)

        let intervalItem = NSMenuItem(title: "设置轮询间隔...", action: #selector(handleSetInterval), keyEquivalent: "i")
        intervalItem.target = self
        menu.addItem(intervalItem)

        let openDashboardItem = NSMenuItem(title: "打开伊莉丝控制台", action: #selector(handleOpenDashboard), keyEquivalent: "d")
        openDashboardItem.target = self
        menu.addItem(openDashboardItem)

        let styleItem = NSMenuItem(title: "状态栏样式", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu(title: "状态栏样式")
        for style in StatusDisplayStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(handleSelectDisplayStyle(_:)), keyEquivalent: "")
            item.target = self
            item.tag = style.rawValue
            styleSubmenu.addItem(item)
            displayStyleMenuItems[style] = item
        }
        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)
        updateDisplayStyleMenuState()

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

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

    @objc private func handleRefresh() {
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

    @objc private func handleSelectDisplayStyle(_ sender: NSMenuItem) {
        guard let style = StatusDisplayStyle(rawValue: sender.tag) else { return }
        displayStyle = style
        saveConfiguration()
        updateDisplayStyleMenuState()
        renderStatusBar()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
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
                let usedPercent = Self.resolveUsedPercentage(usage: displayUsagePayload, remaining: usageRemainingNumber)
                let renewal = Self.resolveRenewalText(package: state.package)
                let packageItems = Self.buildPackageSummaryItems(package: state.package)
                let usageLabel = weeklyUsagePayload == nil ? "套餐用量(已用)" : "本周用量(已用)"
                let progressLabel = weeklyUsagePayload == nil ? "用量进度" : "本周用量进度"
                let usage: String
                if let usedPercent {
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
                        progressLabel: progressLabel
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
        usageLabel: String = "套餐用量(已用)",
        progressLabel: String = "用量进度"
    ) {
        latestUsage = usage
        latestRemaining = remaining
        latestRenewal = renewal
        latestMessage = message
        latestUsageLabel = usageLabel
        latestProgressLabel = progressLabel
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
                progressValue: progressValue,
                progress: latestUsedPercent.map { max(0, min(100, $0)) / 100 },
                footerText: latestMessage
            )
        )
        summaryView.frame = NSRect(origin: .zero, size: summaryView.intrinsicContentSize)
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

    private func updateDisplayStyleMenuState() {
        for style in StatusDisplayStyle.allCases {
            displayStyleMenuItems[style]?.state = (style == displayStyle) ? .on : .off
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

    private func applyTwoLineTitle(top: String, bottom: String) {
        guard let button = statusItem.button else { return }
        statusItem.length = AppMeta.stackedStatusMinWidth
        button.alignment = .center
        button.cell?.wraps = true
        button.cell?.lineBreakMode = .byClipping
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        let combined = NSMutableAttributedString(
            string: "\(top)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )
        combined.append(
            NSAttributedString(
                string: bottom,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: paragraph
                ]
            )
        )
        button.attributedTitle = combined
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

    private func makeCircularProgressImage(progress: Double) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 1.5
        let startAngle: CGFloat = 90
        let endAngle = startAngle - CGFloat(max(0, min(1, progress)) * 360)

        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        bgPath.lineWidth = 2
        NSColor.tertiaryLabelColor.setStroke()
        bgPath.stroke()

        let fgPath = NSBezierPath()
        fgPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        fgPath.lineWidth = 2
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

    nonisolated private static func resolveRenewalText(package: PackagePayload?) -> String? {
        guard let package = selectDisplayPackage(from: package?.packages),
              let expiresAt = package.expiresAt,
              let expiresDate = parseAPIDate(expiresAt)
        else {
            return nil
        }

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = Locale(identifier: "zh_CN")
        absoluteFormatter.timeZone = .current
        absoluteFormatter.dateFormat = "yyyy-MM-dd HH:mm"

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
