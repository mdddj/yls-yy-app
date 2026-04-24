import SwiftUI

private enum StatisticsGroupKind: String, CaseIterable, Hashable {
    case codex
    case agi
}

private struct StatisticsGroupAccessory {
    let text: String
    let tone: SummaryStatusTone?

    static func label(_ text: String) -> StatisticsGroupAccessory {
        StatisticsGroupAccessory(text: text, tone: nil)
    }

    static func status(_ text: String, tone: SummaryStatusTone) -> StatisticsGroupAccessory {
        StatisticsGroupAccessory(text: text, tone: tone)
    }
}

struct CodexMonitorMenuBarContent: View {
    @ObservedObject var store: CodexMonitorStore
    @ObservedObject var appUpdater: AppUpdater

    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        LiquidGlassSummaryPanel(
            model: store.summaryModel,
            onTogglePanelMode: store.togglePanelMode,
            onToggleEmail: store.toggleEmailVisibility,
            onRefresh: store.triggerRefresh,
            onSetAPIKey: { openConfigurationWindow(.apiKey) },
            onSetAGIKey: { openConfigurationWindow(.agiKey) },
            onSetInterval: { openConfigurationWindow(.interval) },
            onOpenDashboard: { openURL(AppMeta.dashboardURL) },
            onOpenPricing: { openURL(AppMeta.pricingURL) },
            onSelectDisplayStyle: store.selectDisplayStyle,
            onConfigureMCP: { openConfigurationWindow(.mcp) },
            updateCheckStatusText: appUpdater.checkButtonSubtitle,
            canCheckForUpdates: appUpdater.canCheckForUpdates,
            onCheckForUpdates: appUpdater.checkForUpdates,
            onQuit: store.quit
        )
        .alert(
            "配置错误",
            isPresented: Binding(
                get: { activeErrorMessage != nil },
                set: { if !$0 { dismissErrors() } }
            )
        ) {
            Button("知道了") {
                dismissErrors()
            }
        } message: {
            Text(activeErrorMessage ?? "")
        }
        .task {
            store.bootstrapIfNeeded()
            appUpdater.bootstrapIfNeeded()
        }
        .onDisappear {
            store.hideEmail()
        }
    }

    private var activeErrorMessage: String? {
        appUpdater.errorMessage ?? store.errorMessage
    }

    private func dismissErrors() {
        appUpdater.dismissError()
        store.dismissError()
    }

    private func openConfigurationWindow(_ kind: ConfigurationWindowKind) {
        openWindow(id: kind.id)
    }
}

extension View {
    @ViewBuilder
    func liquidGlassCapsule() -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                shape: Capsule(),
                tint: Color.white.opacity(0.10),
                shadowOpacity: 0.16
            )
        )
    }

    @ViewBuilder
    func compactSurface(cornerRadius: CGFloat, tint: Color = Color.white.opacity(0.10)) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                shadowOpacity: 0.16
            )
        )
    }

    @ViewBuilder
    func contentMaterialSurface(cornerRadius: CGFloat, tint: Color = Color.white.opacity(0.18)) -> some View {
        modifier(
            MaterialCardSurfaceModifier(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                material: .regularMaterial,
                tint: tint.opacity(0.98),
                shadowOpacity: 0.22
            )
        )
    }
}

private enum GlassPalette {
    static let secondaryText = Color.primary.opacity(0.84)
    static let tertiaryText = Color.primary.opacity(0.72)
    static let cardRestTint = Color.white.opacity(0.18)
    static let cardHoverTint = Color.white.opacity(0.26)
    static let chipRestTint = Color.white.opacity(0.12)
    static let chipHoverTint = Color.white.opacity(0.20)
    static let chipSelectedTint = Color.accentColor.opacity(0.22)
}

private struct LiquidGlassSurfaceModifier<SurfaceShape: InsettableShape>: ViewModifier {
    let shape: SurfaceShape
    let tint: Color
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    glassLayer
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                tint,
                                Color.white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                ZStack {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.50),
                                Color.white.opacity(0.20),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                    shape
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 4)
                        .blur(radius: 8)
                        .mask(shape)
                }
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 22, y: 10)
    }

    @ViewBuilder
    private var glassLayer: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: shape)
        } else {
            shape.fill(.thinMaterial)
        }
        #else
        shape.fill(.thinMaterial)
        #endif
    }
}

private struct MaterialCardSurfaceModifier<SurfaceShape: InsettableShape>: ViewModifier {
    let shape: SurfaceShape
    let material: Material
    let tint: Color
    let shadowOpacity: Double

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var baseOverlay: Color {
        if colorScheme == .dark {
            return Color.black.opacity(reduceTransparency ? 0.26 : 0.16)
        }
        return Color.white.opacity(reduceTransparency ? 0.46 : 0.32)
    }

    private var leadingHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.28)
    }

    private var trailingShade: Color {
        colorScheme == .dark ? Color.white.opacity(0.03) : Color.white.opacity(0.10)
    }

    private var borderTop: Color {
        colorScheme == .dark ? Color.white.opacity(0.20) : Color.white.opacity(0.62)
    }

    private var borderBottom: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.28)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(reduceTransparency ? .thickMaterial : material)
                    shape.fill(baseOverlay)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                leadingHighlight,
                                tint,
                                trailingShade,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            borderTop,
                            borderBottom,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, y: 9)
    }
}

private struct MenuActionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let shortcut: String?
    let prominent: Bool
    let isEnabled: Bool
    let action: (() -> Void)?
    let useInfoCardBackground: Bool

    @State private var isHovered = false

    init(
        title: String,
        subtitle: String?,
        systemImage: String,
        shortcut: String?,
        prominent: Bool,
        isEnabled: Bool = true,
        action: (() -> Void)?,
        useInfoCardBackground: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.prominent = prominent
        self.isEnabled = isEnabled
        self.action = action
        self.useInfoCardBackground = useInfoCardBackground
    }

    private var compactTint: Color {
        prominent
            ? (isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.12))
            : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
    }

    @ViewBuilder
    private func applySurface<Content: View>(to content: Content) -> some View {
        if useInfoCardBackground {
            content.contentMaterialSurface(
                cornerRadius: 15,
                tint: isHovered ? GlassPalette.cardHoverTint : GlassPalette.cardRestTint
            )
        } else {
            content.compactSurface(cornerRadius: 15, tint: compactTint)
        }
    }

    var body: some View {
        Button(action: { action?() }) {
            applySurface(
                to: HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(prominent ? .primary : Color.primary.opacity(0.88))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                        }

                    VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(GlassPalette.secondaryText)
                                .lineLimit(useInfoCardBackground ? 2 : 1)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    if let shortcut {
                        Text(shortcut)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassPalette.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.10))
                            .overlay {
                                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                            }
                            .clipShape(Capsule())
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, subtitle == nil ? 10 : 11)
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.60)
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
                .foregroundStyle(isSelected ? .primary : GlassPalette.secondaryText)

                Text(style.selectorPreview)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? GlassPalette.secondaryText : GlassPalette.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentMaterialSurface(
                cornerRadius: 13,
                tint: isSelected
                    ? GlassPalette.chipSelectedTint
                    : (isHovered ? GlassPalette.chipHoverTint : GlassPalette.chipRestTint)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct LiquidGlassSummaryPanel: View {
    let model: StatusSummaryViewModel
    let onTogglePanelMode: (() -> Void)?
    let onToggleEmail: (() -> Void)?
    let onRefresh: (() -> Void)?
    let onSetAPIKey: (() -> Void)?
    let onSetAGIKey: (() -> Void)?
    let onSetInterval: (() -> Void)?
    let onOpenDashboard: (() -> Void)?
    let onOpenPricing: (() -> Void)?
    let onSelectDisplayStyle: ((StatusDisplayStyle) -> Void)?
    let onConfigureMCP: (() -> Void)?
    let updateCheckStatusText: String
    let canCheckForUpdates: Bool
    let onCheckForUpdates: (() -> Void)?
    let onQuit: (() -> Void)?

    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedGroups: Set<StatisticsGroupKind> = Set(StatisticsGroupKind.allCases)

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
        .frame(width: AppMeta.preferredPanelWidth)
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
        .contentMaterialSurface(cornerRadius: 16, tint: Color.white.opacity(0.20))
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            statisticsGroup(
                kind: .codex,
                title: "Codex",
                systemImage: "cpu",
                accessory: .label("主套餐")
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    heroPanel
                    packageSection
                    progressSection
                }
            }

            if !model.mountedModules.isEmpty {
                let mountedModule = model.mountedModules[0]
                statisticsGroup(
                    kind: .agi,
                    title: "AGI",
                    systemImage: "shippingbox",
                    accessory: .status(mountedModule.statusText, tone: mountedModule.statusTone)
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        mountedModulesSection
                    }
                }
            }
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
                statusBadge(
                    text: model.statusText,
                    tone: model.statusTone,
                    action: isRefreshableStatus(model.statusTone) ? onRefresh : nil
                )

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
                        .background(Color.white.opacity(0.08))
                        .overlay {
                            Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                        }
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.packageItems) { item in
                        packageRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var mountedModulesSection: some View {
        if !model.mountedModules.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(model.mountedModules.enumerated()), id: \.element.id) { index, module in
                    mountedModuleContent(
                        module,
                        showsTitle: model.mountedModules.count > 1
                    )

                    if index < model.mountedModules.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                            .padding(.vertical, 4)
                    }
                }
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
                        .foregroundStyle(item.badgeTone.textColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.badgeTone.fillColor)
                        .overlay {
                            Capsule().stroke(item.badgeTone.borderColor, lineWidth: 0.8)
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

    private func mountedModuleContent(
        _ module: MountedPackageModuleSummary,
        showsTitle: Bool
    ) -> some View {
        let topMetricMinHeight: CGFloat = 78

        return VStack(alignment: .leading, spacing: 8) {
            if showsTitle {
                Text(module.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                compactMetric(
                    title: module.remainingLabel,
                    value: module.remainingValue,
                    alignment: .leading,
                    valueFontSize: 16,
                    valueMinimumScaleFactor: 0.68,
                    cardMinHeight: topMetricMinHeight
                )

                compactMetric(
                    title: module.usageLabel,
                    value: module.usageValue,
                    alignment: .leading,
                    valueFontSize: 11,
                    valueMinimumScaleFactor: 0.76,
                    cardMinHeight: topMetricMinHeight
                )
            }

            compactMetric(
                title: module.renewalLabel,
                value: module.renewalValue,
                alignment: .leading,
                valueFontSize: 11,
                valueMinimumScaleFactor: 0.76
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(module.progressLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(module.progressValue)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                GeometryReader { proxy in
                    let value = module.progress ?? 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.92), .accentColor.opacity(0.42)],
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

            if let packageSectionTitle = module.packageSectionTitle {
                VStack(alignment: .leading, spacing: 7) {
                    Text(packageSectionTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(module.packageItems) { item in
                            packageRow(item)
                        }
                    }
                }
            }

            Text(module.footerText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func statisticsGroup<Content: View>(
        kind: StatisticsGroupKind,
        title: String,
        systemImage: String,
        accessory: StatisticsGroupAccessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: { toggleStatisticsGroup(kind) }) {
                    HStack(spacing: 8) {
                        Label(title, systemImage: systemImage)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let tone = accessory.tone {
                    statusBadge(
                        text: accessory.text,
                        tone: tone,
                        action: isRefreshableStatus(tone) ? onRefresh : nil
                    )
                } else {
                    groupAccessoryChip(accessory.text)
                }

                Button(action: { toggleStatisticsGroup(kind) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(GlassPalette.secondaryText)
                        .rotationEffect(.degrees(isGroupExpanded(kind) ? 0 : -90))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isGroupExpanded(kind) {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 20, tint: Color.white.opacity(0.14))
    }

    private func groupAccessoryChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GlassPalette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.10))
            .overlay {
                Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            }
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func statusBadge(
        text: String,
        tone: SummaryStatusTone,
        action: (() -> Void)?
    ) -> some View {
        let badge = Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tone.textColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(tone.fillColor.opacity(0.85))
            .overlay {
                Capsule().stroke(tone.borderColor.opacity(0.9), lineWidth: 0.8)
            }
            .clipShape(Capsule())

        if let action {
            Button(action: action) {
                badge
            }
            .buttonStyle(.plain)
            .help("状态异常，点击立即刷新")
        } else {
            badge
        }
    }

    private func isRefreshableStatus(_ tone: SummaryStatusTone) -> Bool {
        tone == .critical
    }

    private func isGroupExpanded(_ kind: StatisticsGroupKind) -> Bool {
        expandedGroups.contains(kind)
    }

    private func toggleStatisticsGroup(_ kind: StatisticsGroupKind) {
        let toggle = {
            if expandedGroups.contains(kind) {
                expandedGroups.remove(kind)
            } else {
                expandedGroups.insert(kind)
            }
        }

        if reduceMotion {
            toggle()
            return
        }

        withAnimation(.spring(duration: 0.30, bounce: 0.18)) {
            toggle()
        }
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
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.92), .accentColor.opacity(0.42)],
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
        settingsControls
            .padding(.top, 2)
    }

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(height: 1)
                .padding(.bottom, 2)

            MenuActionButton(
                title: "Codex Key",
                subtitle: model.hasAPIKey ? "已配置" : "未配置",
                systemImage: "key.horizontal",
                shortcut: "⌘K",
                prominent: false,
                action: onSetAPIKey,
                useInfoCardBackground: true
            )

            MenuActionButton(
                title: "AGI Key",
                subtitle: model.hasAGIKey ? "已配置" : "未配置",
                systemImage: "shippingbox",
                shortcut: nil,
                prominent: false,
                action: onSetAGIKey,
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
                title: "检查更新",
                subtitle: updateCheckStatusText,
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                shortcut: nil,
                prominent: false,
                isEnabled: canCheckForUpdates,
                action: onCheckForUpdates,
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
                    .foregroundStyle(GlassPalette.secondaryText)

                Spacer(minLength: 6)

                Text(model.displayStyle.chipTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.26), lineWidth: 0.8)
                    }
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(StatusDisplayStyle.allCases) { style in
                    StyleChipButton(style: style, isSelected: style == model.displayStyle) {
                        applyDisplayStyle(style)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMaterialSurface(cornerRadius: 16, tint: Color.white.opacity(0.18))
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
        valueMinimumScaleFactor: CGFloat = 0.72,
        cardMinHeight: CGFloat = 0
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
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .leading)
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
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .glassEffect()
                .glassEffectID(id, in: glassNamespace)
        } else {
            content.liquidGlassCapsule()
        }
        #else
        content.liquidGlassCapsule()
        #endif
    }
}

struct StatusBarLabelView: View {
    let model: StatusBarPresentation

    var body: some View {
        Group {
            if model.remainingText == "--" {
                Text(model.fallbackText)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            } else {
                switch model.style {
                case .remaining:
                    singleLine("余: \(model.remainingText)")
                case .usedPercent:
                    if let used = model.clampedUsedPercent {
                        singleLine(String(format: "用: %.2f%%", used))
                    } else {
                        singleLine("用: \(model.usageText)")
                    }
                case .remainingPercent:
                    if let remaining = model.remainingPercent {
                        singleLine(String(format: "剩: %.2f%%", remaining))
                    } else {
                        singleLine("剩: --")
                    }
                case .stackedUsedPercent:
                    stackedLabel(
                        top: model.clampedUsedPercent.map { String(format: "%.2f%%", $0) } ?? "--",
                        bottom: "已使用"
                    )
                case .stackedRemainingPercent:
                    stackedLabel(
                        top: model.remainingPercent.map { String(format: "%.2f%%", $0) } ?? "--",
                        bottom: "剩余"
                    )
                case .circleProgress:
                    circleProgressLabel(
                        progress: model.clampedUsedPercent.map { $0 / 100 } ?? 0,
                        bottom: "余: \(model.remainingText)"
                    )
                }
            }
        }
        .fixedSize()
    }

    private func singleLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
    }

    private func stackedLabel(top: String, bottom: String) -> some View {
        VStack(spacing: AppMeta.stackedLineGap) {
            Text(top)
                .font(.system(size: AppMeta.stackedTopFontSize, weight: .semibold))
                .lineLimit(1)
            Text(bottom)
                .font(.system(size: AppMeta.stackedBottomFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .offset(y: AppMeta.stackedVerticalNudge)
        .padding(.horizontal, AppMeta.stackedHorizontalPadding)
        .frame(minWidth: AppMeta.stackedStatusMinWidth, maxWidth: AppMeta.stackedStatusMaxWidth, minHeight: AppMeta.stackedStatusHeight)
    }

    private func circleProgressLabel(progress: Double, bottom: String) -> some View {
        VStack(spacing: AppMeta.circleLineGap) {
            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: AppMeta.circleLineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(.green, style: StrokeStyle(lineWidth: AppMeta.circleLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: AppMeta.circleDiameter, height: AppMeta.circleDiameter)

            Text(bottom)
                .font(.system(size: AppMeta.circleBottomFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppMeta.circleHorizontalPadding)
        .frame(minWidth: AppMeta.circleMinWidth, maxWidth: AppMeta.circleMaxWidth, minHeight: AppMeta.stackedStatusHeight)
    }
}

struct APIKeyEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String

    let title: String
    let description: String
    let onSave: (String) -> Void

    init(
        title: String,
        description: String,
        initialValue: String,
        onSave: @escaping (String) -> Void
    ) {
        _apiKey = State(initialValue: initialValue)
        self.title = title
        self.description = description
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            Text(description)
                .foregroundStyle(.secondary)

            SecureField("Bearer Token", text: $apiKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    onSave(apiKey)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

struct IntervalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value: String

    let onSave: (Double) -> Bool

    init(initialValue: Double, onSave: @escaping (Double) -> Bool) {
        _value = State(initialValue: String(Int(initialValue)))
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置轮询间隔")
                .font(.title3.bold())

            Text("建议 >= 3 秒。")
                .foregroundStyle(.secondary)

            TextField("例如 5", text: $value)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    if onSave(parsed) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

struct MCPEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool
    @State private var portText: String

    let onSave: (Bool, UInt16) -> Bool

    init(initialEnabled: Bool, initialPort: UInt16, onSave: @escaping (Bool, UInt16) -> Bool) {
        _isEnabled = State(initialValue: initialEnabled)
        _portText = State(initialValue: String(initialPort))
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MCP 服务设置")
                .font(.title3.bold())

            Text("应用会在本机启动一个 HTTP MCP 快照服务，供 AI 读取最新数据。")
                .foregroundStyle(.secondary)

            Toggle("启用 MCP 本地服务", isOn: $isEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("端口")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("8765", text: $portText)
                    .textFieldStyle(.roundedBorder)
                Text("示例地址: http://\(AppMeta.mcpHost):\(portText)/mcp/snapshot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    let parsedPort = UInt16(portText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                    if onSave(isEnabled, parsedPort) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

struct MonitorPreviewGallery: View {
    private let previewModels: [StatusSummaryViewModel] = [
        .previewOnline,
        .previewSettings,
        .previewWarning,
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("菜单栏样式预览")
                        .font(.title3.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(StatusDisplayStyle.allCases) { style in
                            HStack(spacing: 16) {
                                StatusBarLabelView(
                                    model: StatusBarPresentation(
                                        style: style,
                                        fallbackText: "余额: 加载中...",
                                        remainingText: "85.94",
                                        usageText: "14.06/100.00",
                                        usedPercent: 14.06
                                    )
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .liquidGlassCapsule()

                                Text(style.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("面板预览")
                        .font(.title3.bold())

                    ForEach(Array(previewModels.enumerated()), id: \.offset) { _, model in
                        LiquidGlassSummaryPanel(
                            model: model,
                            onTogglePanelMode: nil,
                            onToggleEmail: nil,
                            onRefresh: nil,
                            onSetAPIKey: nil,
                            onSetAGIKey: nil,
                            onSetInterval: nil,
                            onOpenDashboard: nil,
                            onOpenPricing: nil,
                            onSelectDisplayStyle: nil,
                            onConfigureMCP: nil,
                            updateCheckStatusText: "已就绪",
                            canCheckForUpdates: true,
                            onCheckForUpdates: nil,
                            onQuit: nil
                        )
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 900)
        .background(PreviewControlCenterBackdrop())
    }
}

private struct PreviewControlCenterBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.14, blue: 0.16),
                    Color(red: 0.11, green: 0.18, blue: 0.28),
                    Color(red: 0.30, green: 0.52, blue: 0.72),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack(spacing: 0) {
                Color.black.opacity(0.34)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.00),
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.00),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 90)
                Color.clear
            }

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: 240, y: -180)

            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.blue.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 360, height: 460)
                .blur(radius: 42)
                .offset(x: 210, y: -20)

            Circle()
                .fill(Color.blue.opacity(0.28))
                .frame(width: 180, height: 180)
                .blur(radius: 36)
                .offset(x: 270, y: 210)
        }
        .ignoresSafeArea()
    }
}

#Preview("Preview Gallery") {
    MonitorPreviewGallery()
}

#Preview("Statistics Panel") {
    LiquidGlassSummaryPanel(
        model: .previewOnline,
        onTogglePanelMode: nil,
        onToggleEmail: nil,
        onRefresh: nil,
        onSetAPIKey: nil,
        onSetAGIKey: nil,
        onSetInterval: nil,
        onOpenDashboard: nil,
        onOpenPricing: nil,
        onSelectDisplayStyle: nil,
        onConfigureMCP: nil,
        updateCheckStatusText: "已就绪",
        canCheckForUpdates: true,
        onCheckForUpdates: nil,
        onQuit: nil
    )
}
