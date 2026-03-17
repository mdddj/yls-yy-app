import AppKit
import Foundation

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
    let userPackgeUsage: UsagePayload?
    let remainingQuota: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case user
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let endpoint = URL(string: "https://codex.ylsagi.com/codex/info")!
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let menu = NSMenu()
    private let emailMenuItem = NSMenuItem(title: "用户邮箱: --", action: nil, keyEquivalent: "")
    private let usageMenuItem = NSMenuItem(title: "套餐用量(已用): --", action: nil, keyEquivalent: "")
    private let remainingMenuItem = NSMenuItem(title: "剩余额度: --", action: nil, keyEquivalent: "")
    private let progressTextMenuItem = NSMenuItem(title: "用量进度: --", action: nil, keyEquivalent: "")
    private let progressBarMenuItem = NSMenuItem()
    private let lastUpdateMenuItem = NSMenuItem(title: "最后更新: --", action: nil, keyEquivalent: "")
    private let progressIndicator: NSProgressIndicator = {
        let bar = NSProgressIndicator(frame: NSRect(x: 16, y: 8, width: 220, height: 14))
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 100
        bar.doubleValue = 0
        bar.controlSize = .small
        return bar
    }()

    private var timer: Timer?
    private var apiKey: String = ""
    private var pollInterval: TimeInterval = 5
    private var displayStyle: StatusDisplayStyle = .remaining
    private var displayStyleMenuItems: [StatusDisplayStyle: NSMenuItem] = [:]
    private var statusFallbackText = "余额: --"
    private var latestUsage = "--"
    private var latestRemaining = "--"
    private var latestUsedPercent: Double?

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
        renderStatusBar()
    }

    private func setupMenu() {
        emailMenuItem.isEnabled = false
        usageMenuItem.isEnabled = false
        remainingMenuItem.isEnabled = false
        progressTextMenuItem.isEnabled = false
        lastUpdateMenuItem.isEnabled = false
        let progressContainer = NSView(frame: NSRect(x: 0, y: 0, width: 252, height: 30))
        progressContainer.addSubview(progressIndicator)
        progressBarMenuItem.view = progressContainer

        menu.addItem(NSMenuItem(title: AppMeta.displayName, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(emailMenuItem)
        menu.addItem(usageMenuItem)
        menu.addItem(remainingMenuItem)
        menu.addItem(progressTextMenuItem)
        menu.addItem(progressBarMenuItem)
        menu.addItem(lastUpdateMenuItem)
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
            updateMenu(usage: "--", remaining: "--", message: "请先设置 API Key", usedPercent: nil, maskedEmail: nil)
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
                    self.updateMenu(usage: "--", remaining: "--", message: "网络错误: \(error.localizedDescription)", usedPercent: nil, maskedEmail: nil)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: 响应异常")
                    self.updateMenu(usage: "--", remaining: "--", message: "无效响应", usedPercent: nil, maskedEmail: nil)
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                DispatchQueue.main.async {
                    self.updateStatusBar(text: "余额: HTTP \(httpResponse.statusCode)")
                    self.updateMenu(usage: "--", remaining: "--", message: "接口返回 HTTP \(httpResponse.statusCode)", usedPercent: nil, maskedEmail: nil)
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
                            maskedEmail: nil
                        )
                    }
                    return
                }

                if let errorText = decoded.error {
                    let details = decoded.details ?? decoded.msg ?? errorText
                    DispatchQueue.main.async {
                        self.updateStatusBar(text: "余额: 授权错误")
                        self.updateMenu(usage: "--", remaining: "--", message: details, usedPercent: nil, maskedEmail: nil)
                    }
                    return
                }

                guard let state = decoded.state else {
                    let text = decoded.msg ?? decoded.details ?? "响应里缺少 state 字段"
                    DispatchQueue.main.async {
                        self.updateStatusBar(text: "余额: 响应异常")
                        self.updateMenu(usage: "--", remaining: "--", message: text, usedPercent: nil, maskedEmail: nil)
                    }
                    return
                }

                let usagePayload = state.userPackgeUsage
                guard let remainingNumber = usagePayload?.remainingQuota ?? state.remainingQuota else {
                    throw NSError(
                        domain: "BalanceParse",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "缺少 remaining_quota 字段"]
                    )
                }

                let remaining = remainingNumber.display
                let usedPercent = Self.resolveUsedPercentage(usage: usagePayload, remaining: remainingNumber)
                let maskedEmail = Self.maskEmail(state.user?.email)
                let usage: String
                if let usedPercent {
                    usage = String(format: "%.2f%%", usedPercent)
                } else if let totalCost = usagePayload?.totalCost?.display {
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
                        maskedEmail: maskedEmail
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
                        maskedEmail: nil
                    )
                }
            }
        }.resume()
    }

    private func updateStatusBar(text: String) {
        statusFallbackText = text
        renderStatusBar()
    }

    private func updateMenu(
        usage: String,
        remaining: String,
        message: String,
        usedPercent: Double?,
        maskedEmail: String?
    ) {
        latestUsage = usage
        latestRemaining = remaining
        latestUsedPercent = usedPercent

        emailMenuItem.title = "用户邮箱: \(maskedEmail ?? "--")"
        usageMenuItem.title = "套餐用量(已用): \(usage)"
        remainingMenuItem.title = "剩余额度: \(remaining)"
        if let usedPercent {
            let clamped = max(0, min(100, usedPercent))
            progressTextMenuItem.title = String(format: "用量进度: %.2f%%", clamped)
            progressIndicator.doubleValue = clamped
        } else {
            progressTextMenuItem.title = "用量进度: --"
            progressIndicator.doubleValue = 0
        }
        lastUpdateMenuItem.title = message
        renderStatusBar()
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
