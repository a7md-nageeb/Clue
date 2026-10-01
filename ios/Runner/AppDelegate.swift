import Flutter
import UIKit
import WidgetKit

final class WidgetChannel {
  static let shared = WidgetChannel()
  var channel: FlutterMethodChannel? {
    didSet { deliverCopyPreview() }
  }
  private var pendingCreate = false
  private var pendingCopyPreview: String?
  private var pendingCopyAt: Date?

  func handle(url: URL) {
    switch url.host {
    case "create":
      openCreate()
    case "copy":
      prepareCopy(url)
    default:
      break
    }
  }

  func openCreate() {
    if let channel {
      channel.invokeMethod("openCreate", arguments: nil)
    } else {
      pendingCreate = true
    }
  }

  func flushPendingCreate() {
    guard pendingCreate else { return }
    pendingCreate = false
    channel?.invokeMethod("openCreate", arguments: nil)
  }

  func prepareCopy(_ url: URL) {
    guard
      let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == "id" })?
        .value,
      !id.isEmpty
    else { return }
    let text = WidgetDataStore.copyText(for: id)
    guard !text.isEmpty else { return }
    WidgetDataStore.pendingCopyText = text
  }

  func flushPendingCopy(retry: Bool = true) {
    guard UIApplication.shared.applicationState == .active else {
      scheduleCopyRetry(retry)
      return
    }
    guard let text = WidgetDataStore.pendingCopyText, !text.isEmpty else {
      scheduleCopyRetry(retry)
      return
    }
    UIPasteboard.general.string = text
    WidgetDataStore.pendingCopyText = nil
    pendingCopyPreview = text.count > 40 ? "\(text.prefix(40))..." : text
    pendingCopyAt = Date()
    deliverCopyPreview()
  }

  private func scheduleCopyRetry(_ retry: Bool) {
    guard retry else { return }
    for delay in [0.35, 1.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        self?.flushPendingCopy(retry: false)
      }
    }
  }

  func consumePendingCopy() -> String? {
    guard
      let pendingCopyPreview,
      let pendingCopyAt,
      Date().timeIntervalSince(pendingCopyAt) < 8
    else {
      self.pendingCopyPreview = nil
      pendingCopyAt = nil
      return nil
    }
    self.pendingCopyPreview = nil
    self.pendingCopyAt = nil
    return pendingCopyPreview
  }

  private func deliverCopyPreview() {
    guard let channel, let pendingCopyPreview else { return }
    channel.invokeMethod("copied", arguments: pendingCopyPreview)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      WidgetChannel.shared.handle(url: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    WidgetChannel.shared.flushPendingCopy()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.forgottenthings.forgotten_things/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    WidgetChannel.shared.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getWidgetDataDirectory":
        guard let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: "group.com.forgottenthings.forgottenThings"
        ) else {
          result(
            FlutterError(
              code: "no_app_group",
              message: "App group container is unavailable",
              details: nil
            )
          )
          return
        }
        let directory = container.appendingPathComponent("widget_data", isDirectory: true)
        do {
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          result(directory.path)
        } catch {
          result(
            FlutterError(
              code: "io_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "updateWidget":
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      case "consumePendingCopy":
        result(WidgetChannel.shared.consumePendingCopy())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    WidgetChannel.shared.flushPendingCreate()
    WidgetChannel.shared.flushPendingCopy()
  }
}
