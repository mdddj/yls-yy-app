import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var feedURLString: String
    @Published private(set) var checkButtonSubtitle = "未配置更新源"
    @Published private(set) var feedButtonSubtitle = "未配置"
    @Published private(set) var publicKeyStatusText = "未注入"
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private var hasBootstrapped = false
    private var hasStartedUpdater = false
    private var lastCycleMessage: String?
    private var cancellables: Set<AnyCancellable> = []

    private lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
                self?.refreshUIState()
            }
            .store(in: &cancellables)

        return controller
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.feedURLString = defaults.string(forKey: DefaultsKey.updateFeedURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        super.init()
        refreshUIState()
    }

    var currentFeedURLValue: String {
        feedURLString
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        _ = updaterController
        startUpdaterIfPossible()
    }

    @discardableResult
    func saveFeedURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  url.host?.isEmpty == false
            else {
                errorMessage = "更新源必须是有效的 http(s) appcast 地址"
                return false
            }
        }

        feedURLString = trimmed
        defaults.set(trimmed, forKey: DefaultsKey.updateFeedURL)
        lastCycleMessage = nil

        if hasStartedUpdater {
            updaterController.updater.resetUpdateCycleAfterShortDelay()
        } else {
            startUpdaterIfPossible()
        }

        refreshUIState()
        return true
    }

    func checkForUpdates() {
        bootstrapIfNeeded()

        if let issue = configurationIssueText {
            errorMessage = issue
            refreshUIState()
            return
        }

        startUpdaterIfPossible()
        guard canCheckForUpdates else {
            errorMessage = "更新器尚未准备好，请稍后再试"
            refreshUIState()
            return
        }

        lastCycleMessage = "正在检查更新"
        refreshUIState()
        updaterController.checkForUpdates(nil)
    }

    func dismissError() {
        errorMessage = nil
    }

    private var bundleFeedURLString: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveFeedURLString: String {
        if !feedURLString.isEmpty {
            return feedURLString
        }
        return bundleFeedURLString
    }

    private var effectiveFeedURL: URL? {
        guard !effectiveFeedURLString.isEmpty else { return nil }
        return URL(string: effectiveFeedURLString)
    }

    private var sparklePublicKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasPublicKey: Bool {
        !sparklePublicKey.isEmpty
    }

    private var configurationIssueText: String? {
        if !hasPublicKey {
            return "缺少 Sparkle 公钥，请在构建设置里配置 SPARKLE_PUBLIC_ED_KEY 或 SUPublicEDKey"
        }
        guard effectiveFeedURL != nil else {
            return "请先配置更新源 Appcast 地址"
        }
        return nil
    }

    private func startUpdaterIfPossible() {
        guard !hasStartedUpdater else { return }
        guard configurationIssueText == nil else {
            refreshUIState()
            return
        }

        updaterController.startUpdater()
        hasStartedUpdater = true

        if lastCycleMessage == nil {
            lastCycleMessage = "自动检查已开启"
        }

        refreshUIState()
    }

    private func refreshUIState() {
        publicKeyStatusText = hasPublicKey ? "已注入" : "未注入"

        if let url = effectiveFeedURL {
            let host = url.host ?? url.absoluteString
            let path = url.path.isEmpty ? "" : url.path
            feedButtonSubtitle = "\(host)\(path)"
        } else {
            feedButtonSubtitle = "未配置"
        }

        if !hasPublicKey {
            checkButtonSubtitle = "缺少公钥"
            canCheckForUpdates = false
            return
        }

        guard effectiveFeedURL != nil else {
            checkButtonSubtitle = "未配置更新源"
            canCheckForUpdates = false
            return
        }

        if let lastCycleMessage, !lastCycleMessage.isEmpty {
            checkButtonSubtitle = lastCycleMessage
            return
        }

        if hasStartedUpdater {
            checkButtonSubtitle = canCheckForUpdates ? "已就绪" : "检查中"
        } else {
            checkButtonSubtitle = "待启动"
        }
    }
}

extension AppUpdater: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        effectiveFeedURLString.isEmpty ? nil : effectiveFeedURLString
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let displayVersion = item.displayVersionString.isEmpty ? item.versionString : item.displayVersionString
        lastCycleMessage = "发现新版本 \(displayVersion)"
        refreshUIState()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        lastCycleMessage = "当前已是最新版本"
        refreshUIState()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        lastCycleMessage = "检查失败"
        errorMessage = error.localizedDescription
        refreshUIState()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if error == nil, lastCycleMessage == "正在检查更新" {
            lastCycleMessage = "已完成检查"
        }
        refreshUIState()
    }
}
