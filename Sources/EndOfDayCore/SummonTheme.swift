import Foundation

public struct RGBComponents: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        self.red = Double((value >> 16) & 0xFF) / 255.0
        self.green = Double((value >> 8) & 0xFF) / 255.0
        self.blue = Double(value & 0xFF) / 255.0
    }
}

public struct SummonTheme: Sendable, Codable, Equatable {
    public struct Colors: Sendable, Codable, Equatable {
        public var background: String
        public var foreground: String
        public var accent: String
        public var accent2: String
        public var muted: String
        public var selection: String

        public init(
            background: String = "#1a1b26",
            foreground: String = "#c0caf5",
            accent: String = "#7aa2f7",
            accent2: String = "#bb9af7",
            muted: String = "#565f89",
            selection: String = "#33467c"
        ) {
            self.background = background
            self.foreground = foreground
            self.accent = accent
            self.accent2 = accent2
            self.muted = muted
            self.selection = selection
        }
    }

    public var name: String
    public var slug: String
    public var appearance: String
    public var colors: Colors

    public var isDark: Bool { appearance.lowercased() != "light" }

    public var accentRGB: RGBComponents {
        RGBComponents(hex: colors.accent) ?? RGBComponents(red: 0.48, green: 0.64, blue: 0.97)
    }

    public var accent2RGB: RGBComponents {
        RGBComponents(hex: colors.accent2) ?? accentRGB
    }

    public var backgroundRGB: RGBComponents {
        RGBComponents(hex: colors.background) ?? RGBComponents(red: 0.10, green: 0.11, blue: 0.15)
    }

    public var foregroundRGB: RGBComponents {
        RGBComponents(hex: colors.foreground) ?? RGBComponents(red: 0.75, green: 0.79, blue: 0.96)
    }

    public init(
        name: String = "Tokyo Night",
        slug: String = "tokyo-night",
        appearance: String = "dark",
        colors: Colors = Colors()
    ) {
        self.name = name
        self.slug = slug
        self.appearance = appearance
        self.colors = colors
    }

    public static let fallback = SummonTheme()

    public static var summonConfigDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/summon", isDirectory: true)
    }

    /// Resolves the active theme from `~/.config/summon/current/theme.json` or `~/.config/summon/current-theme` -> `themes/<slug>/theme.json`.
    public static func loadCurrent(configDir: URL = SummonTheme.summonConfigDir) -> SummonTheme {
        let fm = FileManager.default
        let currentThemeJSON = configDir.appendingPathComponent("current/theme.json")
        if fm.fileExists(atPath: currentThemeJSON.path),
           let data = try? Data(contentsOf: currentThemeJSON),
           let decoded = try? JSONDecoder().decode(SummonTheme.self, from: data) {
            return decoded
        }

        let currentThemeSlugFile = configDir.appendingPathComponent("current-theme")
        if fm.fileExists(atPath: currentThemeSlugFile.path),
           let slugRaw = try? String(contentsOf: currentThemeSlugFile, encoding: .utf8) {
            let slug = slugRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !slug.isEmpty {
                let slugThemeJSON = configDir
                    .appendingPathComponent("themes", isDirectory: true)
                    .appendingPathComponent(slug, isDirectory: true)
                    .appendingPathComponent("theme.json")
                if let data = try? Data(contentsOf: slugThemeJSON),
                   let decoded = try? JSONDecoder().decode(SummonTheme.self, from: data) {
                    return decoded
                }
            }
        }

        return .fallback
    }
}
