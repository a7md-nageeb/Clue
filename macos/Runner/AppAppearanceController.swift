import AppKit

enum AppAppearanceController {
  /// Matches Flutter SharedPreferences key (`flutter.` prefix + prefs key).
  static let preferencesKey = "flutter.menuBarOnlyPrefsKey"

  static func isMenuBarOnlyEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: preferencesKey)
  }

  @discardableResult
  static func setMenuBarOnly(_ enabled: Bool, hideWindows: Bool) -> Bool {
    let policy: NSApplication.ActivationPolicy = enabled ? .accessory : .regular
    guard NSApp.setActivationPolicy(policy) else { return false }

    if enabled && hideWindows {
      hideAllWindows()
    } else if !enabled {
      NSApp.activate(ignoringOtherApps: true)
      showMainWindow()
    }

    return true
  }

  @discardableResult
  static func applyStoredPreferenceOnLaunch() -> Bool {
    let enabled = isMenuBarOnlyEnabled()
    guard enabled else { return true }

    let policyApplied = NSApp.setActivationPolicy(.accessory)
    if policyApplied {
      hideAllWindows()
    }
    return policyApplied
  }

  static func hideAllWindows() {
    for window in NSApp.windows {
      window.orderOut(nil)
    }
  }

  static func showMainWindow() {
    for window in NSApp.windows where window.canBecomeMain {
      window.makeKeyAndOrderFront(nil)
      return
    }
  }
}
