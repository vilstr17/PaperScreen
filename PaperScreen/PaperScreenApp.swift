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

    private var currentAppName: String {
        controller.focusedApp.frontAppName?.capitalized ?? "No App"
    }

    private var currentAppExcluded: Bool {
        controller.excludedApps.contains(controller.focusedApp.frontBundleID ?? "")
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 12) {
                // Title bar
                HStack(spacing: 6) {
                    Image(systemName: "menubar.rectangle")
                        .frame(width: 18)
                    Text("PaperScreen")
                        .font(.headline)
                    Spacer()
                    Text(settings.paperEnabled ? "On" : "Off")
                        .font(.caption)
                        .foregroundStyle(settings.paperEnabled ? .green : .secondary)
                }

                // ══ SECTION 1: PAPER MODE ══
                VStack(spacing: 10) {
                    HStack {
                        Text("PAPER MODE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $settings.paperEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
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
                                ? "Turn On for \(currentAppName)"
                                : "Turn Off for \(currentAppName)",
                            systemImage: currentAppExcluded ? "eye" : "eye.slash"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(currentAppExcluded ? .green : .primary)
                    .disabled(controller.focusedApp.frontBundleID == nil)

                    Picker("", selection: $settings.texture) {
                        ForEach(PaperTexture.allCases) { texture in
                            Text(texture.displayName).tag(texture)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.opacity, in: 0.05...0.4)
                        Text("\(Int(settings.opacity * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                if !controller.excludedApps.isEmpty {
                    Text(controller.excludedApps.count == 1
                            ? "1 app without overlay"
                            : "\(controller.excludedApps.count) apps without overlay")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Bottom row — settings & quit only
                HStack {
                    Spacer()

                    Button {
                        SettingsWindow.shared.show(
                            settings: settings,
                            controller: controller
                        )
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                    .help("Settings")

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Quit PaperScreen")
                }
            }
            .padding(12)
            .frame(width: 268)
        } label: {
            Image(systemName: "menubar.rectangle")
                .renderingMode(.template)
                .opacity(settings.paperEnabled ? 1.0 : 0.4)
        }
        .menuBarExtraStyle(.window)
    }
}