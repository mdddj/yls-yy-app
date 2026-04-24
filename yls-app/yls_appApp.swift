//
//  yls_appApp.swift
//  yls-app
//
//  Created by ldd on 2026/4/23.
//

import SwiftUI

@main
struct yls_appApp: App {
    @StateObject private var store = CodexMonitorStore()
    @StateObject private var appUpdater = AppUpdater()

    @SceneBuilder
    var body: some Scene {
        MenuBarExtra {
            CodexMonitorMenuBarContent(store: store, appUpdater: appUpdater)
        } label: {
            StatusBarLabelView(model: store.statusBarPresentation)
                .task {
                    store.bootstrapIfNeeded()
                    appUpdater.bootstrapIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Window(ConfigurationWindowKind.apiKey.title, id: ConfigurationWindowKind.apiKey.id) {
            APIKeyEditorSheet(
                title: ConfigurationWindowKind.apiKey.title,
                description: "请输入 Codex Bearer Token，只填 token 本体。",
                initialValue: store.currentAPIKeyValue
            ) { value in
                store.saveAPIKey(value)
            }
        }
        .defaultSize(
            width: ConfigurationWindowKind.apiKey.defaultSize.width,
            height: ConfigurationWindowKind.apiKey.defaultSize.height
        )
        .windowResizability(.contentSize)

        Window(ConfigurationWindowKind.agiKey.title, id: ConfigurationWindowKind.agiKey.id) {
            APIKeyEditorSheet(
                title: ConfigurationWindowKind.agiKey.title,
                description: "请输入 AGI Bearer Token，只填 token 本体。",
                initialValue: store.currentAGIKeyValue
            ) { value in
                store.saveAGIKey(value)
            }
        }
        .defaultSize(
            width: ConfigurationWindowKind.agiKey.defaultSize.width,
            height: ConfigurationWindowKind.agiKey.defaultSize.height
        )
        .windowResizability(.contentSize)

        Window(ConfigurationWindowKind.interval.title, id: ConfigurationWindowKind.interval.id) {
            IntervalEditorSheet(initialValue: store.pollInterval) { value in
                store.savePollInterval(value)
            }
        }
        .defaultSize(
            width: ConfigurationWindowKind.interval.defaultSize.width,
            height: ConfigurationWindowKind.interval.defaultSize.height
        )
        .windowResizability(.contentSize)

        Window(ConfigurationWindowKind.mcp.title, id: ConfigurationWindowKind.mcp.id) {
            MCPEditorSheet(
                initialEnabled: store.mcpEnabled,
                initialPort: store.mcpPort
            ) { enabled, port in
                store.saveMCPConfiguration(enabled: enabled, port: port)
            }
        }
        .defaultSize(
            width: ConfigurationWindowKind.mcp.defaultSize.width,
            height: ConfigurationWindowKind.mcp.defaultSize.height
        )
        .windowResizability(.contentSize)

        Window(ConfigurationWindowKind.updates.title, id: ConfigurationWindowKind.updates.id) {
            UpdateFeedEditorSheet(
                initialFeedURL: appUpdater.currentFeedURLValue,
                publicKeyStatusText: appUpdater.publicKeyStatusText
            ) { value in
                appUpdater.saveFeedURL(value)
            }
        }
        .defaultSize(
            width: ConfigurationWindowKind.updates.defaultSize.width,
            height: ConfigurationWindowKind.updates.defaultSize.height
        )
        .windowResizability(.contentSize)
    }
}
