import Foundation

public struct AppEntry: Sendable, Codable, Equatable, Identifiable, Hashable {
    public var id: String { bundleIdentifier }
    public let bundleName: String
    public let canonicalName: String
    public let category: String
    public let bundleIdentifier: String

    public init(bundleName: String, canonicalName: String, category: String, bundleIdentifier: String) {
        self.bundleName = bundleName
        self.canonicalName = canonicalName
        self.category = category
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum AppCatalog {
    public static let systemAppsDenyList: Set<String> = [
        "com.apple.Finder",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.SystemUIServer",
        "com.apple.WindowManager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "local.summon.end-of-day",
        "com.summon.app",
    ]

    public static let categoryOrder: [String] = [
        "Office", "Communication", "Productivity", "Browsers", "Dev", "Design", "Remote/IT", "Other",
    ]

    private static let categoryPriorities: [String: Int] = [
        "Communication": 1,
        "Office": 1,
        "Browsers": 2,
        "Productivity": 2,
        "Remote/IT": 2,
        "Other": 2,
        "Dev": 3,
        "Design": 3,
    ]

    public static let entries: [AppEntry] = [
        // Office
        AppEntry(bundleName: "Microsoft Outlook", canonicalName: "Microsoft Outlook", category: "Office", bundleIdentifier: "com.microsoft.Outlook"),
        AppEntry(bundleName: "Microsoft Teams", canonicalName: "Microsoft Teams", category: "Office", bundleIdentifier: "com.microsoft.teams2"),
        AppEntry(bundleName: "Microsoft Teams (work or school)", canonicalName: "Microsoft Teams (work or school)", category: "Office", bundleIdentifier: "com.microsoft.teams"),
        AppEntry(bundleName: "Microsoft Edge", canonicalName: "Microsoft Edge", category: "Office", bundleIdentifier: "com.microsoft.edgemac"),
        AppEntry(bundleName: "Microsoft Excel", canonicalName: "Microsoft Excel", category: "Office", bundleIdentifier: "com.microsoft.Excel"),
        AppEntry(bundleName: "Microsoft Word", canonicalName: "Microsoft Word", category: "Office", bundleIdentifier: "com.microsoft.Word"),
        AppEntry(bundleName: "Microsoft PowerPoint", canonicalName: "Microsoft PowerPoint", category: "Office", bundleIdentifier: "com.microsoft.Powerpoint"),
        AppEntry(bundleName: "Microsoft OneNote", canonicalName: "Microsoft OneNote", category: "Office", bundleIdentifier: "com.microsoft.onenote.mac"),
        // Communication
        AppEntry(bundleName: "Slack", canonicalName: "Slack", category: "Communication", bundleIdentifier: "com.tinyspeck.slackmacgap"),
        AppEntry(bundleName: "zoom.us", canonicalName: "zoom.us", category: "Communication", bundleIdentifier: "us.zoom.xos"),
        AppEntry(bundleName: "WhatsApp", canonicalName: "WhatsApp", category: "Communication", bundleIdentifier: "net.whatsapp.WhatsApp"),
        AppEntry(bundleName: "Discord", canonicalName: "Discord", category: "Communication", bundleIdentifier: "com.hnc.Discord"),
        AppEntry(bundleName: "Telegram", canonicalName: "Telegram", category: "Communication", bundleIdentifier: "ru.keepcoder.Telegram"),
        AppEntry(bundleName: "Signal", canonicalName: "Signal", category: "Communication", bundleIdentifier: "org.whispersystems.signal-desktop"),
        AppEntry(bundleName: "Loom", canonicalName: "Loom", category: "Communication", bundleIdentifier: "com.loom.desktop"),
        AppEntry(bundleName: "Webex", canonicalName: "Webex", category: "Communication", bundleIdentifier: "com.cisco.webexmeetingsapp"),
        // Productivity
        AppEntry(bundleName: "Notion", canonicalName: "Notion", category: "Productivity", bundleIdentifier: "notion.id"),
        AppEntry(bundleName: "Obsidian", canonicalName: "Obsidian", category: "Productivity", bundleIdentifier: "md.obsidian"),
        AppEntry(bundleName: "Todoist", canonicalName: "Todoist", category: "Productivity", bundleIdentifier: "com.todoist.mac.Todoist"),
        AppEntry(bundleName: "Things3", canonicalName: "Things 3", category: "Productivity", bundleIdentifier: "com.culturedcode.ThingsMac"),
        // Browsers
        AppEntry(bundleName: "Google Chrome", canonicalName: "Google Chrome", category: "Browsers", bundleIdentifier: "com.google.Chrome"),
        AppEntry(bundleName: "Firefox", canonicalName: "Firefox", category: "Browsers", bundleIdentifier: "org.mozilla.firefox"),
        AppEntry(bundleName: "Arc", canonicalName: "Arc", category: "Browsers", bundleIdentifier: "company.thebrowser.Browser"),
        // Dev
        AppEntry(bundleName: "Visual Studio Code", canonicalName: "Visual Studio Code", category: "Dev", bundleIdentifier: "com.microsoft.VSCode"),
        AppEntry(bundleName: "Cursor", canonicalName: "Cursor", category: "Dev", bundleIdentifier: "com.todesktop.230313mzl4w4u92"),
        AppEntry(bundleName: "iTerm2", canonicalName: "iTerm2", category: "Dev", bundleIdentifier: "com.googlecode.iterm2"),
        AppEntry(bundleName: "Warp", canonicalName: "Warp", category: "Dev", bundleIdentifier: "dev.warp.Warp-Stable"),
        AppEntry(bundleName: "GitHub Desktop", canonicalName: "GitHub Desktop", category: "Dev", bundleIdentifier: "com.github.GitHubClient"),
        AppEntry(bundleName: "TablePlus", canonicalName: "TablePlus", category: "Dev", bundleIdentifier: "com.tinyapp.TablePlus"),
        // Design
        AppEntry(bundleName: "Figma", canonicalName: "Figma", category: "Design", bundleIdentifier: "com.figma.Desktop"),
        AppEntry(bundleName: "Sketch", canonicalName: "Sketch", category: "Design", bundleIdentifier: "com.bohemiancoding.sketch3"),
        // Remote / IT
        AppEntry(bundleName: "AnyDesk", canonicalName: "AnyDesk", category: "Remote/IT", bundleIdentifier: "com.philandro.anydesk"),
        AppEntry(bundleName: "Microsoft Remote Desktop", canonicalName: "Microsoft Remote Desktop", category: "Remote/IT", bundleIdentifier: "com.microsoft.rdc.macos"),
        AppEntry(bundleName: "Cisco AnyConnect Secure Mobility Client", canonicalName: "Cisco AnyConnect Secure Mobility Client", category: "Remote/IT", bundleIdentifier: "com.cisco.anyconnect.gui"),
        AppEntry(bundleName: "GlobalProtect", canonicalName: "GlobalProtect", category: "Remote/IT", bundleIdentifier: "com.paloaltonetworks.GlobalProtect"),
        // Other
        AppEntry(bundleName: "Spotify", canonicalName: "Spotify", category: "Other", bundleIdentifier: "com.spotify.client"),
    ]

    public static let bundleIdentifierIndex: [String: AppEntry] = Dictionary(
        uniqueKeysWithValues: entries.reversed().map { ($0.bundleIdentifier, $0) }
    )

    public static let canonicalNameIndex: [String: AppEntry] = Dictionary(
        uniqueKeysWithValues: entries.reversed().map { ($0.canonicalName, $0) }
    )

    public static let bundleNameIndex: [String: AppEntry] = Dictionary(
        uniqueKeysWithValues: entries.reversed().map { ($0.bundleName, $0) }
    )

    public static func filterSystemApps(_ bundleIDs: [String]) -> [String] {
        bundleIDs.filter { !systemAppsDenyList.contains($0) }
    }

    public static func defaultPriority(for category: String) -> Int {
        categoryPriorities[category] ?? 2
    }

    public static func priority(for bundleIdentifier: String, overrides: [String: Int] = [:]) -> Int {
        if let override = overrides[bundleIdentifier] { return override }
        guard let entry = bundleIdentifierIndex[bundleIdentifier] else { return 2 }
        return defaultPriority(for: entry.category)
    }

    public static func entry(matching value: String) -> AppEntry? {
        bundleIdentifierIndex[value] ?? canonicalNameIndex[value] ?? bundleNameIndex[value]
    }

    public static func displayName(for identifierOrName: String, customNames: [String: String] = [:]) -> String {
        if let custom = customNames[identifierOrName], !custom.isEmpty {
            return custom
        }
        if let entry = entry(matching: identifierOrName) {
            return entry.canonicalName
        }
        return identifierOrName
    }

    public static func category(for identifierOrName: String) -> String {
        entry(matching: identifierOrName)?.category ?? "Other"
    }

    public static func entriesByCategory(including extraEntries: [AppEntry] = []) -> [(category: String, entries: [AppEntry])] {
        var seen = Set<String>()
        var combined: [AppEntry] = []
        for item in entries + extraEntries {
            if seen.insert(item.bundleIdentifier).inserted {
                combined.append(item)
            }
        }
        var grouped: [String: [AppEntry]] = [:]
        for entry in combined {
            grouped[entry.category, default: []].append(entry)
        }
        return categoryOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, entries: items)
        }
    }

    /// Scans `/Applications` and `~/Applications` to find which catalog apps are installed on this Mac.
    public static func installedBundleIdentifiers(searchDirectories: [URL]? = nil) -> Set<String> {
        let fm = FileManager.default
        let dirs: [URL]
        if let searchDirectories {
            dirs = searchDirectories
        } else {
            var defaults = [URL(fileURLWithPath: "/Applications")]
            let userApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            if fm.fileExists(atPath: userApps.path) {
                defaults.append(userApps)
            }
            dirs = defaults
        }

        var installed = Set<String>()
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items where item.pathExtension == "app" {
                let bundleName = item.deletingPathExtension().lastPathComponent
                if let entry = bundleNameIndex[bundleName] {
                    installed.insert(entry.bundleIdentifier)
                } else if let bundleID = Bundle(url: item)?.bundleIdentifier,
                          let entry = bundleIdentifierIndex[bundleID] {
                    installed.insert(entry.bundleIdentifier)
                }
            }
        }
        return installed
    }

    /// Infers a human-friendly category from an application bundle ID or name.
    public static func inferCategory(bundleIdentifier: String, name: String) -> String {
        if let existing = entry(matching: bundleIdentifier)?.category {
            return existing
        }
        let lower = (bundleIdentifier + " " + name).lowercased()
        if lower.contains("outlook") || lower.contains("teams") || lower.contains("word") || lower.contains("excel") || lower.contains("powerpoint") || lower.contains("office") {
            return "Office"
        }
        if lower.contains("slack") || lower.contains("zoom") || lower.contains("telegram") || lower.contains("whatsapp") || lower.contains("discord") || lower.contains("signal") || lower.contains("loom") || lower.contains("message") {
            return "Communication"
        }
        if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") || lower.contains("edge") || lower.contains("browser") || lower.contains("arc") || lower.contains("brave") {
            return "Browsers"
        }
        if lower.contains("notion") || lower.contains("obsidian") || lower.contains("todoist") || lower.contains("things") || lower.contains("note") || lower.contains("calendar") || lower.contains("remind") || lower.contains("linear") {
            return "Productivity"
        }
        if lower.contains("code") || lower.contains("terminal") || lower.contains("iterm") || lower.contains("ghostty") || lower.contains("xcode") || lower.contains("zed") || lower.contains("git") || lower.contains("sublime") || lower.contains("cursor") {
            return "Dev"
        }
        if lower.contains("figma") || lower.contains("sketch") || lower.contains("photoshop") || lower.contains("illustrator") || lower.contains("design") || lower.contains("canva") {
            return "Design"
        }
        if lower.contains("remote") || lower.contains("anydesk") || lower.contains("teamviewer") || lower.contains("vpn") || lower.contains("connect") || lower.contains("protect") {
            return "Remote/IT"
        }
        return "Other"
    }

    /// Dynamically discovers all installed .app bundles on this Mac from standard application folders.
    public static func discoverInstalledApplications(searchDirectories: [URL]? = nil) -> [AppEntry] {
        let fm = FileManager.default
        let dirs: [URL]
        if let searchDirectories {
            dirs = searchDirectories
        } else {
            var defaults = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/System/Applications")
            ]
            let userApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            if fm.fileExists(atPath: userApps.path) {
                defaults.append(userApps)
            }
            dirs = defaults
        }

        var foundByID: [String: AppEntry] = [:]
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items where item.pathExtension == "app" {
                let bundleName = item.deletingPathExtension().lastPathComponent
                guard let bundle = Bundle(url: item), let bid = bundle.bundleIdentifier, !bid.isEmpty else {
                    continue
                }
                if systemAppsDenyList.contains(bid) || bid.hasPrefix("com.apple.WebKit.") {
                    continue
                }
                if let known = bundleIdentifierIndex[bid] {
                    foundByID[bid] = known
                } else {
                    let cat = inferCategory(bundleIdentifier: bid, name: bundleName)
                    foundByID[bid] = AppEntry(
                        bundleName: bundleName,
                        canonicalName: bundleName,
                        category: cat,
                        bundleIdentifier: bid
                    )
                }
            }
        }
        return Array(foundByID.values).sorted { $0.canonicalName.localizedCaseInsensitiveCompare($1.canonicalName) == .orderedAscending }
    }
}
