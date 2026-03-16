import AppKit
import Foundation

private enum DefaultsKey {
    static let apiKey = "api_key"
    static let interval = "poll_interval_seconds"
}

private enum AppMeta {
    static let displayName = "伊莉丝Codex账户监控助手"
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
    }

    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: DefaultsKey.apiKey)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
    }

    private func setupStatusButton() {
        guard let button = statusItem.button else { return }
        if apiKey.isEmpty {
            button.title = "余额: 未配置Key"
        } else {
            button.title = "余额: 加载中..."
        }
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
        statusItem.button?.title = text
    }

    private func updateMenu(
        usage: String,
        remaining: String,
        message: String,
        usedPercent: Double?,
        maskedEmail: String?
    ) {
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
