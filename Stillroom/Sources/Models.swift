import Foundation

enum Effect: String, CaseIterable, Codable, Identifiable {
    case off, snow, heavySnow, drizzle, rain, mist, leaves, sakura, fireflies, starfall
    var id: String { rawValue }
    var title: String {
        self == .heavySnow ? "Heavy Snow" : rawValue.capitalized
    }
}

enum EffectDensity: String, CaseIterable, Codable, Identifiable {
    case light, balanced, full

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var multiplier: Double {
        switch self {
        case .light: 0.55
        case .balanced: 1
        case .full: 1.65
        }
    }
}

enum WallpaperRule: String, CaseIterable, Codable, Identifiable {
    case manual, matchEffect, dayNight, season, random
    var id: String { rawValue }
    var title: String {
        switch self {
        case .manual: "Manual"
        case .matchEffect: "Match effect"
        case .dayNight: "Day & night"
        case .season: "Season"
        case .random: "Random"
        }
    }
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
             effects: [.snow, .heavySnow, .mist, .fireflies, .starfall], resource: "Salt-Marsh"),
        Self(id: "amber-ridge", title: "Amber Ridge",
             effects: [.drizzle, .rain, .leaves, .sakura], resource: "Amber-Ridge")
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
    // Optional storage lets existing v1 preferences decode without a density key.
    private var effectDensity: EffectDensity?
    var density: EffectDensity {
        get { effectDensity ?? .balanced }
        set { effectDensity = newValue }
    }
    var groundSnow: Bool?
    var surfaceSnow: Bool?
    var deeperSnow: Bool?
    var snowCrafting: Bool?
    var southernHemisphere: Bool?
    var randomHours: Int?
    var lastRandomSlot: Int?
    var lastRandomWallpaper: String?
    var automaticWallpaperKey: String?
    var saverDelay: Int?
    var saverScene: String?
    var saverShuffle: Bool?
    var desktopProps: [String: Set<DesktopProp>]?
    var decorationLayouts: [String: [DesktopProp: DecorationLayout]]?
    var automaticVisitors: Set<DesktopVisitor>?
    var routeVisitorsAcrossDisplays: Bool?
    var interfaceLanguage: String?
    var effectsAboveWindows: Bool?
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
