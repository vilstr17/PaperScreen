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
                // Hero button — per-app paper overlay
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

                // Paper controls
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Style", selection: $settings.texture) {
                        ForEach(PaperTexture.allCases) { texture in
                            Text(texture.displayName).tag(texture)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .disabled(!controller.enabled)

                    HStack(spacing: 8) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.opacity, in: 0.05...0.4)
                            .disabled(!controller.enabled)
                        Text("\(Int(settings.opacity * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                Divider()

                // Privacy Shield — independent of paper mode
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Privacy Shield", systemImage: "shield.lefthalf.filled")
                            .font(.callout)
                        Spacer()
                        Toggle("", isOn: $settings.securityEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }

                    if settings.securityEnabled {
                        Picker(selection: $settings.securityTechnique) {
                            ForEach(SecurityTechnique.allCases) { tech in
                                Text(tech.displayName).tag(tech)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        HStack(spacing: 8) {
                            Image(systemName: "shield")
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.securityStrength, in: 0.1...1.0)
                            Text("\(Int(settings.securityStrength * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
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

                // Footer: independent master switches + actions
                HStack(spacing: 10) {
                    Text("Paper")
                        .font(.caption)
                    Toggle("", isOn: $controller.enabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()

                    Spacer()

                    Text("Shield")
                        .font(.caption)
                    Toggle("", isOn: $settings.securityEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()

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
                .opacity(controller.enabled || settings.securityEnabled ? 1.0 : 0.4)
        }
        .menuBarExtraStyle(.window)
    }
}