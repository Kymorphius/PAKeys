import ServiceManagement
import SwiftUI

@main
struct PAKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("PAKeys", id: "main") {
            MenuContent(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(model: model)
    }
}

/// Uses a native, persistent NSStatusItem so menu-bar managers such as Bartender
/// can identify, position, hide, and restore PAKeys reliably.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init(model: AppModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.autosaveName = "dev.333.PAKeys.statusItem"
        statusItem.isVisible = true

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "command", accessibilityDescription: "PAKeys")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "PAKeys — 右 Command → 左 Command"
            button.setAccessibilityLabel("PAKeys")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 260)
        popover.contentViewController = NSHostingController(rootView: MenuContent(model: model))
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var mappingEnabled = false
    @Published var launchAtLogin = false
    @Published var isBusy = false
    @Published var message: String?

    private let service = HIDMappingService()
    private let enabledKey = "mappingEnabled"

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled

        let shouldEnable = UserDefaults.standard.bool(forKey: enabledKey)
        Task { await refreshAndRestore(shouldEnable: shouldEnable) }
    }

    func setMappingEnabled(_ enabled: Bool) {
        guard !isBusy else { return }
        isBusy = true
        message = nil

        Task {
            do {
                try await perform { try self.service.setEnabled(enabled) }
                mappingEnabled = enabled
                UserDefaults.standard.set(enabled, forKey: enabledKey)
            } catch {
                message = error.localizedDescription
                await refreshOnly()
            }
            isBusy = false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            message = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            message = "无法更新登录启动设置：\(error.localizedDescription)"
        }
    }

    func refresh() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            await refreshOnly()
            isBusy = false
        }
    }

    private func refreshAndRestore(shouldEnable: Bool) async {
        isBusy = true
        do {
            if shouldEnable {
                try await perform { try self.service.setEnabled(true) }
            }
            mappingEnabled = try await perform { try self.service.isEnabled() }
        } catch {
            message = error.localizedDescription
        }
        isBusy = false
    }

    private func refreshOnly() async {
        do {
            mappingEnabled = try await perform { try self.service.isEnabled() }
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: operation).value
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAKeys")
                        .font(.headline)
                    Text("右 Command → 左 Command")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("启用按键映射", isOn: Binding(
                get: { model.mappingEnabled },
                set: { model.setMappingEnabled($0) }
            ))
            .disabled(model.isBusy)

            Toggle("登录时自动启动", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            if model.isBusy {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在更新…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(
                    model.mappingEnabled ? "映射已生效" : "映射未启用",
                    systemImage: model.mappingEnabled ? "checkmark.circle.fill" : "circle"
                )
                .font(.caption)
                .foregroundStyle(model.mappingEnabled ? .green : .secondary)
            }

            Divider()

            HStack {
                Button("打开窗口") {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApplication.shared.windows
                        .first(where: { $0.title == "PAKeys" })?
                        .makeKeyAndOrderFront(nil)
                }
                Button("刷新") { model.refresh() }
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}
