import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private var systemChannel: FlutterMethodChannel?
  private var menuBarChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    isRestorable = false

    let defaultContentSize = NSSize(width: 380, height: 680)
    setContentSize(defaultContentSize)
    minSize = NSSize(width: 380, height: 400)

    let flutterViewController = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)
    setContentSize(defaultContentSize)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupSystemChannel(messenger: flutterViewController.engine.binaryMessenger)
    setupMenuBarChannel(messenger: flutterViewController.engine.binaryMessenger)
    MenuBarController.shared.setup(mainWindow: self)

    if AppAppearanceController.isMenuBarOnlyEnabled() {
      orderOut(nil)
    }

    super.awakeFromNib()

    DispatchQueue.main.async { [weak self] in
      self?.setContentSize(defaultContentSize)
    }
  }

  private func setupSystemChannel(messenger: FlutterBinaryMessenger) {
    systemChannel = FlutterMethodChannel(
      name: "forgotten_things/system",
      binaryMessenger: messenger
    )
    systemChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getStartAtStartup":
        result(self?.isStartAtStartupEnabled() ?? false)
      case "setStartAtStartup":
        if let enabled = call.arguments as? Bool {
          result(self?.setStartAtStartup(enabled) ?? false)
        } else {
          result(false)
        }
      case "getMenuBarOnly":
        result(AppAppearanceController.isMenuBarOnlyEnabled())
      case "setMenuBarOnly":
        if let enabled = call.arguments as? Bool {
          result(AppAppearanceController.setMenuBarOnly(enabled, hideWindows: false))
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupMenuBarChannel(messenger: FlutterBinaryMessenger) {
    menuBarChannel = FlutterMethodChannel(name: "ace/menubar", binaryMessenger: messenger)
    menuBarChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "updateItems":
        if let payload = call.arguments as? [String: Any] {
          MenuBarController.shared.updateItems(payload)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected items payload", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    MenuBarController.shared.onRefreshRequested = { [weak self] in
      self?.menuBarChannel?.invokeMethod("requestRefresh", arguments: nil) { _ in }
    }
  }

  private func isStartAtStartupEnabled() -> Bool {
    if #available(macOS 13.0, *) {
      return SMAppService.mainApp.status == .enabled
    }
    return false
  }

  private func setStartAtStartup(_ enabled: Bool) -> Bool {
    guard #available(macOS 13.0, *) else { return false }
    do {
      if enabled {
        if SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        }
      } else if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      }
      return SMAppService.mainApp.status == (enabled ? .enabled : .notRegistered)
    } catch {
      return false
    }
  }
}
