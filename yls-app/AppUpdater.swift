import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var checkButtonSubtitle = "未配置更新源"
    @Published private(set) var hasAvailableUpdate = false
    @Published private(set) var availableUpdateVersion = ""

    private var hasBootstrapped = false
    private var hasStartedUpdater = false
    private var lastCycleMessage: String?
    private var cancellables: Set<AnyCancellable> = []

    private lazy var updaterController: SPUStandardUpdaterController = {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
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

    override init() {
        super.init()
        refreshUIState()
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        _ = updaterController
        startUpdaterIfPossible()
    }

    func checkForUpdates() {
        bootstrapIfNeeded()

        guard configurationIssueText == nil else {
            refreshUIState()
            return
        }

        startUpdaterIfPossible()
        guard canCheckForUpdates else {
            lastCycleMessage = "更新器未就绪"
            refreshUIState()
            return
        }

        lastCycleMessage = "检查中"
        refreshUIState()
        updaterController.updater.checkForUpdateInformation()
    }

    func openAvailableUpdate() {
        bootstrapIfNeeded()

        guard configurationIssueText == nil else {
            refreshUIState()
            return
        }

        startUpdaterIfPossible()
        updaterController.checkForUpdates(nil)
    }

    func dismissError() {
        // Updater no longer surfaces alert-based errors.
    }

    private var bundleFeedURLString: String {
        let injectedValue = (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !injectedValue.isEmpty {
            return injectedValue
        }
        return AppMeta.appcastURL.absoluteString
    }

    private var effectiveFeedURL: URL? {
        URL(string: bundleFeedURLString)
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
            lastCycleMessage = "自动检查开启"
        }

        refreshUIState()
    }

    private func refreshUIState() {
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
        bundleFeedURLString
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        markUpdateAvailable(item)
        refreshUIState()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        clearAvailableUpdate()
        lastCycleMessage = "已是最新"
        refreshUIState()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        lastCycleMessage = displayMessage(for: error)
        refreshUIState()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if error == nil, lastCycleMessage == "检查中" {
            lastCycleMessage = "检查完成"
        }
        refreshUIState()
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate updateItem: SUAppcastItem, state: SPUUserUpdateState) {
        switch choice {
        case .skip:
            clearAvailableUpdate()
            lastCycleMessage = "已忽略此版本"
        case .install:
            markUpdateAvailable(updateItem)
            lastCycleMessage = "准备升级"
        case .dismiss:
            markUpdateAvailable(updateItem)
            lastCycleMessage = "发现 \(availableUpdateVersion)"
        @unknown default:
            break
        }

        refreshUIState()
    }
}

extension AppUpdater: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate || !state.userInitiated {
            markUpdateAvailable(update)
            refreshUIState()
        }
    }
}

private extension AppUpdater {
    func markUpdateAvailable(_ item: SUAppcastItem) {
        let displayVersion = item.displayVersionString.isEmpty ? item.versionString : item.displayVersionString
        hasAvailableUpdate = true
        availableUpdateVersion = displayVersion
        lastCycleMessage = "发现 \(displayVersion)"
    }

    func clearAvailableUpdate() {
        hasAvailableUpdate = false
        availableUpdateVersion = ""
    }

    func displayMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == SUSparkleErrorDomain {
            switch nsError.code {
            case 1:
                return "缺少公钥"
            case 4:
                return "更新源无效"
            case 1000, 1002:
                return "更新源异常"
            case 2001:
                return "下载失败"
            case 3001, 3002:
                return "签名校验失败"
            default:
                break
            }
        }

        return "检查失败"
    }
}
