import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: PaperSettings
    @ObservedObject var controller: PaperOverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apps without overlay")
                .font(.headline)

            if controller.excludedApps.isEmpty {
                Text("Overlay is on for every app.\n\nUse “Turn Off for …” in the menu bar while an app is in front to exclude it.")
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

            Spacer(minLength: 0)

            Link(destination: URL(string: "https://github.com/Bearbobs")!) {
                HStack(spacing: 6) {
                    Image(systemName: "c.circle.fill")
                    Text("Bearbobs/PaperScreen")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300, height: 260)
    }
}