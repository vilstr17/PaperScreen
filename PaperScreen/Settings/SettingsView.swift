import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: PaperSettings
    @ObservedObject var controller: PaperOverlayController

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker(
                    "Paper Type",
                    selection: $settings.texture
                ) {
                    ForEach(PaperTexture.allCases) { texture in
                        Text(texture.displayName)
                            .tag(texture)
                    }
                }
                .pickerStyle(.menu)
                .padding()

                Section {
                    Text("Opacity")
                    Slider(
                        value: $settings.opacity,
                        in: 0.05...0.4
                    )
                }

                Section {
                    Text("Apps without overlay")
                        .font(.headline)
                    if controller.excludedApps.isEmpty {
                        Text("None — overlay is on everywhere.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(controller.excludedApps).sorted(), id: \.self) { app in
                            HStack {
                                Text(app)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    controller.excludedApps.remove(app)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Tip: use “Disable for Current App” in the menu bar while the app is in front.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()

            Spacer(minLength: 0)

            Link(destination: URL(string: "https://github.com/Bearbobs")!) {
                HStack(spacing: 6) {
                    Image(systemName: "c.circle.fill")
                    Text("Bearbobs/PaperScreen")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 360, height: 380)
    }
}