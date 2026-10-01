import AppKit
import ApplicationServices

enum AppAppearanceController {
  /// Matches Flutter SharedPreferences key (`flutter.` prefix + prefs key).
  static let preferencesKey = "flutter.menuBarOnlyPrefsKey"

  static func isMenuBarOnlyEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: preferencesKey)
  }

  /// Apply the stored Dock policy before windows exist. Switching to
  /// accessory while the app is already frontmost is what fails at runtime.
  static func applyStoredPolicyBeforeWindows() {
    guard isMenuBarOnlyEnabled() else { return }
    _ = applyActivationPolicy(.accessory)
  }

  static func setMenuBarOnly(
    _ enabled: Bool,
    hideWindows: Bool,
    completion: @escaping (Bool) -> Void
  ) {
    runOnMainAsync {
      let policy: NSApplication.ActivationPolicy = enabled ? .accessory : .regular
      attemptActivationPolicy(policy) { success in
        finishMenuBarOnlyChange(enabled: enabled, hideWindows: hideWindows)
        completion(success)
      }
    }
  }

  /// Always put the window on screen. Login items start hidden; accessory
  /// policy can also autohide. Dock hiding is applied after the window is
  /// visible, then the window is restored.
  static func presentOnLaunch() {
    NSApp.unhide(nil)
    showMainWindow()
    NSApp.activate(ignoringOtherApps: true)

    guard isMenuBarOnlyEnabled() else { return }

    DispatchQueue.main.async {
      applyDockPolicyThenRestoreWindow()
    }
  }

  @discardableResult
  static func applyDockPolicy() -> Bool {
    var success = false
    runOnMainSync {
      let policy: NSApplication.ActivationPolicy =
        isMenuBarOnlyEnabled() ? .accessory : .regular
      success = applyActivationPolicy(policy)
      if success {
        MenuBarController.shared.recreateStatusItem()
      }
    }
    return success
  }

  static func hideAllWindows() {
    for window in NSApp.windows {
      window.orderOut(nil)
    }
  }

  static func showMainWindow() {
    NSApp.unhide(nil)

    let window = NSApp.windows.first(where: { $0 is MainFlutterWindow })
      ?? NSApp.windows.first(where: \.canBecomeMain)
      ?? NSApp.windows.first

    window?.deminiaturize(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  private static func finishMenuBarOnlyChange(enabled: Bool, hideWindows: Bool) {
    if enabled && hideWindows {
      hideAllWindows()
    } else {
      showMainWindow()
    }
    MenuBarController.shared.recreateStatusItem()
  }

  private static func applyDockPolicyThenRestoreWindow() {
    let policy: NSApplication.ActivationPolicy =
      isMenuBarOnlyEnabled() ? .accessory : .regular

    func restore() {
      showMainWindow()
      MenuBarController.shared.recreateStatusItem()
    }

    attemptActivationPolicy(policy) { _ in
      restore()
    }
  }

  private static func attemptActivationPolicy(
    _ policy: NSApplication.ActivationPolicy,
    completion: @escaping (Bool) -> Void
  ) {
    if applyActivationPolicy(policy) {
      completion(true)
      return
    }

    // Accessory policy is rejected while Clue is the active app.
    NSApp.hide(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      if applyActivationPolicy(policy) {
        completion(true)
        return
      }

      NSWorkspace.shared.runningApplications
        .first { $0.bundleIdentifier == "com.apple.finder" }?
        .activate()

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        completion(applyActivationPolicy(policy))
      }
    }
  }

  @discardableResult
  private static func applyActivationPolicy(
    _ policy: NSApplication.ActivationPolicy
  ) -> Bool {
    if NSApp.activationPolicy() == policy {
      return true
    }

    _ = NSApp.setActivationPolicy(policy)
    if NSApp.activationPolicy() == policy {
      return true
    }

    _ = transformProcess(toForeground: policy == .regular)
    _ = NSApp.setActivationPolicy(policy)
    return NSApp.activationPolicy() == policy
  }

  @discardableResult
  private static func transformProcess(toForeground: Bool) -> Bool {
    var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
    let state = ProcessApplicationTransformState(
      toForeground
        ? kProcessTransformToForegroundApplication
        : kProcessTransformToUIElementApplication
    )
    return TransformProcessType(&psn, state) == noErr
  }

  private static func runOnMainSync(_ work: () -> Void) {
    if Thread.isMainThread {
      work()
      return
    }
    DispatchQueue.main.sync(execute: work)
  }

  private static func runOnMainAsync(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
      return
    }
    DispatchQueue.main.async(execute: work)
  }
}
