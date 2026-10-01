import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    for context in connectionOptions.urlContexts {
      WidgetChannel.shared.handle(url: context.url)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    WidgetChannel.shared.flushPendingCopy()
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      WidgetChannel.shared.handle(url: context.url)
    }
    super.scene(scene, openURLContexts: URLContexts)
    WidgetChannel.shared.flushPendingCopy()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    WidgetChannel.shared.flushPendingCopy()
  }
}
