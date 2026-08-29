import SwiftUI
import AppKit

@main
struct PaperScreenApp: App {
    @StateObject private var settings: PaperSettings
    @StateObject private var controller: PaperOverlayController

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let settings = PaperSettings()

        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(
            wrappedValue: PaperOverlayController(settings: settings)
        )
    }

    private var currentAppExcluded: Bool {
        controller.excludedApps.contains(controller.focusedApp.frontBundleID ?? "")
    }

    var body: some Scene {
        MenuBarExtra {
            VStack {
                // Header
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PaperScreen")
                            .font(.headline)

                        Text(controller.enabled ? "Active" : "Paused")
                            .font(.caption)
                            .foregroundStyle(
                                controller.enabled ? .green : .secondary
                            )
                    }

                    Spacer()
                }
                .padding(.bottom, 8)

                Divider()
                Label(
                    controller.enabled ? "Paper Mode On" : "Paper Mode Off",
                    systemImage: controller.enabled
                        ? "checkmark.circle.fill"
                        : "circle"
                ).padding()


                // Current app section
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text(controller.focusedApp.frontAppName?.capitalized ?? "Unknown App")
                    } icon: {
                        Image(systemName: "app.dashed")
                    }

                    Button {
                        if let bid = controller.focusedApp.frontBundleID {
                            if currentAppExcluded {
                                controller.excludedApps.remove(bid)
                            } else {
                                controller.excludedApps.insert(bid)
                            }
                        }
                    } label: {
                        Label(
                            currentAppExcluded
                                ? "Enable for Current App"
                                : "Disable for Current App",
                            systemImage: currentAppExcluded
                                ? "eye"
                                : "eye.slash"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()

                Divider()

                // Quick info
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Opacity \(Int(settings.opacity * 100))%")
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                    }

                    Label {
                        Text(settings.texture.rawValue.capitalized)
                    } icon: {
                        Image(systemName: "square.3.layers.3d")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()


                Button {
                    controller.enabled.toggle()
                } label: {
                    Label(
                        controller.enabled ? "Disable PaperScreen" : "Enable PaperScreen",
                        systemImage: "power"
                    )
                }

                Divider()

                // Actions
                Button {
                    SettingsWindow.shared.show(
                        settings: settings,
                        controller: controller
                    )
                } label: {
                    Label("Settings…", systemImage: "slider.horizontal.3")
                }
                .keyboardShortcut(",")

                Divider()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit PaperScreen", systemImage: "power.circle")
                }
                .keyboardShortcut("q")
            }
            .padding(8)

        } label: {
            // System symbol — no asset catalog needed, always renders.
            Image(systemName: controller.enabled
                    ? "menubar.rectangle"
                    : "menubar.rectangle")
                .renderingMode(.template)
                .opacity(controller.enabled ? 1.0 : 0.4)
        }
        .menuBarExtraStyle(.window)
    }
}