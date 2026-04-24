import Darwin
import Combine
import Foundation
import Network
import SwiftUI

struct MCPServerSnapshot: Encodable {
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
    let hasAGIKey: Bool
    let pollIntervalSeconds: Double
    let displayStyle: String
    let mcpStatusText: String
    let packageItems: [MCPPackageItem]
    let mountedModules: [MCPMountedPackageModule]
}

struct MCPPackageItem: Encodable {
    let title: String
    let subtitle: String
    let badgeText: String
}

struct MCPMountedPackageModule: Encodable {
    let title: String
    let statusText: String
    let remaining: String
    let usage: String
    let renewal: String
    let progressValue: String
    let progressFraction: Double?
    let packageItems: [MCPPackageItem]
}

final class MCPSnapshotStore: @unchecked Sendable {
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

final class MCPHTTPServer: @unchecked Sendable {
    private let stateProvider: @Sendable () -> Data
    private let resourceURI = "yls://codex-monitor/snapshot"
    private let toolName = "get_codex_monitor_snapshot"
    private let queue = DispatchQueue(label: "com.yls.codex-monitor.mcp-server")
    private var listener: NWListener?

    private(set) var port: UInt16
    private(set) var isRunning = false
    var lastError: String?
    var onStateChange: (@Sendable () -> Void)?

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
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw URLError(.badServerResponse)
        }
        let listener = try NWListener(using: params, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isRunning = true
                self.lastError = nil
            case .failed(let error):
                self.isRunning = false
                self.lastError = error.localizedDescription
            case .cancelled:
                self.isRunning = false
            default:
                break
            }
            self.onStateChange?()
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        onStateChange?()
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
                self.onStateChange?()
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
                    "error": "bad_request",
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
                "resource": resourceURI,
            ])
        case "/snapshot", "/mcp/snapshot":
            response = makeRawJSONResponse(stateProvider())
        case "/mcp":
            response = handleMCPRequest(body: request.body)
        default:
            response = makeJSONResponse([
                "ok": false,
                "error": "not_found",
                "path": request.path,
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
        let firstLine = header.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
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
        for line in header.split(whereSeparator: \.isNewline) {
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
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else {
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32700,
                    "message": "Parse error",
                ],
                "id": NSNull(),
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
                    "resources": [:],
                ],
                "serverInfo": [
                    "name": "yls-codex-monitor-mcp",
                    "version": "0.2.0",
                ],
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
                        "properties": [:],
                    ],
                ]],
            ]
        case "tools/call":
            let tool = params["name"] as? String ?? ""
            if tool == toolName {
                result = [
                    "content": [[
                        "type": "text",
                        "text": snapshotString,
                    ]],
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32601,
                        "message": "Unknown tool: \(tool)",
                    ],
                    "id": id,
                ])
            }
        case "resources/list":
            result = [
                "resources": [[
                    "uri": resourceURI,
                    "name": "Codex Monitor Snapshot",
                    "description": "伊莉丝 Codex 账户监控的最新本地快照",
                    "mimeType": "application/json",
                ]],
            ]
        case "resources/read":
            let uri = params["uri"] as? String ?? ""
            if uri == resourceURI {
                result = [
                    "contents": [[
                        "uri": resourceURI,
                        "mimeType": "application/json",
                        "text": snapshotString,
                    ]],
                ]
            } else {
                return makeJSONResponse([
                    "jsonrpc": "2.0",
                    "error": [
                        "code": -32602,
                        "message": "Unknown resource: \(uri)",
                    ],
                    "id": id,
                ])
            }
        default:
            return makeJSONResponse([
                "jsonrpc": "2.0",
                "error": [
                    "code": -32601,
                    "message": "Method not found: \(method)",
                ],
                "id": id,
            ])
        }

        return makeJSONResponse([
            "jsonrpc": "2.0",
            "result": result,
            "id": id,
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
            "",
        ].joined(separator: "\r\n")
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

@MainActor
final class CodexMonitorStore: ObservableObject {
    @Published private(set) var apiKey = ""
    @Published private(set) var agiAPIKey = ""
    @Published private(set) var pollInterval: TimeInterval = 5
    @Published private(set) var displayStyle: StatusDisplayStyle = .remaining
    @Published private(set) var panelMode: MenuPanelMode = .statistics
    @Published private(set) var statusFallbackText = "余额: --"
    @Published private(set) var mcpEnabled = true
    @Published private(set) var mcpPort: UInt16 = AppMeta.defaultMCPPort
    @Published private(set) var latestUsage = "--"
    @Published private(set) var latestRemaining = "--"
    @Published private(set) var latestRenewal = "--"
    @Published private(set) var latestMessage = "等待数据"
    @Published private(set) var latestUsageLabel = "已用/总"
    @Published private(set) var latestProgressLabel = "用量进度"
    @Published private(set) var latestProgressPrefix: String?
    @Published private(set) var latestEmail: String?
    @Published private(set) var latestPackageItems: [SummaryPackageItem] = []
    @Published private(set) var latestUsedPercent: Double?
    @Published private(set) var agiLatestUsage = "--"
    @Published private(set) var agiLatestRemaining = "--"
    @Published private(set) var agiLatestRenewal = "--"
    @Published private(set) var agiLatestMessage = ""
    @Published private(set) var agiLatestPackageItems: [SummaryPackageItem] = []
    @Published private(set) var agiLatestUsedPercent: Double?
    @Published private(set) var isEmailVisible = false
    @Published private(set) var mcpStatusText = "MCP 未启动"
    @Published private(set) var hasAPIKey = false
    @Published private(set) var hasAGIKey = false
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let mcpSnapshotStore = MCPSnapshotStore()
    private var pollingTask: Task<Void, Never>?
    private var isRefreshing = false
    private var hasBootstrapped = false

    private lazy var mcpServer: MCPHTTPServer = {
        let server = MCPHTTPServer(port: mcpPort) { [weak self] in
            self?.mcpSnapshotStore.get() ?? Data("{}".utf8)
        }
        server.onStateChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateMCPStatusText()
                self?.updateSnapshot()
            }
        }
        return server
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var summaryModel: StatusSummaryViewModel {
        let progressValue: String
        if let latestUsedPercent {
            progressValue = String(format: "%.2f%%", min(max(latestUsedPercent, 0), 100))
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

        return StatusSummaryViewModel(
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
            progress: latestUsedPercent.map { min(max($0, 0), 100) / 100 },
            footerText: latestMessage,
            hasAPIKey: hasAPIKey,
            hasAGIKey: hasAGIKey,
            pollIntervalText: "\(Int(pollInterval)) 秒",
            displayStyle: displayStyle,
            panelMode: panelMode,
            mcpStatusText: mcpStatusText,
            mountedModules: currentMountedModules()
        )
    }

    var statusBarPresentation: StatusBarPresentation {
        StatusBarPresentation(
            style: displayStyle,
            fallbackText: statusFallbackText,
            remainingText: latestRemaining,
            usageText: latestUsage,
            usedPercent: latestUsedPercent
        )
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        loadConfiguration()
        configureInitialState()
        restartMCPIfNeeded()
        restartPolling()
        triggerRefresh()
    }

    func triggerRefresh() {
        Task {
            await refreshNow()
        }
    }

    func togglePanelMode() {
        panelMode = panelMode == .statistics ? .settings : .statistics
    }

    func toggleEmailVisibility() {
        guard latestEmail?.isEmpty == false else { return }
        isEmailVisible.toggle()
        updateSnapshot()
    }

    func hideEmail() {
        guard isEmailVisible else { return }
        isEmailVisible = false
        updateSnapshot()
    }

    func selectDisplayStyle(_ style: StatusDisplayStyle) {
        guard displayStyle != style else { return }
        displayStyle = style
        saveConfiguration()
        updateSnapshot()
    }

    func saveAPIKey(_ value: String) {
        apiKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        hasAPIKey = !apiKey.isEmpty
        saveConfiguration()
        statusFallbackText = apiKey.isEmpty ? "余额: 未配置Key" : "余额: 加载中..."
        updateSnapshot()
        triggerRefresh()
    }

    func saveAGIKey(_ value: String) {
        agiAPIKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        hasAGIKey = !agiAPIKey.isEmpty
        if !hasAGIKey {
            resetAGIState(message: "")
        }
        saveConfiguration()
        updateSnapshot()
        triggerRefresh()
    }

    @discardableResult
    func savePollInterval(_ value: Double) -> Bool {
        guard value >= 1 else {
            errorMessage = "轮询间隔必须 >= 1 秒"
            return false
        }
        pollInterval = value
        saveConfiguration()
        restartPolling()
        updateSnapshot()
        triggerRefresh()
        return true
    }

    @discardableResult
    func saveMCPConfiguration(enabled: Bool, port: UInt16) -> Bool {
        guard port > 0 else {
            errorMessage = "MCP 端口必须是 1-65535 之间的数字"
            return false
        }
        mcpEnabled = enabled
        mcpPort = port
        saveConfiguration()
        restartMCPIfNeeded()
        return true
    }

    func dismissError() {
        errorMessage = nil
    }

    func quit() {
        exit(EXIT_SUCCESS)
    }

    func refreshNow() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let codexRefresh: Void = refreshCodexNow()
        async let agiRefresh: Void = refreshAGINow()
        _ = await (codexRefresh, agiRefresh)
    }

    private func refreshCodexNow() async {
        guard !apiKey.isEmpty else {
            updateStatusBar(text: "余额: 未配置Key")
            updateMenu(usage: "--", remaining: "--", message: "请先设置 API Key", usedPercent: nil, email: nil)
            return
        }

        var request = URLRequest(url: AppMeta.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                updateStatusBar(text: "余额: 响应异常")
                updateMenu(usage: "--", remaining: "--", message: "无效响应", usedPercent: nil, email: nil)
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                updateStatusBar(text: "余额: HTTP \(httpResponse.statusCode)")
                updateMenu(
                    usage: "--",
                    remaining: "--",
                    message: "接口返回 HTTP \(httpResponse.statusCode)",
                    usedPercent: nil,
                    email: nil
                )
                return
            }

            do {
                let decoded = try JSONDecoder().decode(APIEnvelope.self, from: data)
                if let code = decoded.code, code != 200 {
                    let apiMessage = decoded.msg ?? decoded.error ?? decoded.details ?? "接口返回业务错误"
                    updateStatusBar(text: "余额: 业务错误")
                    updateMenu(
                        usage: "--",
                        remaining: "--",
                        message: "错误码 \(code): \(apiMessage)",
                        usedPercent: nil,
                        email: nil
                    )
                    return
                }

                if let errorText = decoded.error {
                    let details = decoded.details ?? decoded.msg ?? errorText
                    updateStatusBar(text: "余额: 授权错误")
                    updateMenu(usage: "--", remaining: "--", message: details, usedPercent: nil, email: nil)
                    return
                }

                guard let state = decoded.state else {
                    let text = decoded.msg ?? decoded.details ?? "响应里缺少 state 字段"
                    updateStatusBar(text: "余额: 响应异常")
                    updateMenu(usage: "--", remaining: "--", message: text, usedPercent: nil, email: nil)
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

                updateStatusBar(text: "余: \(remaining)")
                updateMenu(
                    usage: usage,
                    remaining: remaining,
                    message: "更新时间: \(Self.timeFormatter.string(from: Date()))",
                    usedPercent: usedPercent,
                    email: state.user?.email,
                    renewal: renewal ?? "--",
                    packageItems: packageItems,
                    usageLabel: usageLabel,
                    progressLabel: progressLabel,
                    progressPrefix: progressPrefix
                )
            } catch {
                let rawSnippet = String(data: data, encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(120) ?? "无法读取响应内容"
                updateStatusBar(text: "余额: 解析失败")
                updateMenu(
                    usage: "--",
                    remaining: "--",
                    message: "解析错误: \(error.localizedDescription) | \(rawSnippet)",
                    usedPercent: nil,
                    email: nil
                )
            }
        } catch {
            updateStatusBar(text: "余额: 请求失败")
            updateMenu(
                usage: "--",
                remaining: "--",
                message: "网络错误: \(error.localizedDescription)",
                usedPercent: nil,
                email: nil
            )
        }
    }

    private func refreshAGINow() async {
        guard !agiAPIKey.isEmpty else {
            resetAGIState(message: "")
            return
        }

        var request = URLRequest(url: AppMeta.agiPackageEndpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(agiAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                updateAGIMenu(usage: "--", remaining: "--", message: "AGI 响应异常", usedPercent: nil)
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                updateAGIMenu(
                    usage: "--",
                    remaining: "--",
                    message: "AGI 接口 HTTP \(httpResponse.statusCode)",
                    usedPercent: nil
                )
                return
            }

            do {
                let decoded = try JSONDecoder().decode(AGIPackageEnvelope.self, from: data)
                if let code = decoded.code, code != 200 {
                    updateAGIMenu(
                        usage: "--",
                        remaining: "--",
                        message: "AGI 错误码 \(code): \(decoded.message ?? "接口返回业务错误")",
                        usedPercent: nil
                    )
                    return
                }

                guard let payload = decoded.data else {
                    updateAGIMenu(usage: "--", remaining: "--", message: "AGI 响应缺少 data 字段", usedPercent: nil)
                    return
                }

                let packages = payload.packages ?? []
                let totalBytes = payload.summary?.totalByte?.doubleValue
                    ?? packages.compactMap { $0.byteTotal?.doubleValue }.reduce(0, +)
                let remainingBytes = payload.summary?.remainingByte?.doubleValue
                    ?? packages.compactMap { $0.byteRemaining?.doubleValue }.reduce(0, +)
                let usedBytes = payload.summary?.usedByte?.doubleValue
                    ?? packages.compactMap { $0.byteUsed?.doubleValue }.reduce(0, +)
                let usedPercent = Self.resolveUsedPercentage(total: totalBytes, used: usedBytes)
                let packageItems = Self.buildAGIPackageSummaryItems(packages: packages)
                let renewal = Self.resolveAGIRenewalText(summary: payload.summary, packages: packages) ?? "--"
                let usage: String

                if totalBytes > 0 {
                    usage = "\(Self.formatByteCount(usedBytes))/\(Self.formatByteCount(totalBytes))"
                } else if usedBytes > 0 {
                    usage = Self.formatByteCount(usedBytes)
                } else {
                    usage = "--"
                }

                updateAGIMenu(
                    usage: usage,
                    remaining: Self.formatByteCount(remainingBytes),
                    message: "更新时间: \(Self.timeFormatter.string(from: Date()))",
                    usedPercent: usedPercent,
                    renewal: renewal,
                    packageItems: packageItems
                )
            } catch {
                let rawSnippet = String(data: data, encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(120) ?? "无法读取响应内容"
                updateAGIMenu(
                    usage: "--",
                    remaining: "--",
                    message: "AGI 解析错误: \(error.localizedDescription) | \(rawSnippet)",
                    usedPercent: nil
                )
            }
        } catch {
            updateAGIMenu(
                usage: "--",
                remaining: "--",
                message: "AGI 网络错误: \(error.localizedDescription)",
                usedPercent: nil
            )
        }
    }

    var currentAPIKeyValue: String {
        apiKey
    }

    var currentAGIKeyValue: String {
        agiAPIKey
    }

    private func configureInitialState() {
        hasAPIKey = !apiKey.isEmpty
        hasAGIKey = !agiAPIKey.isEmpty
        statusFallbackText = apiKey.isEmpty ? "余额: 未配置Key" : "余额: 加载中..."
        updateMCPStatusText()
        updateSnapshot()
    }

    private func loadConfiguration() {
        apiKey = defaults.string(forKey: DefaultsKey.apiKey) ?? ""
        if defaults.object(forKey: DefaultsKey.agiAPIKey) != nil {
            agiAPIKey = defaults.string(forKey: DefaultsKey.agiAPIKey) ?? ""
        } else {
            agiAPIKey = ProcessInfo.processInfo.environment[AppMeta.agiEnvironmentKey] ?? ""
        }
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
        defaults.set(apiKey, forKey: DefaultsKey.apiKey)
        defaults.set(agiAPIKey, forKey: DefaultsKey.agiAPIKey)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
        defaults.set(displayStyle.rawValue, forKey: DefaultsKey.displayStyle)
        defaults.set(mcpEnabled, forKey: DefaultsKey.mcpEnabled)
        defaults.set(Int(mcpPort), forKey: DefaultsKey.mcpPort)
    }

    private func restartPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while let self {
                let interval = await MainActor.run { self.pollInterval }
                let nanoseconds = UInt64(max(interval, 1) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                await self.refreshNow()
            }
        }
    }

    private func restartMCPIfNeeded() {
        mcpServer.stop()
        guard mcpEnabled else {
            updateMCPStatusText()
            updateSnapshot()
            return
        }
        do {
            try mcpServer.updatePort(mcpPort)
        } catch {
            mcpServer.stop()
            mcpServer.lastError = error.localizedDescription
        }
        updateMCPStatusText()
        updateSnapshot()
    }

    private func updateMCPStatusText() {
        if !mcpEnabled {
            mcpStatusText = "已关闭"
            return
        }
        if mcpServer.isRunning {
            mcpStatusText = "http://\(AppMeta.mcpHost):\(mcpPort)/mcp/snapshot"
            return
        }
        if let error = mcpServer.lastError, !error.isEmpty {
            mcpStatusText = "启动失败: \(error)"
            return
        }
        mcpStatusText = "启动中..."
    }

    private func updateStatusBar(text: String) {
        statusFallbackText = text
        updateMCPStatusText()
        updateSnapshot()
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
        updateMCPStatusText()
        updateSnapshot()
    }

    private func updateAGIMenu(
        usage: String,
        remaining: String,
        message: String,
        usedPercent: Double?,
        renewal: String = "--",
        packageItems: [SummaryPackageItem] = []
    ) {
        agiLatestUsage = usage
        agiLatestRemaining = remaining
        agiLatestRenewal = renewal
        agiLatestMessage = message
        agiLatestPackageItems = packageItems
        agiLatestUsedPercent = usedPercent
        updateMCPStatusText()
        updateSnapshot()
    }

    private func resetAGIState(message: String) {
        agiLatestUsage = "--"
        agiLatestRemaining = "--"
        agiLatestRenewal = "--"
        agiLatestMessage = message
        agiLatestPackageItems = []
        agiLatestUsedPercent = nil
        updateSnapshot()
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
            || statusFallbackText.contains("响应异常")
        {
            return ("异常", .critical)
        }
        return ("等待中", .neutral)
    }

    private func currentAGIStatus() -> (String, SummaryStatusTone) {
        if !hasAGIKey {
            return ("未配置", .warning)
        }
        if agiLatestRemaining != "--" || !agiLatestPackageItems.isEmpty {
            return ("已挂载", .success)
        }
        if agiLatestMessage.contains("HTTP")
            || agiLatestMessage.contains("错误")
            || agiLatestMessage.contains("异常")
            || agiLatestMessage.contains("失败")
        {
            return ("异常", .critical)
        }
        return ("加载中", .neutral)
    }

    private func currentMountedModules() -> [MountedPackageModuleSummary] {
        guard hasAGIKey || !agiLatestMessage.isEmpty || !agiLatestPackageItems.isEmpty else {
            return []
        }

        let (statusText, statusTone) = currentAGIStatus()
        let progressValue = agiLatestUsedPercent.map { String(format: "%.2f%%", min(max($0, 0), 100)) } ?? "--"
        let packageSectionTitle: String? = if agiLatestPackageItems.isEmpty {
            nil
        } else {
            "已挂载套餐（\(agiLatestPackageItems.count)）"
        }

        return [
            MountedPackageModuleSummary(
                title: "AGI 套餐",
                statusText: statusText,
                statusTone: statusTone,
                usageLabel: "已用/总字节",
                usageValue: agiLatestUsage,
                remainingLabel: "剩余字节",
                remainingValue: agiLatestRemaining,
                renewalLabel: "最近到期",
                renewalValue: agiLatestRenewal,
                progressLabel: "AGI 用量进度",
                progressValue: progressValue,
                progress: agiLatestUsedPercent.map { min(max($0, 0), 100) / 100 },
                footerText: agiLatestMessage.isEmpty ? "等待数据" : agiLatestMessage,
                packageSectionTitle: packageSectionTitle,
                packageItems: agiLatestPackageItems
            ),
        ]
    }

    private func updateSnapshot() {
        let snapshot = MCPServerSnapshot(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            displayName: AppMeta.displayName,
            dashboardURL: AppMeta.dashboardURL.absoluteString,
            pricingURL: AppMeta.pricingURL.absoluteString,
            statusText: currentSummaryStatus().0,
            latestMessage: latestMessage,
            remaining: latestRemaining,
            usage: latestUsage,
            renewal: latestRenewal,
            progressLabel: latestProgressLabel,
            progressPrefix: latestProgressPrefix,
            usedPercent: latestUsedPercent,
            email: latestEmail,
            hasAPIKey: hasAPIKey,
            hasAGIKey: hasAGIKey,
            pollIntervalSeconds: pollInterval,
            displayStyle: displayStyle.title,
            mcpStatusText: mcpStatusText,
            packageItems: latestPackageItems.map {
                MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
            },
            mountedModules: currentMountedModules().map { module in
                MCPMountedPackageModule(
                    title: module.title,
                    statusText: module.statusText,
                    remaining: module.remainingValue,
                    usage: module.usageValue,
                    renewal: module.renewalValue,
                    progressValue: module.progressValue,
                    progressFraction: module.progress,
                    packageItems: module.packageItems.map {
                        MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
                    }
                )
            }
        )
        let data = (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8)
        mcpSnapshotStore.set(data)
        CodexMonitorWidgetBridge.writeSnapshot(data)
    }

    nonisolated static func resolveUsedPercentage(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
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

    nonisolated static func resolveUsageQuotaPair(
        usage: UsagePayload?,
        remaining: FlexibleNumber
    ) -> (used: String, total: String)? {
        guard let usedQuota = resolveUsedQuota(usage: usage, remaining: remaining),
              let totalQuota = usage?.totalQuota?.doubleValue
        else {
            return nil
        }
        return (
            used: formatQuotaValue(usedQuota),
            total: formatQuotaValue(totalQuota)
        )
    }

    nonisolated static func resolveUsedQuota(usage: UsagePayload?, remaining: FlexibleNumber) -> Double? {
        guard
            let totalQuota = usage?.totalQuota?.doubleValue,
            totalQuota > 0,
            let remainingQuota = remaining.doubleValue
        else {
            return nil
        }
        return max(0, totalQuota - remainingQuota)
    }

    nonisolated static func formatQuotaValue(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.005 {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", value)
    }

    nonisolated static func resolveUsedPercentage(total: Double?, used: Double?) -> Double? {
        guard let total, total > 0, let used else {
            return nil
        }
        return min(max((used / total) * 100, 0), 100)
    }

    nonisolated static func formatByteCount(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0 else {
            return "--"
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        let roundedValue = Int64(value.rounded())
        let numberText = formatter.string(from: NSNumber(value: roundedValue)) ?? "\(roundedValue)"
        return "\(numberText) B"
    }

    nonisolated static func resolveAGIRenewalText(summary: AGIPackageSummary?, packages: [AGIPackageItem]) -> String? {
        let expiryText = summary?.latestExpireTime
            ?? packages.compactMap { $0.expireTime }.sorted().first
        guard let expiryText, let expiresDate = parseAPIDate(expiryText) else {
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

    nonisolated static func buildAGIPackageSummaryItems(packages: [AGIPackageItem]) -> [SummaryPackageItem] {
        packages
            .compactMap { item -> (AGIPackageItem, Date)? in
                guard let expiryText = item.expireTime, let expiresDate = parseAPIDate(expiryText) else {
                    return nil
                }
                return (item, expiresDate)
            }
            .sorted(by: { $0.1 < $1.1 })
            .map { item, expiresDate in
                let createText = parseAPIDate(item.createTime ?? "").map { compactDateFormatter.string(from: $0) } ?? "--"
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

                let reasonText = (item.reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? item.reason!
                    : "无备注"

                return SummaryPackageItem(
                    title: normalizeAGIPackageTitle(orderClass: item.orderClass, level: item.level),
                    subtitle: "开通 \(createText)  到期 \(expireText)  · \(reasonText)",
                    badgeText: daysRemaining == 0 ? "今天到期" : "剩\(daysRemaining)天",
                    badgeTone: badgeTone
                )
            }
    }

    nonisolated static func resolveRenewalText(package: PackagePayload?) -> String? {
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

    nonisolated static func buildPackageSummaryItems(package: PackagePayload?) -> [SummaryPackageItem] {
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

    nonisolated static func selectDisplayPackage(from packages: [PackageItem]?) -> PackageItem? {
        let now = Date()
        let candidates = activePackages(from: packages)

        if let upcoming = candidates
            .filter({ $0.1 >= now })
            .min(by: { $0.1 < $1.1 })
        {
            return upcoming.0
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    nonisolated static func activePackages(from packages: [PackageItem]?) -> [(PackageItem, Date)] {
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

    nonisolated static func parseAPIDate(_ rawValue: String) -> Date? {
        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractionalSeconds.date(from: rawValue) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }

    nonisolated static func normalizePackageTitle(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "未知套餐" }
        return rawValue
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func normalizeAGIPackageTitle(orderClass: String?, level: Int?) -> String {
        let order = orderClass?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (order, level) {
        case let (order?, level?) where !order.isEmpty:
            return "\(order) Lv\(level)"
        case let (order?, _) where !order.isEmpty:
            return order
        case let (_, level?):
            return "Lv\(level)"
        default:
            return "AGI 套餐"
        }
    }

    nonisolated static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    nonisolated static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}
