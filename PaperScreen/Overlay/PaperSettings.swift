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

    // Security layer
    @Published var securityEnabled: Bool {
        didSet { UserDefaults.standard.set(securityEnabled, forKey: "securityEnabled") }
    }
    @Published var securityTechnique: SecurityTechnique {
        didSet { UserDefaults.standard.set(securityTechnique.rawValue, forKey: "securityTechnique") }
    }
    @Published var securityStrength: Double {
        didSet { UserDefaults.standard.set(securityStrength, forKey: "securityStrength") }
    }

    // Paper master — persisted so relaunch restores paper state too
    @Published var paperEnabled: Bool {
        didSet { UserDefaults.standard.set(paperEnabled, forKey: "paperEnabled") }
    }

    init() {
        let d = UserDefaults.standard
        opacity = d.object(forKey: "opacity") as? Double ?? 0.12
        warmth = d.object(forKey: "warmth") as? Double ?? 0.10
        let raw = d.string(forKey: "texture") ?? ""
        texture = PaperTexture(rawValue: raw) ?? .matte

        securityEnabled = d.object(forKey: "securityEnabled") as? Bool ?? false
        let rawTech = d.string(forKey: "securityTechnique") ?? ""
        securityTechnique = SecurityTechnique(rawValue: rawTech) ?? .spotlightFollow
        securityStrength = d.object(forKey: "securityStrength") as? Double ?? 0.6

        paperEnabled = d.object(forKey: "paperEnabled") as? Bool ?? true
    }
}