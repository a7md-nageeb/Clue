import Foundation
import UIKit

enum WidgetPalette {
  static let ocean300 = UIColor(red: 102 / 255, green: 157 / 255, blue: 242 / 255, alpha: 1)
  static let ocean100 = UIColor(red: 196 / 255, green: 219 / 255, blue: 255 / 255, alpha: 1)
  static let ocean900 = UIColor(red: 15 / 255, green: 35 / 255, blue: 67 / 255, alpha: 1)
  static let charcoal50 = UIColor(red: 245 / 255, green: 245 / 255, blue: 247 / 255, alpha: 1)
  static let charcoal600 = UIColor(red: 64 / 255, green: 64 / 255, blue: 65 / 255, alpha: 1)
  static let charcoal500 = UIColor(red: 92 / 255, green: 92 / 255, blue: 94 / 255, alpha: 1)
  static let charcoal900 = UIColor(red: 20 / 255, green: 20 / 255, blue: 20 / 255, alpha: 1)
}

struct WidgetCategory: Codable, Hashable {
  let icon: String
  let count: Int
}

struct WidgetItem: Codable, Hashable, Identifiable {
  let id: String
  let title: String
  let content: String
  let icon: String
  let isPinned: Bool
  let hasTitle: Bool
  let displayTitle: String
}

struct WidgetSnapshot: Codable {
  let totalCount: Int
  let categories: [WidgetCategory]
  let items: [WidgetItem]
}

enum WidgetDataStore {
  static let appGroupId = "group.com.forgottenthings.forgottenThings"
  static let filterKey = "widget_filter_icon"
  static let pendingCopyKey = "widget_pending_copy"

  static var dataDirectory: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
      .appendingPathComponent("widget_data", isDirectory: true)
  }

  static var defaults: UserDefaults {
    UserDefaults(suiteName: appGroupId) ?? .standard
  }

  static var selectedFilter: String? {
    get {
      defaults.string(forKey: filterKey)?.nilIfEmpty
    }
    set {
      if let newValue, !newValue.isEmpty {
        defaults.set(newValue, forKey: filterKey)
      } else {
        defaults.removeObject(forKey: filterKey)
      }
    }
  }

  /// The saved filter, or nil when its category no longer has any items.
  static func activeFilter(in snapshot: WidgetSnapshot) -> String? {
    guard let filter = selectedFilter,
          snapshot.categories.contains(where: { $0.icon == filter })
    else { return nil }
    return filter
  }

  /// Items matching the active filter, pinned first.
  static func matchingItems(from snapshot: WidgetSnapshot) -> [WidgetItem] {
    let filter = activeFilter(in: snapshot)
    let items = filter.map { icon in snapshot.items.filter { $0.icon == icon } } ?? snapshot.items
    return items.filter(\.isPinned) + items.filter { !$0.isPinned }
  }

  /// Chip order: the categories picked in Edit Widget that still exist, otherwise most-used first.
  static func chipCategories(from snapshot: WidgetSnapshot, preferred: [String]) -> [WidgetCategory] {
    var seen = Set<String>()
    let picked = preferred.compactMap { icon -> WidgetCategory? in
      guard seen.insert(icon).inserted else { return nil }
      return snapshot.categories.first(where: { $0.icon == icon })
    }
    return picked.isEmpty ? snapshot.categories : picked
  }

  /// "person-square" -> "Person square", "stickyNote" -> "Sticky note".
  static func displayName(for icon: String) -> String {
    var words: [String] = []
    var current = ""
    for character in icon {
      if character == "-" || character == "_" || character.isUppercase {
        if !current.isEmpty { words.append(current) }
        current = character.isUppercase ? String(character) : ""
      } else {
        current.append(character)
      }
    }
    if !current.isEmpty { words.append(current) }
    let sentence = words.map { $0.lowercased() }.joined(separator: " ")
    return sentence.prefix(1).uppercased() + sentence.dropFirst()
  }

  /// Text the home-screen widget asked the app to place on the pasteboard.
  /// The widget process cannot write UIPasteboard on a device.
  static var pendingCopyText: String? {
    get {
      defaults.synchronize()
      return defaults.string(forKey: pendingCopyKey)?.nilIfEmpty
    }
    set {
      if let newValue, !newValue.isEmpty {
        defaults.set(newValue, forKey: pendingCopyKey)
      } else {
        defaults.removeObject(forKey: pendingCopyKey)
      }
      defaults.synchronize()
    }
  }

  static func copyText(for itemId: String) -> String {
    guard let item = loadSnapshot().items.first(where: { $0.id == itemId }) else { return "" }
    let text = item.content.isEmpty ? item.displayTitle : item.content
    return text
  }

  static func loadSnapshot() -> WidgetSnapshot {
    guard let file = dataDirectory?.appendingPathComponent("snapshot.json"),
          let data = try? Data(contentsOf: file),
          let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    else {
      return WidgetSnapshot(totalCount: 0, categories: [], items: [])
    }
    return snapshot
  }

  static func logoImage() -> UIImage? {
    image(named: "logo.png")
  }

  static func copyImage() -> UIImage? {
    image(named: "copy.png")
  }

  static func iconImage(named icon: String) -> UIImage? {
    iconData(named: icon).flatMap(UIImage.init(data:))
  }

  static func iconData(named icon: String) -> Data? {
    let safe = icon.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
    guard let url = dataDirectory?.appendingPathComponent("icons/\(safe).png") else { return nil }
    return try? Data(contentsOf: url)
  }

  private static func image(named fileName: String) -> UIImage? {
    image(at: fileName)
  }

  private static func image(at relativePath: String) -> UIImage? {
    guard let url = dataDirectory?.appendingPathComponent(relativePath),
          let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    return UIImage(data: data)
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}
