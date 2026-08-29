import Foundation
import Combine

final class PaperSettings: ObservableObject {
    @Published var opacity: Double {
        didSet { UserDefaults.standard.set(opacity, forKey: "opacity") }
    }
    @Published var warmth: Double {
        didSet { UserDefaults.standard.set(warmth, forKey: "warmth") }
    }
    @Published var texture: PaperTexture {
        didSet { UserDefaults.standard.set(texture.rawValue, forKey: "texture") }
    }

    init() {
        let d = UserDefaults.standard
        opacity = d.object(forKey: "opacity") as? Double ?? 0.12
        warmth = d.object(forKey: "warmth") as? Double ?? 0.10
        let raw = d.string(forKey: "texture") ?? ""
        texture = PaperTexture(rawValue: raw) ?? .matte
    }
}