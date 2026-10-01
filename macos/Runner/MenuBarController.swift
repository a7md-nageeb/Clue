import AppKit
import FlutterMacOS

struct MenuBarItemData {
  let id: String
  let title: String
  let content: String
  let iconPng: Data?

  init?(dict: [String: Any]) {
    guard let id = dict["id"] as? String,
          let content = dict["content"] as? String else { return nil }
    self.id = id
    self.title = dict["title"] as? String ?? ""
    self.content = content
    if let typedData = dict["iconPng"] as? FlutterStandardTypedData {
      iconPng = typedData.data
    } else {
      iconPng = nil
    }
  }
}

final class MenuBarController: NSObject, NSMenuDelegate {
  static let shared = MenuBarController()

  private var statusItem: NSStatusItem?
  private weak var mainWindow: NSWindow?
  private var menuItems: [MenuBarItemData] = []
  var onRefreshRequested: (() -> Void)?

  private override init() {
    super.init()
  }

  func setup(mainWindow: NSWindow?) {
    self.mainWindow = mainWindow

    if statusItem == nil {
      createStatusItem()
    }

    rebuildMenu()
  }

  /// Recreates the status item after activation policy changes.
  /// NSStatusItem must be created at the correct window layer for the current policy.
  func recreateStatusItem() {
    if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
    createStatusItem()
    rebuildMenu()
  }

  private func createStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem = item

    if let button = item.button {
      if let icon = Self.loadMenuBarIcon() {
        button.image = icon
        button.image?.accessibilityDescription = "Clue"
        button.imageScaling = .scaleProportionallyDown
      } else if let fallback = NSImage(
        systemSymbolName: "checklist",
        accessibilityDescription: "Clue"
      ) {
        fallback.isTemplate = true
        button.image = fallback
      } else {
        button.title = "Clue"
      }
    }
  }

  func updateItems(_ payload: [String: Any]) {
    if let rawItems = payload["items"] as? [[String: Any]] {
      menuItems = rawItems.compactMap(MenuBarItemData.init(dict:))
    }

    rebuildMenu()
  }

  private func rebuildMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = true
    menu.delegate = self

    if menuItems.isEmpty {
      let emptyItem = NSMenuItem(title: "No items", action: nil, keyEquivalent: "")
      emptyItem.isEnabled = false
      menu.addItem(emptyItem)
    } else {
      for item in menuItems {
        let rowView = MenuBarItemRowView(
          iconPng: item.iconPng,
          title: displayTitle(for: item.title, content: item.content),
          content: item.content
        )

        let menuItem = NSMenuItem()
        menuItem.view = rowView
        menuItem.target = self
        menuItem.action = #selector(copyItem(_:))
        menuItem.representedObject = item.content
        rowView.onActivate = { [weak menuItem] in
          guard let menuItem, let target = menuItem.target, let action = menuItem.action else {
            return
          }
          NSApp.sendAction(action, to: target, from: menuItem)
        }
        menu.addItem(menuItem)
      }
    }

    menu.addItem(NSMenuItem.separator())

    let refreshItem = NSMenuItem(
      title: "Refresh",
      action: #selector(refreshMenu),
      keyEquivalent: ""
    )
    refreshItem.target = self
    if let refreshImage = NSImage(
      systemSymbolName: "arrow.clockwise",
      accessibilityDescription: "Refresh"
    ) {
      refreshItem.image = refreshImage
    }
    menu.addItem(refreshItem)

    menu.addItem(NSMenuItem.separator())

    let openItem = NSMenuItem(
      title: "Open Clue",
      action: #selector(openMainWindow),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)

    let quitItem = NSMenuItem(
      title: "Quit Clue",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu?.cancelTracking()
    statusItem?.menu = menu
  }

  func menuWillOpen(_ menu: NSMenu) {
    let width = max(menu.size.width, 220)
    for case let rowView as MenuBarItemRowView in menu.items.compactMap(\.view) {
      rowView.updateWidth(width)
    }
  }

  @objc private func copyItem(_ sender: NSMenuItem) {
    guard let content = sender.representedObject as? String else { return }
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
  }

  @objc private func refreshMenu() {
    DispatchQueue.main.async { [weak self] in
      self?.onRefreshRequested?()
    }
  }

  @objc private func openMainWindow() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      NSApp.activate(ignoringOtherApps: true)

      if let mainWindow = self.mainWindow {
        mainWindow.makeKeyAndOrderFront(nil)
        return
      }

      for window in NSApp.windows where window.canBecomeMain {
        window.makeKeyAndOrderFront(nil)
        break
      }
    }
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  private func displayTitle(for title: String, content: String) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedTitle.isEmpty {
      return trimmedTitle
    }
    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedContent.count > 40 {
      return String(trimmedContent.prefix(40)) + "..."
    }
    return trimmedContent
  }

  private static func loadMenuBarIcon() -> NSImage? {
    guard let image = NSImage(named: "MenuBarIcon") else { return nil }
    image.isTemplate = true
    image.size = NSSize(width: 14, height: 16)
    return image
  }
}
