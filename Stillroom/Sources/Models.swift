import Foundation

enum Effect: String, CaseIterable, Codable, Identifiable {
    case off, snow, heavySnow, rain, leaves, sakura, fireflies, starfall
    var id: String { rawValue }
    var title: String {
        self == .heavySnow ? "Heavy Snow" : rawValue.capitalized
    }
}

enum WallpaperRule: String, CaseIterable, Codable, Identifiable {
    case manual, matchEffect
    var id: String { rawValue }
    var title: String { self == .manual ? "Manual" : "Match effect" }
}

enum Resolution: String, CaseIterable, Codable, Identifiable {
    case auto, normal, ultrawide
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Wallpaper: Identifiable {
    let id: String
    let title: String
    let effects: Set<Effect>
    let resource: String

    static let catalog = [
        Self(id: "salt-marsh", title: "Salt Marsh",
             effects: [.snow, .heavySnow, .fireflies, .starfall], resource: "Salt-Marsh"),
        Self(id: "amber-ridge", title: "Amber Ridge",
             effects: [.rain, .leaves, .sakura], resource: "Amber-Ridge")
    ]

    func url(for resolution: Resolution, aspectRatio: Double) -> URL? {
        let wide = resolution == .ultrawide || (resolution == .auto && aspectRatio > 2.1)
        return (wide ? Bundle.main.url(forResource: resource + "-Wide", withExtension: "png") : nil)
            ?? Bundle.main.url(forResource: resource, withExtension: "png")
    }
}

struct Preferences: Codable {
    var onboardingComplete = false
    var effect: Effect = .off
    var lastEffect: Effect = .snow
    var manualPause = false
    var pauseOnBattery = false
    var reduceMotion = false
    var wind = 0.0
    var rainbow = false
    var lightning = false
    var rule: WallpaperRule = .manual
    var weatherDisabled: Set<String> = []
    var resolution: [String: Resolution] = [:]
    var desired: [String: String] = [:]
    var seenDisplays: Set<String> = []
    var defaultWallpaper: String?

    private static let key = "stillroom.preferences.v1"

    static func load(_ defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: key),
              let prefs = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return prefs
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
