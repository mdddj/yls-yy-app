import AppKit
import Combine
import Foundation
import Network
import SwiftUI

private enum DefaultsKey {
    static let apiKey = "api_key"
    static let codexAPIKey = "codex_api_key"
    static let agiAPIKey = "agi_api_key"
    static let selectedSource = "selected_source"
    static let statisticsDisplayMode = "statistics_display_mode"
    static let interval = "poll_interval_seconds"
    static let displayStyle = "status_display_style"
    static let mcpEnabled = "mcp_enabled"
    static let mcpPort = "mcp_port"
}

private enum AppMeta {
    static let displayName = "伊莉丝账户监控助手"
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

private enum PackageSource: String, CaseIterable {
    case codex
    case agi

    var title: String {
        switch self {
        case .codex:
            return "Codex 套餐"
        case .agi:
            return "AGI 套餐"
        }
    }

    var chipTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    var settingsTitle: String {
        switch self {
        case .codex:
            return "Codex"
        case .agi:
            return "AGI"
        }
    }

    var endpoint: URL {
        switch self {
        case .codex:
            return URL(string: "https://codex.ylsagi.com/codex/info")!
        case .agi:
            return URL(string: "https://api.ylsagi.com/user/package")!
        }
    }

    var dashboardURL: String? {
        switch self {
        case .codex:
            return "https://code.ylsagi.com/user/dashboard"
        case .agi:
            return nil
        }
    }

    var pricingURL: String? {
        switch self {
        case .codex:
            return "https://code.ylsagi.com/pricing"
        case .agi:
            return nil
        }
    }

    var apiKeyDefaultsKey: String {
        switch self {
        case .codex:
            return DefaultsKey.codexAPIKey
        case .agi:
            return DefaultsKey.agiAPIKey
        }
    }

    var legacyDefaultsKey: String? {
        switch self {
        case .codex:
            return DefaultsKey.apiKey
        case .agi:
            return nil
        }
    }

    var environmentVariableCandidates: [String] {
        switch self {
        case .codex:
            return ["YLS_CODEX", "YLS_CODEX_KEY", "YLS_CODEX_TOKEN", "YLS_API_KEY"]
        case .agi:
            return ["YLS_AGI_KEY", "YLS_AGI", "YLS_AGI_TOKEN"]
        }
    }

    var keyButtonTitle: String {
        switch self {
        case .codex:
            return "Codex API Key"
        case .agi:
            return "AGI API Key"
        }
    }

    var apiKeyDialogTitle: String { "设置 \(settingsTitle) API Key" }

    var apiKeyDialogHint: String {
        "请输入 \(settingsTitle) Bearer Token（只填 token 本体）"
    }

    var openDashboardTitle: String {
        switch self {
        case .codex:
            return "打开 Codex 控制台"
        case .agi:
            return "打开套餐控制台"
        }
    }
}

private enum APIKeyOrigin {
    case userDefaults
    case environment
    case none
}

private struct APIKeyResolution {
    let value: String
    let origin: APIKeyOrigin
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

private enum StatisticsDisplayMode: Int, CaseIterable {
    case single = 0
    case dual

    var title: String {
        switch self {
        case .single:
            return "单显"
        case .dual:
            return "双显"
        }
    }

    var fullTitle: String {
        switch self {
        case .single:
            return "单显模式"
        case .dual:
            return "双显模式"
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

private struct AGIAPIEnvelope: Decodable {
    let code: Int?
    let message: String?
    let data: AGIData?
}

private struct AGIData: Decodable {
    let packages: [AGIPackage]?
    let summary: AGISummary?
}

private struct AGIPackage: Decodable {
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

private struct AGISummary: Decodable {
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

private enum CodexLogAPI {
    static let endpoint = URL(string: "https://code.ylsagi.com/codex/logs")!
}

private struct CodexLogAPIEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let data: CodexLogPage?
}

private struct CodexLogPage: Decodable {
    let items: [CodexLogItem]
    let page: Int
    let pageSize: Int
    let total: Int

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case pageSize = "page_size"
        case total
    }
}

private struct CodexLogItem: Decodable, Identifiable {
    let rawID: String?
    let type: String?
    let model: String?
    let reasoning: String?
    let inputTokens: FlexibleNumber?
    let inputTokensCached: FlexibleNumber?
    let inputCacheCreationTokens: FlexibleNumber?
    let outputTokens: FlexibleNumber?
    let outputTokensReasoning: FlexibleNumber?
    let totalTokens: FlexibleNumber?
    let inputCost: FlexibleNumber?
    let outputCost: FlexibleNumber?
    let cacheCreationCost: FlexibleNumber?
    let cacheReadCost: FlexibleNumber?
    let totalCost: FlexibleNumber?
    let createdAt: String?
    let updatedAt: String?

    var id: String {
        rawID ?? "\(createdAt ?? "unknown")-\(totalTokens?.display ?? "0")"
    }

    enum CodingKeys: String, CodingKey {
        case rawID = "_id"
        case type
        case model
        case reasoning
        case inputTokens = "input_tokens"
        case inputTokensCached = "input_tokens_cached"
        case inputCacheCreationTokens = "input_cache_creation_tokens"
        case outputTokens = "output_tokens"
        case outputTokensReasoning = "output_tokens_reasoning"
        case totalTokens = "total_tokens"
        case inputCost = "input_cost"
        case outputCost = "output_cost"
        case cacheCreationCost = "cache_creation_cost"
        case cacheReadCost = "cache_read_cost"
        case totalCost = "total_cost"
        case createdAt
        case updatedAt
    }
}

private enum CodexLogFormat {
    static let pageSizeOptions = [10, 20, 50, 100]

    static func tokenText(_ value: FlexibleNumber?) -> String {
        numberText(value?.doubleValue)
    }

    static func costText(_ value: FlexibleNumber?) -> String {
        costText(value?.doubleValue)
    }

    static func costText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        if abs(value) < 0.00005 {
            return "$0"
        }
        return String(format: "$%.4f", value)
    }

    static func dateText(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "--" }
        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        if let date = isoWithFractionalSeconds.date(from: rawValue) ?? iso.date(from: rawValue) {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_CN")
            dateFormatter.timeZone = .current
            dateFormatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
            return dateFormatter.string(from: date)
        }
        return rawValue
    }

    static func tokenSummary(for item: CodexLogItem) -> String {
        let input = tokenText(item.inputTokens)
        let output = tokenText(item.outputTokens)
        let cached = item.inputTokensCached?.doubleValue ?? 0
        let reasoning = item.outputTokensReasoning?.doubleValue ?? 0

        var inputPart = "In \(input)"
        if cached > 0 {
            inputPart += " (cached \(numberText(cached)))"
        }

        var outputPart = "Out \(output)"
        if reasoning > 0 {
            outputPart += " (think \(numberText(reasoning)))"
        }

        return "\(inputPart) · \(outputPart)"
    }

    static func costSummary(for item: CodexLogItem) -> String {
        let cacheCost = (item.cacheReadCost?.doubleValue ?? 0) + (item.cacheCreationCost?.doubleValue ?? 0)
        return "输入 \(costText(item.inputCost)) · 输出 \(costText(item.outputCost)) · 缓存 \(costText(cacheCost))"
    }

    static func billableInputTokens(for item: CodexLogItem) -> String {
        guard let input = item.inputTokens?.doubleValue else { return "--" }
        let cached = item.inputTokensCached?.doubleValue ?? 0
        return numberText(max(0, input - cached))
    }

    static func outputDetailText(for item: CodexLogItem) -> String {
        let output = tokenText(item.outputTokens)
        let reasoning = item.outputTokensReasoning?.doubleValue ?? 0
        guard reasoning > 0 else { return output }
        return "\(output)  (think \(numberText(reasoning)))"
    }

    static func cacheCost(for item: CodexLogItem) -> String {
        costText((item.cacheReadCost?.doubleValue ?? 0) + (item.cacheCreationCost?.doubleValue ?? 0))
    }

    private static func numberText(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(value.rounded() - value) < 0.005 ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }
}

@MainActor
private final class CodexLogViewModel: ObservableObject, @unchecked Sendable {
    @Published private(set) var items: [CodexLogItem] = []
    @Published private(set) var page = 1
    @Published var pageSize = 20
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiKey: String
    private var latestRequestID = UUID()

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(total) / Double(max(pageSize, 1)))))
    }

    var pageSummary: String {
        "第 \(page) / \(totalPages) 页"
    }

    var totalSummary: String {
        total > 0 ? "共 \(total) 条" : "暂无记录"
    }

    var canGoPrevious: Bool {
        page > 1 && !isLoading
    }

    var canGoNext: Bool {
        page < totalPages && !isLoading
    }

    func loadIfNeeded() {
        guard items.isEmpty, !isLoading, errorMessage == nil else { return }
        load(page: 1)
    }

    func reload() {
        load(page: page)
    }

    func loadPreviousPage() {
        guard canGoPrevious else { return }
        load(page: page - 1)
    }

    func loadNextPage() {
        guard canGoNext else { return }
        load(page: page + 1)
    }

    func load(page requestedPage: Int) {
        guard !apiKey.isEmpty else {
            items = []
            total = 0
            errorMessage = "请先设置 Codex API Key"
            return
        }

        let boundedPage = total > 0
            ? max(1, min(requestedPage, totalPages))
            : max(1, requestedPage)
        let currentPageSize = max(1, pageSize)
        let requestID = UUID()
        latestRequestID = requestID
        isLoading = true
        errorMessage = nil

        Task { [weak self, apiKey, boundedPage, currentPageSize, requestID] in
            do {
                let page = try await Self.fetchLogs(
                    apiKey: apiKey,
                    page: boundedPage,
                    pageSize: currentPageSize
                )
                guard let self, self.latestRequestID == requestID else { return }
                self.items = page.items
                self.page = page.page
                self.pageSize = page.pageSize
                self.total = page.total
                self.errorMessage = nil
                self.isLoading = false
            } catch {
                guard let self, self.latestRequestID == requestID else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    nonisolated private static func fetchLogs(apiKey: String, page: Int, pageSize: Int) async throws -> CodexLogPage {
        guard var components = URLComponents(url: CodexLogAPI.endpoint, resolvingAgainstBaseURL: false) else {
            throw makeLogError("日志接口地址无效")
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        guard let url = components.url else {
            throw makeLogError("日志接口分页参数无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw makeLogError("日志接口响应异常")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw makeLogError("日志接口返回 HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(CodexLogAPIEnvelope.self, from: data)
            if let code = decoded.code, code != 200 {
                throw makeLogError("错误码 \(code): \(decoded.msg ?? "接口返回业务错误")")
            }
            guard let page = decoded.data else {
                throw makeLogError(decoded.msg ?? "响应里缺少 data 字段")
            }
            return page
        } catch let error as NSError where error.domain == "CodexLog" {
            throw error
        } catch {
            let rawSnippet = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(120) ?? "无法读取响应内容"
            throw makeLogError("解析日志失败: \(error.localizedDescription) | \(rawSnippet)")
        }
    }

    nonisolated private static func makeLogError(_ description: String) -> NSError {
        NSError(
            domain: "CodexLog",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}

private struct CodexLogWindowView: View {
    @StateObject private var viewModel: CodexLogViewModel
    @State private var expandedLogIDs: Set<String> = []

    init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: CodexLogViewModel(apiKey: apiKey))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minWidth: 960, minHeight: 540)
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.items.map(\.id)) { ids in
            expandedLogIDs.formIntersection(Set(ids))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Codex Log", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 16, weight: .bold))

            Text(viewModel.totalSummary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Button(action: viewModel.reload) {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var content: some View {
        ZStack {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        CodexLogTableHeader()

                        ForEach(viewModel.items) { item in
                            Divider()
                            CodexLogRow(
                                item: item,
                                isExpanded: expandedLogIDs.contains(item.id)
                            ) {
                                if expandedLogIDs.contains(item.id) {
                                    expandedLogIDs.remove(item.id)
                                } else {
                                    expandedLogIDs.insert(item.id)
                                }
                            }
                        }
                        Divider()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }

            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("加载日志...")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.errorMessage == nil ? "doc.text" : "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(viewModel.errorMessage ?? "暂无日志")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            if viewModel.errorMessage != nil {
                Button(action: viewModel.reload) {
                    Label("重试", systemImage: "arrow.clockwise")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Picker("每页", selection: $viewModel.pageSize) {
                ForEach(CodexLogFormat.pageSizeOptions, id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
            .frame(width: 110)
            .onChange(of: viewModel.pageSize) { _ in
                viewModel.load(page: 1)
            }

            Text(viewModel.pageSummary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Button(action: viewModel.loadPreviousPage) {
                Label("上一页", systemImage: "chevron.left")
            }
            .disabled(!viewModel.canGoPrevious)

            Button(action: viewModel.loadNextPage) {
                Label("下一页", systemImage: "chevron.right")
            }
            .disabled(!viewModel.canGoNext)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

private struct CodexLogTableHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            Text("时间")
                .frame(width: 190, alignment: .leading)

            Text("模型")
                .frame(width: 150, alignment: .leading)

            Text("Tokens")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("费用")
                .frame(width: 260, alignment: .leading)

            Text("明细")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct CodexLogRow: View {
    let item: CodexLogItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow

            if isExpanded {
                detailPanel
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 22) {
            Text(CodexLogFormat.dateText(item.createdAt))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .frame(width: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.model ?? "--")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(item.reasoning ?? "--")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(CodexLogFormat.tokenText(item.totalTokens))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(CodexLogFormat.tokenSummary(for: item))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(CodexLogFormat.costText(item.totalCost))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(CodexLogFormat.costSummary(for: item))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: 260, alignment: .leading)

            Button(action: onToggle) {
                Text(isExpanded ? "收起" : "明细")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
    }

    private var detailPanel: some View {
        HStack(alignment: .top, spacing: 24) {
            CodexLogDetailSection(
                title: "Tokens",
                rows: [
                    CodexLogDetailRowData(title: "总计", value: CodexLogFormat.tokenText(item.totalTokens)),
                    CodexLogDetailRowData(title: "输入", value: CodexLogFormat.billableInputTokens(for: item)),
                    CodexLogDetailRowData(title: "缓存", value: CodexLogFormat.tokenText(item.inputTokensCached)),
                    CodexLogDetailRowData(title: "输出", value: CodexLogFormat.outputDetailText(for: item)),
                ]
            )

            CodexLogDetailSection(
                title: "费用",
                rows: [
                    CodexLogDetailRowData(title: "总计", value: CodexLogFormat.costText(item.totalCost)),
                    CodexLogDetailRowData(title: "输入", value: CodexLogFormat.costText(item.inputCost)),
                    CodexLogDetailRowData(title: "缓存", value: CodexLogFormat.cacheCost(for: item)),
                    CodexLogDetailRowData(title: "输出", value: CodexLogFormat.costText(item.outputCost)),
                ]
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
    }
}

private struct CodexLogDetailRowData: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

private struct CodexLogDetailSection: View {
    let title: String
    let rows: [CodexLogDetailRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .leading)

                    Spacer(minLength: 8)

                    Text(row.value)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum SummaryStatusTone: Equatable {
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
    let currentSourceTitle: String
    let statisticsDisplayMode: StatisticsDisplayMode
    let statisticsModeText: String
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
    let codexAPIKeyStatusText: String
    let agiAPIKeyStatusText: String
    let pollIntervalText: String
    let displayStyle: StatusDisplayStyle
    let panelMode: MenuPanelMode
    let mcpStatusText: String
    let canOpenDashboard: Bool
    let canOpenPricing: Bool
    let dashboardActionTitle: String
    let sourceGroups: [SourceSummaryGroupViewModel]
}

private struct SummaryPackageItem {
    let title: String
    let subtitle: String
    let badgeText: String
    let badgeTone: SummaryStatusTone
}

private struct SourceSummaryGroupViewModel {
    let source: PackageSource
    let statusText: String
    let statusTone: SummaryStatusTone
    let usageLabel: String
    let usageValue: String
    let remainingValue: String
    let renewalLabel: String
    let renewalValue: String
    let packageItems: [SummaryPackageItem]
    let progressLabel: String
    let progressPrefix: String?
    let progressValue: String
    let progress: Double?
    let footerText: String
    let isExpanded: Bool
}

private struct WeightedMetricRowLayout: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    init(weights: [CGFloat], spacing: CGFloat = 8) {
        self.weights = weights
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = resolvedWidth(for: proposal, subviews: subviews)
        let widths = distributedWidths(for: availableWidth, count: subviews.count)
        let maxHeight = subviews.enumerated().reduce(CGFloat.zero) { current, pair in
            let (index, subview) = pair
            let size = subview.sizeThatFits(
                ProposedViewSize(width: widths[index], height: proposal.height)
            )
            return max(current, size.height)
        }
        return CGSize(width: availableWidth, height: maxHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let widths = distributedWidths(for: bounds.width, count: subviews.count)
        var currentX = bounds.minX

        for (index, subview) in subviews.enumerated() {
            let width = widths[index]
            subview.place(
                at: CGPoint(x: currentX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            currentX += width + spacing
        }
    }

    private func resolvedWidth(for proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width {
            return width
        }

        let intrinsicWidth = subviews.reduce(CGFloat.zero) { current, subview in
            current + subview.sizeThatFits(.unspecified).width
        }
        let totalSpacing = spacing * CGFloat(max(subviews.count - 1, 0))
        return intrinsicWidth + totalSpacing
    }

    private func distributedWidths(for totalWidth: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }

        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
        let contentWidth = max(0, totalWidth - totalSpacing)
        let activeWeights = Array(weights.prefix(count))
        let weightSum = max(activeWeights.reduce(CGFloat.zero, +), 1)

        return activeWeights.map { contentWidth * ($0 / weightSum) }
    }
}

private struct NormalizedMonitorPayload {
    let usage: String
    let remaining: String
    let renewal: String?
    let packageItems: [SummaryPackageItem]
    let usedPercent: Double?
    let usageLabel: String
    let progressLabel: String
    let progressPrefix: String?
    let email: String?
}

private struct SourceMonitorState {
    let source: PackageSource
    var usage: String
    var remaining: String
    var renewal: String
    var message: String
    var usageLabel: String
    var progressLabel: String
    var progressPrefix: String?
    var email: String?
    var packageItems: [SummaryPackageItem]
    var usedPercent: Double?
    var fallbackText: String

    static func placeholder(for source: PackageSource, hasAPIKey: Bool) -> SourceMonitorState {
        SourceMonitorState(
            source: source,
            usage: "--",
            remaining: "--",
            renewal: "--",
            message: hasAPIKey ? "等待数据" : "请先设置\(source.settingsTitle) API Key",
            usageLabel: source == .agi ? "已用" : "已用/总",
            progressLabel: source == .agi ? "总用量进度" : "用量进度",
            progressPrefix: nil,
            email: nil,
            packageItems: [],
            usedPercent: nil,
            fallbackText: hasAPIKey ? "\(source.chipTitle): 加载中..." : "\(source.chipTitle): 未配置Key"
        )
    }
}

private extension SummaryStatusTone {
    var swiftUIColor: Color { Color(nsColor: textColor) }
    var swiftUIFillColor: Color { Color(nsColor: fillColor) }
    var swiftUIBorderColor: Color { Color(nsColor: borderColor) }
}

private extension StatusSummaryViewModel {
    static let placeholder = StatusSummaryViewModel(
        title: AppMeta.displayName,
        currentSourceTitle: PackageSource.codex.chipTitle,
        statisticsDisplayMode: .single,
        statisticsModeText: StatisticsDisplayMode.single.fullTitle,
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
        codexAPIKeyStatusText: "未配置",
        agiAPIKeyStatusText: "未配置",
        pollIntervalText: "--",
        displayStyle: .remaining,
        panelMode: .statistics,
        mcpStatusText: "MCP 未启动",
        canOpenDashboard: true,
        canOpenPricing: true,
        dashboardActionTitle: PackageSource.codex.openDashboardTitle,
        sourceGroups: []
    )
}

private extension View {
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        #if compiler(>=6.2)
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
        #else
        self
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(.quaternary, lineWidth: 0.8)
            }
        #endif
    }

    @ViewBuilder
    func compactSurface(cornerRadius: CGFloat, tint: Color = .clear) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
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
        #else
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
        #endif
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

private struct SourceSummaryGroupView: View {
    let model: SourceSummaryGroupViewModel
    let onToggle: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { onToggle?() }) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: model.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Text(model.source.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text("余: \(model.remainingValue)")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(model.statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.statusTone.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(model.statusTone.swiftUIFillColor)
                        .overlay {
                            Capsule().stroke(model.statusTone.swiftUIBorderColor, lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(model.footerText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if model.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    WeightedMetricRowLayout(weights: [3, 3, 4], spacing: 8) {
                        metricCard(title: "剩余", value: model.remainingValue)
                        metricCard(title: model.usageLabel, value: model.usageValue)
                        metricCard(title: model.renewalLabel, value: model.renewalValue, lineLimit: 2)
                    }

                    if !model.packageItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("套餐")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ForEach(Array(model.packageItems.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Text(item.subtitle)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    Spacer(minLength: 6)

                                    Text(item.badgeText)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(item.badgeTone.swiftUIColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(item.badgeTone.swiftUIFillColor)
                                        .overlay {
                                            Capsule().stroke(item.badgeTone.swiftUIBorderColor, lineWidth: 0.8)
                                        }
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentMaterialSurface(cornerRadius: 13)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(model.progressLabel)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 8)

                            if let progressPrefix = model.progressPrefix {
                                Text(progressPrefix)
                                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }

                            Text(model.progressValue)
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentMaterialSurface(cornerRadius: 13)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 16)
    }

    private func metricCard(title: String, value: String, lineLimit: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .contentMaterialSurface(cornerRadius: 13)
    }
}

private struct LiquidGlassSummaryPanel: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSelectStatisticsMode: (() -> Void)?
    let onSelectSource: (() -> Void)?
    let onSetCodexAPIKey: (() -> Void)?
    let onSetAGIAPIKey: (() -> Void)?
    let onSetInterval: (() -> Void)?
    let onOpenLogs: (() -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onToggleSourceGroup: ((PackageSource) -> Void)?
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
            if model.statisticsDisplayMode == .dual {
                dualContentPanel
            } else {
                metaRow
                contentPanel
            }
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

            Text(model.statisticsModeText)
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

    private var dualContentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(model.sourceGroups.enumerated()), id: \.element.source.rawValue) { _, group in
                SourceSummaryGroupView(model: group) {
                    onToggleSourceGroup?(group.source)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Text(model.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if model.statisticsDisplayMode == .single {
                    Text(model.currentSourceTitle)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

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
        model.panelMode == .settings
            || model.statisticsDisplayMode == .dual
            || !model.canToggleEmail
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Text(model.footerText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            if model.statisticsDisplayMode == .single, model.canToggleEmail {
                #if compiler(>=6.2)
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 6) {
                        emailControls
                    }
                } else {
                    emailControls
                }
                #else
                emailControls
                #endif
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                settingsControls
            }
            .padding(.top, 2)
        } else {
            settingsControls
                .padding(.top, 2)
        }
        #else
        settingsControls
            .padding(.top, 2)
        #endif
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.bottom, 2)

            MenuActionButton(
                title: "统计模式",
                subtitle: model.statisticsModeText,
                systemImage: "square.split.2x1",
                shortcut: nil,
                prominent: false,
                action: onSelectStatisticsMode,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "单显套餐源",
                subtitle: model.currentSourceTitle,
                systemImage: "square.stack.3d.up",
                shortcut: nil,
                prominent: false,
                action: onSelectSource,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: PackageSource.codex.keyButtonTitle,
                subtitle: model.codexAPIKeyStatusText,
                systemImage: "key.horizontal",
                shortcut: "⌘K",
                prominent: false,
                action: onSetCodexAPIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: PackageSource.agi.keyButtonTitle,
                subtitle: model.agiAPIKeyStatusText,
                systemImage: "key.horizontal",
                shortcut: nil,
                prominent: false,
                action: onSetAGIAPIKey,
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
                title: "Log",
                subtitle: "查看 Codex 日志",
                systemImage: "doc.text.magnifyingglass",
                shortcut: nil,
                prominent: false,
                action: onOpenLogs,
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

            if model.canOpenDashboard {
                MenuActionButton(
                    title: model.dashboardActionTitle,
                    subtitle: nil,
                    systemImage: "safari",
                    shortcut: "⌘D",
                    prominent: false,
                    action: onOpenDashboard,
                    useInfoCardBackground: true
                )
            }

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

                if model.canOpenPricing {
                    Button(action: { onOpenPricing?() }) {
                        Text("去续费")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(model.renewalValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(2)
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
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect()
                .glassEffectID(id, in: glassNamespace)
        } else {
            content
                .liquidGlassCapsule()
        }
        #else
        content
            .liquidGlassCapsule()
        #endif
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
    var onSelectStatisticsMode: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSelectSource: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetCodexAPIKey: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetAGIAPIKey: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onSetInterval: (() -> Void)? {
        didSet { updateRootView() }
    }
    var onOpenLogs: (() -> Void)? {
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
    var onToggleSourceGroup: ((PackageSource) -> Void)? {
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
                onSelectStatisticsMode: nil,
                onSelectSource: nil,
                onSetCodexAPIKey: nil,
                onSetAGIAPIKey: nil,
                onSetInterval: nil,
                onOpenLogs: nil,
                onOpenDashboard: nil,
                onOpenPricing: nil,
                onSelectDisplayStyle: nil,
                onToggleSourceGroup: nil,
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
            onSelectStatisticsMode: onSelectStatisticsMode,
            onSelectSource: onSelectSource,
            onSetCodexAPIKey: onSetCodexAPIKey,
            onSetAGIAPIKey: onSetAGIAPIKey,
            onSetInterval: onSetInterval,
            onOpenLogs: onOpenLogs,
            onOpenDashboard: onOpenDashboard,
            onOpenPricing: onOpenPricing,
            onSelectDisplayStyle: onSelectDisplayStyle,
            onToggleSourceGroup: onToggleSourceGroup,
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
    let currentSource: String
    let dashboardURL: String?
    let pricingURL: String?
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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, @unchecked Sendable {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let mcpSnapshotStore = MCPSnapshotStore()

    private let menu = NSMenu()
    private let summaryMenuItem = NSMenuItem()
    private let summaryView = StatusSummaryView(frame: NSRect(x: 0, y: 0, width: StatusSummaryView.preferredWidth, height: 246))
    private var logWindowController: NSWindowController?
    private var logWindowAPIKey: String?

    private var timer: Timer?
    private var currentSource: PackageSource = .codex
    private var statisticsDisplayMode: StatisticsDisplayMode = .single
    private var codexAPIKey: String = ""
    private var codexAPIKeyOrigin: APIKeyOrigin = .none
    private var agiAPIKey: String = ""
    private var agiAPIKeyOrigin: APIKeyOrigin = .none
    private var pollInterval: TimeInterval = 5
    private var displayStyle: StatusDisplayStyle = .remaining
    private var panelMode: MenuPanelMode = .statistics
    private var sourceStates: [PackageSource: SourceMonitorState] = [:]
    private var sourceGroupExpanded: [PackageSource: Bool] = [
        .codex: true,
        .agi: true,
    ]
    private var mcpEnabled = true
    private var mcpPort: UInt16 = AppMeta.defaultMCPPort
    private lazy var mcpServer = MCPHTTPServer(port: mcpPort) { [weak self] in
        guard let self else { return Data("{}".utf8) }
        return self.mcpSnapshotStore.get()
    }
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
        currentSource = PackageSource(rawValue: defaults.string(forKey: DefaultsKey.selectedSource) ?? "") ?? .codex
        statisticsDisplayMode = StatisticsDisplayMode(rawValue: defaults.integer(forKey: DefaultsKey.statisticsDisplayMode)) ?? .single

        let codexResolution = resolveAPIKey(for: .codex, defaults: defaults)
        codexAPIKey = codexResolution.value
        codexAPIKeyOrigin = codexResolution.origin

        let agiResolution = resolveAPIKey(for: .agi, defaults: defaults)
        agiAPIKey = agiResolution.value
        agiAPIKeyOrigin = agiResolution.origin

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

        rebuildSourceStates()
    }

    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(codexAPIKey, forKey: DefaultsKey.apiKey)
        defaults.set(codexAPIKey, forKey: DefaultsKey.codexAPIKey)
        defaults.set(agiAPIKey, forKey: DefaultsKey.agiAPIKey)
        defaults.set(currentSource.rawValue, forKey: DefaultsKey.selectedSource)
        defaults.set(statisticsDisplayMode.rawValue, forKey: DefaultsKey.statisticsDisplayMode)
        defaults.set(pollInterval, forKey: DefaultsKey.interval)
        defaults.set(displayStyle.rawValue, forKey: DefaultsKey.displayStyle)
        defaults.set(mcpEnabled, forKey: DefaultsKey.mcpEnabled)
        defaults.set(Int(mcpPort), forKey: DefaultsKey.mcpPort)
    }

    private func setupStatusButton() {
        rebuildSourceStates()
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
        summaryView.onSelectStatisticsMode = { [weak self] in
            self?.performMenuAction {
                self?.handleSelectStatisticsMode()
            }
        }
        summaryView.onSelectSource = { [weak self] in
            self?.performMenuAction {
                self?.handleSelectSource()
            }
        }
        summaryView.onSetCodexAPIKey = { [weak self] in
            self?.performMenuAction {
                self?.handleSetAPIKey(for: .codex)
            }
        }
        summaryView.onSetAGIAPIKey = { [weak self] in
            self?.performMenuAction {
                self?.handleSetAPIKey(for: .agi)
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
        summaryView.onToggleSourceGroup = { [weak self] source in
            self?.toggleSourceGroup(source)
        }
        summaryView.onConfigureMCP = { [weak self] in
            self?.performMenuAction {
                self?.handleConfigureMCP()
            }
        }
        summaryView.onOpenLogs = { [weak self] in
            self?.performMenuAction {
                self?.handleOpenLogs()
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

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let logWindow = logWindowController?.window,
              window === logWindow else {
            return
        }
        logWindowController = nil
        logWindowAPIKey = nil
    }

    private func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: pollInterval, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
    }

    @objc private func handleTimerTick() {
        refreshNow()
    }

    private func handleToggleEmailVisibility() {
        guard state(for: currentSource).email?.isEmpty == false else { return }
        isEmailVisible.toggle()
        renderSummaryView()
    }

    private func handleSelectStatisticsMode() {
        let alert = NSAlert()
        alert.messageText = "选择统计模式"
        alert.informativeText = "单显显示当前套餐源；双显会同时显示 Codex 和 AGI 两组统计，状态栏默认优先显示 Codex。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let selector = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        StatisticsDisplayMode.allCases.forEach { mode in
            selector.addItem(withTitle: mode.fullTitle)
        }
        selector.selectItem(at: StatisticsDisplayMode.allCases.firstIndex(of: statisticsDisplayMode) ?? 0)
        alert.accessoryView = selector

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        statisticsDisplayMode = StatisticsDisplayMode.allCases[selector.indexOfSelectedItem]
        saveConfiguration()
        renderSummaryView()
        renderStatusBar()
        refreshNow()
    }

    private func handleSelectSource() {
        let alert = NSAlert()
        alert.messageText = "选择单显套餐源"
        alert.informativeText = "单显模式下的统计面板会跟随当前选择的数据源；双显模式下仍会同时展示 Codex 和 AGI。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let selector = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28), pullsDown: false)
        PackageSource.allCases.forEach { source in
            selector.addItem(withTitle: source.title)
        }
        selector.selectItem(at: PackageSource.allCases.firstIndex(of: currentSource) ?? 0)
        alert.accessoryView = selector

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        currentSource = PackageSource.allCases[selector.indexOfSelectedItem]
        isEmailVisible = false
        saveConfiguration()
        setupStatusButton()
        refreshNow()
    }

    private func handleSetAPIKey(for source: PackageSource) {
        let alert = NSAlert()
        alert.messageText = source.apiKeyDialogTitle
        alert.informativeText = source.apiKeyDialogHint
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = apiKeyValue(for: source)
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        setAPIKey(token, for: source)
        saveConfiguration()
        if source == currentSource || statisticsDisplayMode == .dual {
            setupStatusButton()
            refreshNow()
        } else {
            renderSummaryView()
        }
    }

    private func apiKeyValue(for source: PackageSource) -> String {
        switch source {
        case .codex:
            return codexAPIKey
        case .agi:
            return agiAPIKey
        }
    }

    private func apiKeyOrigin(for source: PackageSource) -> APIKeyOrigin {
        switch source {
        case .codex:
            return codexAPIKeyOrigin
        case .agi:
            return agiAPIKeyOrigin
        }
    }

    private func setAPIKey(_ value: String, for source: PackageSource) {
        let normalized = Self.normalizeAPIKey(value)
        switch source {
        case .codex:
            codexAPIKey = normalized
            codexAPIKeyOrigin = .userDefaults
        case .agi:
            agiAPIKey = normalized
            agiAPIKeyOrigin = .userDefaults
        }
    }

    private func apiKeyStatusText(for source: PackageSource) -> String {
        let token = apiKeyValue(for: source)
        guard !token.isEmpty else { return "未配置" }
        switch apiKeyOrigin(for: source) {
        case .userDefaults:
            return "已配置"
        case .environment:
            return "环境变量"
        case .none:
            return "未配置"
        }
    }

    private func resolveAPIKey(for source: PackageSource, defaults: UserDefaults) -> APIKeyResolution {
        if let stored = defaults.object(forKey: source.apiKeyDefaultsKey) as? String {
            let normalized = Self.normalizeAPIKey(stored)
            if !normalized.isEmpty {
                return APIKeyResolution(value: normalized, origin: .userDefaults)
            }
        }
        if let legacyKey = source.legacyDefaultsKey,
           let stored = defaults.object(forKey: legacyKey) as? String {
            let normalized = Self.normalizeAPIKey(stored)
            if !normalized.isEmpty {
                return APIKeyResolution(value: normalized, origin: .userDefaults)
            }
        }

        let environment = ProcessInfo.processInfo.environment
        if let value = source.environmentVariableCandidates.lazy
            .compactMap({ environment[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .map(Self.normalizeAPIKey)
            .first(where: { !$0.isEmpty }) {
            return APIKeyResolution(value: value, origin: .environment)
        }
        return APIKeyResolution(value: "", origin: .none)
    }

    nonisolated private static func normalizeAPIKey(_ rawValue: String) -> String {
        let components = rawValue
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !components.isEmpty else { return "" }

        if components[0].lowercased() == "bearer" {
            return components.dropFirst().first ?? ""
        }

        return components[0]
    }

    private func rebuildSourceStates() {
        for source in PackageSource.allCases {
            let hasAPIKey = !apiKeyValue(for: source).isEmpty
            let existing = sourceStates[source]
            if let existing, existing.remaining != "--" {
                continue
            }
            sourceStates[source] = .placeholder(for: source, hasAPIKey: hasAPIKey)
        }
    }

    private func state(for source: PackageSource) -> SourceMonitorState {
        sourceStates[source] ?? .placeholder(for: source, hasAPIKey: !apiKeyValue(for: source).isEmpty)
    }

    private func setState(_ state: SourceMonitorState, for source: PackageSource) {
        sourceStates[source] = state
    }

    private func updateSourceState(source: PackageSource, payload: NormalizedMonitorPayload, message: String) {
        var state = state(for: source)
        state.usage = payload.usage
        state.remaining = payload.remaining
        state.renewal = payload.renewal ?? "--"
        state.message = message
        state.usageLabel = payload.usageLabel
        state.progressLabel = payload.progressLabel
        state.progressPrefix = payload.progressPrefix
        state.email = payload.email
        state.packageItems = payload.packageItems
        state.usedPercent = payload.usedPercent
        state.fallbackText = "余: \(payload.remaining)"
        setState(state, for: source)
    }

    private func updateSourceFailure(source: PackageSource, fallbackText: String, message: String) {
        var state = state(for: source)
        state.usage = "--"
        state.remaining = "--"
        state.renewal = "--"
        state.message = message
        state.usageLabel = source == .agi ? "已用" : "已用/总"
        state.progressLabel = source == .agi ? "总用量进度" : "用量进度"
        state.progressPrefix = nil
        state.packageItems = []
        state.usedPercent = nil
        state.email = nil
        state.fallbackText = fallbackText
        setState(state, for: source)
    }

    private func toggleSourceGroup(_ source: PackageSource) {
        sourceGroupExpanded[source] = !(sourceGroupExpanded[source] ?? true)
        renderSummaryView()
    }

    private func primaryStatusSource() -> PackageSource {
        if statisticsDisplayMode == .dual {
            let codex = state(for: .codex)
            if codex.remaining != "--" || !apiKeyValue(for: .codex).isEmpty {
                return .codex
            }
            let agi = state(for: .agi)
            if agi.remaining != "--" || !apiKeyValue(for: .agi).isEmpty {
                return .agi
            }
            return .codex
        }
        return currentSource
    }

    private func summaryStatus(for source: PackageSource) -> (String, SummaryStatusTone) {
        let sourceState = state(for: source)
        if sourceState.remaining != "--" {
            return ("在线", .success)
        }
        if sourceState.fallbackText.contains("未配置") || sourceState.message.contains("请先设置") {
            return ("未配置", .warning)
        }
        if sourceState.fallbackText.contains("加载中") {
            return ("加载中", .neutral)
        }
        if sourceState.fallbackText.contains("请求失败")
            || sourceState.fallbackText.contains("授权错误")
            || sourceState.fallbackText.contains("HTTP")
            || sourceState.fallbackText.contains("解析失败")
            || sourceState.fallbackText.contains("业务错误")
            || sourceState.fallbackText.contains("响应异常") {
            return ("异常", .critical)
        }
        return ("等待中", .neutral)
    }

    private func aggregateSummaryStatus() -> (String, SummaryStatusTone) {
        let statuses = PackageSource.allCases.map(summaryStatus(for:))
        if statuses.contains(where: { $0.1 == .success }) {
            return ("在线", .success)
        }
        if statuses.allSatisfy({ $0.1 == .warning }) {
            return ("未配置", .warning)
        }
        if statuses.contains(where: { $0.1 == .critical }) {
            return ("异常", .critical)
        }
        if statuses.contains(where: { $0.1 == .neutral }) {
            return ("加载中", .neutral)
        }
        return ("等待中", .neutral)
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
        guard let rawURL = currentSource.dashboardURL,
              let url = URL(string: rawURL) else {
            showError("控制台链接无效")
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func handleOpenLogs() {
        guard !codexAPIKey.isEmpty else {
            showError("请先设置 Codex API Key")
            return
        }

        if let controller = logWindowController, logWindowAPIKey == codexAPIKey {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        logWindowController?.close()
        logWindowController = nil
        logWindowAPIKey = nil

        let hostingView = NSHostingView(rootView: CodexLogWindowView(apiKey: codexAPIKey))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Log"
        window.contentView = hostingView
        window.minSize = NSSize(width: 960, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        logWindowController = controller
        logWindowAPIKey = codexAPIKey
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        guard let rawURL = currentSource.pricingURL,
              let url = URL(string: rawURL) else {
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
        let primarySource = primaryStatusSource()
        let primaryState = state(for: primarySource)
        let overallStatus = statisticsDisplayMode == .dual ? aggregateSummaryStatus() : summaryStatus(for: primarySource)
        let snapshot = MCPServerSnapshot(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            displayName: AppMeta.displayName,
            currentSource: statisticsDisplayMode == .dual ? statisticsDisplayMode.title : currentSource.chipTitle,
            dashboardURL: primarySource.dashboardURL,
            pricingURL: primarySource.pricingURL,
            statusText: overallStatus.0,
            latestMessage: primaryState.message,
            remaining: primaryState.remaining,
            usage: primaryState.usage,
            renewal: primaryState.renewal,
            progressLabel: primaryState.progressLabel,
            progressPrefix: primaryState.progressPrefix,
            usedPercent: primaryState.usedPercent,
            email: primaryState.email,
            hasAPIKey: !apiKeyValue(for: primarySource).isEmpty,
            pollIntervalSeconds: pollInterval,
            displayStyle: displayStyle.title,
            packageItems: primaryState.packageItems.map {
                MCPPackageItem(title: $0.title, subtitle: $0.subtitle, badgeText: $0.badgeText)
            }
        )
        return (try? JSONEncoder().encode(snapshot)) ?? Data("{}".utf8)
    }

    private func refreshNow() {
        rebuildSourceStates()
        renderSummaryView()
        renderStatusBar()
        PackageSource.allCases.forEach(refreshSource)
    }

    private func refreshSource(_ source: PackageSource) {
        let apiKey = apiKeyValue(for: source)

        guard !apiKey.isEmpty else {
            updateSourceFailure(
                source: source,
                fallbackText: "\(source.chipTitle): 未配置Key",
                message: "请先设置\(source.settingsTitle) API Key"
            )
            renderSummaryView()
            renderStatusBar()
            return
        }

        var request = URLRequest(url: source.endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.updateSourceFailure(
                        source: source,
                        fallbackText: "\(source.chipTitle): 请求失败",
                        message: "网络错误: \(error.localizedDescription)"
                    )
                    self.renderSummaryView()
                    self.renderStatusBar()
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.updateSourceFailure(
                        source: source,
                        fallbackText: "\(source.chipTitle): 响应异常",
                        message: "无效响应"
                    )
                    self.renderSummaryView()
                    self.renderStatusBar()
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data else {
                DispatchQueue.main.async {
                    self.updateSourceFailure(
                        source: source,
                        fallbackText: "\(source.chipTitle): HTTP \(httpResponse.statusCode)",
                        message: "接口返回 HTTP \(httpResponse.statusCode)"
                    )
                    self.renderSummaryView()
                    self.renderStatusBar()
                }
                return
            }

            do {
                let payload = try Self.parsePayload(from: data, source: source)
                let now = Date()

                DispatchQueue.main.async {
                    self.updateSourceState(
                        source: source,
                        payload: payload,
                        message: "更新时间: \(Self.timeFormatter.string(from: now))"
                    )
                    self.renderSummaryView()
                    self.renderStatusBar()
                }
            } catch {
                let rawSnippet = String(data: data, encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(120) ?? "无法读取响应内容"
                DispatchQueue.main.async {
                    self.updateSourceFailure(
                        source: source,
                        fallbackText: "\(source.chipTitle): 解析失败",
                        message: "解析错误: \(error.localizedDescription) | \(rawSnippet)"
                    )
                    self.renderSummaryView()
                    self.renderStatusBar()
                }
            }
        }.resume()
    }

    nonisolated private static func parsePayload(from data: Data, source: PackageSource) throws -> NormalizedMonitorPayload {
        switch source {
        case .codex:
            return try parseCodexPayload(from: data)
        case .agi:
            return try parseAGIPayload(from: data)
        }
    }

    nonisolated private static func parseCodexPayload(from data: Data) throws -> NormalizedMonitorPayload {
        let decoded = try JSONDecoder().decode(APIEnvelope.self, from: data)
        if let code = decoded.code, code != 200 {
            let apiMessage = decoded.msg ?? decoded.error ?? decoded.details ?? "接口返回业务错误"
            throw makeParseError("错误码 \(code): \(apiMessage)")
        }

        if let errorText = decoded.error {
            throw makeParseError(decoded.details ?? decoded.msg ?? errorText)
        }

        guard let state = decoded.state else {
            throw makeParseError(decoded.msg ?? decoded.details ?? "响应里缺少 state 字段")
        }

        let packageUsagePayload = state.userPackgeUsage
        let weeklyUsagePayload = state.userPackgeUsageWeek
        let displayUsagePayload = weeklyUsagePayload ?? packageUsagePayload

        guard let remainingNumber = packageUsagePayload?.remainingQuota ?? state.remainingQuota ?? displayUsagePayload?.remainingQuota else {
            throw makeParseError("缺少 remaining_quota 字段")
        }

        let usageRemainingNumber = displayUsagePayload?.remainingQuota ?? remainingNumber
        let packageRemainingNumber = packageUsagePayload?.remainingQuota ?? remainingNumber
        let usedPercent = resolveUsedPercentage(usage: displayUsagePayload, remaining: usageRemainingNumber)
        let usageQuotaPair = resolveUsageQuotaPair(usage: displayUsagePayload, remaining: usageRemainingNumber)
        let dailyUsagePair = resolveUsageQuotaPair(usage: packageUsagePayload, remaining: packageRemainingNumber)

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

        return NormalizedMonitorPayload(
            usage: usage,
            remaining: remainingNumber.display,
            renewal: resolveRenewalText(package: state.package),
            packageItems: buildPackageSummaryItems(package: state.package),
            usedPercent: usedPercent,
            usageLabel: "已用/总",
            progressLabel: weeklyUsagePayload == nil ? "用量进度" : "本周用量进度",
            progressPrefix: usageQuotaPair.map { "\($0.used)/\($0.total)" },
            email: state.user?.email
        )
    }

    nonisolated private static func parseAGIPayload(from data: Data) throws -> NormalizedMonitorPayload {
        let decoded = try JSONDecoder().decode(AGIAPIEnvelope.self, from: data)
        if let code = decoded.code, code != 200 {
            throw makeParseError("错误码 \(code): \(decoded.message ?? "接口返回业务错误")")
        }

        guard let payload = decoded.data else {
            throw makeParseError(decoded.message ?? "响应里缺少 data 字段")
        }

        let displayPackage = selectDisplayAGIPackage(from: payload.packages)
        let remainingNumber = payload.summary?.remainingByte ?? displayPackage?.byteRemaining
        guard let remainingNumber else {
            throw makeParseError("缺少 remaining_byte 字段")
        }

        let totalNumber = payload.summary?.totalByte ?? displayPackage?.byteTotal
        let usedNumber = payload.summary?.usedByte ?? displayPackage?.byteUsed

        let usedPercent = resolveUsedPercentage(total: totalNumber, used: usedNumber, remaining: remainingNumber)
        let usedValue = usedNumber?.doubleValue.map(formatQuotaValue)
        let usage: String
        if let usedValue {
            usage = usedValue
        } else if let usedPercent {
            usage = String(format: "%.2f%%", usedPercent)
        } else {
            usage = "--"
        }

        return NormalizedMonitorPayload(
            usage: usage,
            remaining: remainingNumber.display,
            renewal: resolveAGIRenewalText(summary: payload.summary, packages: payload.packages),
            packageItems: buildAGIPackageSummaryItems(packages: payload.packages, summary: payload.summary),
            usedPercent: usedPercent,
            usageLabel: "已用",
            progressLabel: "总用量进度",
            progressPrefix: nil,
            email: nil
        )
    }

    nonisolated private static func makeParseError(_ description: String) -> NSError {
        NSError(
            domain: "MonitorParse",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    private func renderSummaryView() {
        let activeSource = currentSource
        let activeState = state(for: activeSource)
        let activeStatus = summaryStatus(for: activeSource)
        let overallStatus = statisticsDisplayMode == .dual ? aggregateSummaryStatus() : activeStatus

        let progressValue: String
        if let usedPercent = activeState.usedPercent {
            progressValue = String(format: "%.2f%%", max(0, min(100, usedPercent)))
        } else {
            progressValue = "--"
        }

        let displayEmail: String
        if let email = activeState.email, !email.isEmpty {
            displayEmail = isEmailVisible ? email : "***"
        } else {
            displayEmail = "--"
        }

        let packageSectionTitle: String? = if activeState.packageItems.isEmpty {
            nil
        } else if activeState.packageItems.count == 1 {
            "当前\(activeSource.settingsTitle)套餐"
        } else {
            "\(activeSource.settingsTitle)有效套餐（\(activeState.packageItems.count)）"
        }

        let sourceGroups = PackageSource.allCases.map { source -> SourceSummaryGroupViewModel in
            let sourceState = state(for: source)
            let status = summaryStatus(for: source)
            let progressValue = sourceState.usedPercent.map {
                String(format: "%.2f%%", max(0, min(100, $0)))
            } ?? "--"

            return SourceSummaryGroupViewModel(
                source: source,
                statusText: status.0,
                statusTone: status.1,
                usageLabel: sourceState.usageLabel,
                usageValue: sourceState.usage,
                remainingValue: sourceState.remaining,
                renewalLabel: sourceState.packageItems.count > 1 ? "最近到期" : "下次续费",
                renewalValue: sourceState.renewal,
                packageItems: sourceState.packageItems,
                progressLabel: sourceState.progressLabel,
                progressPrefix: sourceState.progressPrefix,
                progressValue: progressValue,
                progress: sourceState.usedPercent.map { max(0, min(100, $0)) / 100 },
                footerText: sourceState.message,
                isExpanded: sourceGroupExpanded[source] ?? true
            )
        }

        summaryView.apply(
            StatusSummaryViewModel(
                title: AppMeta.displayName,
                currentSourceTitle: activeSource.chipTitle,
                statisticsDisplayMode: statisticsDisplayMode,
                statisticsModeText: statisticsDisplayMode.fullTitle,
                statusText: overallStatus.0,
                statusTone: overallStatus.1,
                emailText: displayEmail,
                canToggleEmail: activeState.email?.isEmpty == false,
                isEmailVisible: isEmailVisible,
                usageLabel: activeState.usageLabel,
                usageValue: activeState.usage,
                remainingValue: activeState.remaining,
                renewalLabel: activeState.packageItems.count > 1 ? "最近到期" : "下次续费",
                renewalValue: activeState.renewal,
                packageSectionTitle: packageSectionTitle,
                packageItems: activeState.packageItems,
                progressLabel: activeState.progressLabel,
                progressPrefix: activeState.progressPrefix,
                progressValue: progressValue,
                progress: activeState.usedPercent.map { max(0, min(100, $0)) / 100 },
                footerText: activeState.message,
                codexAPIKeyStatusText: apiKeyStatusText(for: .codex),
                agiAPIKeyStatusText: apiKeyStatusText(for: .agi),
                pollIntervalText: "\(Int(pollInterval)) 秒",
                displayStyle: displayStyle,
                panelMode: panelMode,
                mcpStatusText: currentMCPStatusText(),
                canOpenDashboard: activeSource.dashboardURL != nil,
                canOpenPricing: activeSource.pricingURL != nil,
                dashboardActionTitle: activeSource.openDashboardTitle,
                sourceGroups: sourceGroups
            )
        )
        summaryView.frame = NSRect(origin: .zero, size: summaryView.intrinsicContentSize)
        mcpSnapshotStore.set(makeMCPSnapshotData())
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

        let source = primaryStatusSource()
        let sourceState = state(for: source)

        // 当接口数据不可用时，优先展示错误/未配置等状态文案。
        guard sourceState.remaining != "--" else {
            applySingleLineTitle(sourceState.fallbackText)
            return
        }

        let clampedUsed = sourceState.usedPercent.map { max(0, min(100, $0)) }
        let remainingPercent = clampedUsed.map { max(0, 100 - $0) }

        switch displayStyle {
        case .remaining:
            applySingleLineTitle("余: \(sourceState.remaining)")
        case .usedPercent:
            if let clampedUsed {
                applySingleLineTitle(String(format: "用: %.2f%%", clampedUsed))
            } else {
                applySingleLineTitle("用: \(sourceState.usage)")
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
            applyCircleProgressWithRemaining(progress: clampedUsed.map { $0 / 100 }, remainingText: "余: \(sourceState.remaining)")
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

    nonisolated private static func resolveUsedPercentage(
        total: FlexibleNumber?,
        used: FlexibleNumber?,
        remaining: FlexibleNumber?
    ) -> Double? {
        guard let totalValue = total?.doubleValue, totalValue > 0 else {
            return nil
        }
        if let usedValue = used?.doubleValue {
            return max(0, min(100, (usedValue / totalValue) * 100))
        }
        if let remainingValue = remaining?.doubleValue {
            return max(0, min(100, (1 - (remainingValue / totalValue)) * 100))
        }
        return nil
    }

    nonisolated private static func resolveUsageQuotaPair(
        total: FlexibleNumber?,
        used: FlexibleNumber?,
        remaining: FlexibleNumber?
    ) -> (used: String, total: String)? {
        guard let totalValue = total?.doubleValue, totalValue > 0 else {
            return nil
        }

        let usedValue: Double?
        if let explicitUsed = used?.doubleValue {
            usedValue = explicitUsed
        } else if let remainingValue = remaining?.doubleValue {
            usedValue = max(0, totalValue - remainingValue)
        } else {
            usedValue = nil
        }

        guard let usedValue else { return nil }
        return (
            used: formatQuotaValue(usedValue),
            total: formatQuotaValue(totalValue)
        )
    }

    nonisolated private static func formatQuotaValue(_ value: Double) -> String {
        guard value.isFinite else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.005 {
            return "\(Int(rounded))"
        }
        return String(format: "%.2f", value)
    }

    nonisolated private static func resolveRenewalText(from dateString: String?) -> String? {
        guard let dateString,
              let expiresDate = parseAPIDate(dateString) else {
            return nil
        }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let renewalYear = calendar.component(.year, from: expiresDate)

        let absoluteFormatter = DateFormatter()
        absoluteFormatter.locale = Locale(identifier: "zh_CN")
        absoluteFormatter.timeZone = .current
        absoluteFormatter.dateFormat = renewalYear == currentYear ? "MM-dd" : "yyyy-MM-dd"

        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = Locale(identifier: "zh_CN")
        relativeFormatter.unitsStyle = .short

        let absolute = absoluteFormatter.string(from: expiresDate)
        let relative = relativeFormatter.localizedString(for: expiresDate, relativeTo: Date())
        return "\(absolute)（\(relative)）"
    }

    nonisolated private static func resolveRenewalText(package: PackagePayload?) -> String? {
        guard let package = selectDisplayPackage(from: package?.packages) else {
            return nil
        }
        return resolveRenewalText(from: package.expiresAt)
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
                subtitle: startText == "--"
                    ? "到期 \(expireText)"
                    : "开通 \(startText)\n到期 \(expireText)",
                badgeText: daysRemaining == 0 ? "今天到期" : "剩\(daysRemaining)天",
                badgeTone: badgeTone
            )
        }
    }

    nonisolated private static func resolveAGIRenewalText(summary: AGISummary?, packages: [AGIPackage]?) -> String? {
        resolveRenewalText(from: summary?.latestExpireTime ?? selectDisplayAGIPackage(from: packages)?.expireTime)
    }

    nonisolated private static func buildAGIPackageSummaryItems(
        packages: [AGIPackage]?,
        summary: AGISummary?
    ) -> [SummaryPackageItem] {
        activeAGIPackages(from: packages).map { item, expiresDate in
            let startText = parseAPIDate(item.createTime ?? "").map { compactDateFormatter.string(from: $0) } ?? "--"
            let expireText = compactDateFormatter.string(from: expiresDate)
            let explicitDays = item.day ?? -1
            let computedDays = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: expiresDate)
            ).day ?? 0
            let daysRemaining = max(0, explicitDays >= 0 ? explicitDays : computedDays)

            let badgeTone: SummaryStatusTone
            if daysRemaining <= 1 {
                badgeTone = .critical
            } else if daysRemaining <= 7 {
                badgeTone = .warning
            } else {
                badgeTone = .success
            }

            let subtitleParts = [
                startText == "--" ? nil : "开通 \(startText)",
                "到期 \(expireText)"
            ].compactMap { $0 }

            return SummaryPackageItem(
                title: normalizeAGIPackageTitle(item, summary: summary),
                subtitle: subtitleParts.joined(separator: "\n"),
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

    nonisolated private static func selectDisplayAGIPackage(from packages: [AGIPackage]?) -> AGIPackage? {
        let now = Date()
        let candidates = activeAGIPackages(from: packages)

        if let upcoming = candidates
            .filter({ $0.1 >= now })
            .min(by: { $0.1 < $1.1 }) {
            return upcoming.0
        }

        return candidates.max(by: { $0.1 < $1.1 })?.0
    }

    nonisolated private static func activeAGIPackages(from packages: [AGIPackage]?) -> [(AGIPackage, Date)] {
        guard let packages, !packages.isEmpty else { return [] }
        return packages.compactMap { item -> (AGIPackage, Date)? in
            guard let expireTime = item.expireTime,
                  let expireDate = parseAPIDate(expireTime) else {
                return nil
            }
            return (item, expireDate)
        }
        .sorted(by: { $0.1 < $1.1 })
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

    nonisolated private static func normalizeAGIPackageTitle(_ package: AGIPackage, summary: AGISummary?) -> String {
        let baseTitle = normalizePackageTitle(package.orderClass ?? summary?.userType ?? "AGI 套餐")
        if let level = package.level ?? summary?.highestLevel {
            return "\(baseTitle) Lv\(level)"
        }
        return baseTitle
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
