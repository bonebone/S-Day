import UIKit

enum AppQuickAction: String {
    case addNewPatient = "ZYYY.S-Day-app.addNewPatient"

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }

    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: rawValue,
            localizedTitle: "添加新病人",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "person.badge.plus"),
            userInfo: nil
        )
    }
}

@MainActor
enum AppQuickActionRegistry {
    static func installShortcutItems() {
        UIApplication.shared.shortcutItems = [
            AppQuickAction.addNewPatient.shortcutItem
        ]
    }

    static func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = AppQuickAction(shortcutItem: shortcutItem) else { return false }

        switch action {
        case .addNewPatient:
            AppNavigationState.shared.showPreOpComposer()
            return true
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            AppQuickActionRegistry.installShortcutItems()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        Task { @MainActor in
            AppQuickActionRegistry.installShortcutItems()
            if let shortcutItem = connectionOptions.shortcutItem {
                _ = AppQuickActionRegistry.handle(shortcutItem)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let handled = AppQuickActionRegistry.handle(shortcutItem)
            completionHandler(handled)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Task { @MainActor in
            AppQuickActionRegistry.installShortcutItems()
        }
    }
}
