//
//  ExtensionManifest.swift
//  Browser
//
//  Firefox-compatible WebExtensions manifest (MV2 + basic MV3).
//

import Foundation

struct ExtensionManifest: Codable, Equatable {
    var manifestVersion: Int
    var name: String
    var version: String
    var description: String?
    var author: String?
    var homepageURL: String?
    var icons: [String: String]?
    var permissions: [String]?
    var optionalPermissions: [String]?
    var hostPermissions: [String]?
    var contentScripts: [ContentScript]?
    var background: Background?
    var browserAction: BrowserAction?
    var action: BrowserAction?
    var optionsUI: OptionsUI?
    var browserSpecificSettings: BrowserSpecificSettings?
    var applications: BrowserSpecificSettings?

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case name, version, description, author, icons, permissions
        case optionalPermissions = "optional_permissions"
        case hostPermissions = "host_permissions"
        case contentScripts = "content_scripts"
        case background
        case browserAction = "browser_action"
        case action
        case optionsUI = "options_ui"
        case homepageURL = "homepage_url"
        case browserSpecificSettings = "browser_specific_settings"
        case applications
    }

    struct ContentScript: Codable, Equatable {
        var matches: [String]
        var excludeMatches: [String]?
        var js: [String]?
        var css: [String]?
        var runAt: String?
        var allFrames: Bool?
        var matchAboutBlank: Bool?

        enum CodingKeys: String, CodingKey {
            case matches
            case excludeMatches = "exclude_matches"
            case js, css
            case runAt = "run_at"
            case allFrames = "all_frames"
            case matchAboutBlank = "match_about_blank"
        }
    }

    struct Background: Codable, Equatable {
        var scripts: [String]?
        var page: String?
        var persistent: Bool?
        var serviceWorker: String?

        enum CodingKeys: String, CodingKey {
            case scripts, page, persistent
            case serviceWorker = "service_worker"
        }
    }

    struct BrowserAction: Codable, Equatable {
        var defaultTitle: String?
        var defaultIcon: IconValue?
        var defaultPopup: String?

        enum CodingKeys: String, CodingKey {
            case defaultTitle = "default_title"
            case defaultIcon = "default_icon"
            case defaultPopup = "default_popup"
        }
    }

    enum IconValue: Codable, Equatable {
        case path(String)
        case sized([String: String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let path = try? container.decode(String.self) {
                self = .path(path)
            } else {
                self = .sized(try container.decode([String: String].self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .path(let path): try container.encode(path)
            case .sized(let map): try container.encode(map)
            }
        }

        var preferredPath: String? {
            switch self {
            case .path(let path): return path
            case .sized(let map):
                let preferred = ["128", "96", "64", "48", "32", "16"]
                for key in preferred {
                    if let path = map[key] { return path }
                }
                return map.values.first
            }
        }
    }

    struct OptionsUI: Codable, Equatable {
        var page: String?
        var openInTab: Bool?

        enum CodingKeys: String, CodingKey {
            case page
            case openInTab = "open_in_tab"
        }
    }

    struct BrowserSpecificSettings: Codable, Equatable {
        var gecko: Gecko?

        struct Gecko: Codable, Equatable {
            var id: String?
            var strictMinVersion: String?

            enum CodingKeys: String, CodingKey {
                case id
                case strictMinVersion = "strict_min_version"
            }
        }
    }

    /// Stable extension id: gecko id when present, otherwise a derived slug.
    var resolvedExtensionId: String {
        if let geckoId = browserSpecificSettings?.gecko?.id ?? applications?.gecko?.id, !geckoId.isEmpty {
            return geckoId
        }
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "extension.\(version)" : "\(slug)@zero.local"
    }

    var toolbarAction: BrowserAction? {
        browserAction ?? action
    }
}
