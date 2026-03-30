import UIKit
import Postles

class CustomInAppDelegate: InAppDelegate {
    func handle(action: InAppAction, context: [String : Any], notification: PostlesNotification) {
        print("PV | Action: \(action) \(context)")
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // TODO: Enter API Key and URL
        let apiKey = "pk_3f45d77c-4581-11ed-8b0b-0242ac110003"
        let urlEndpoint = "https://7101c80c7a35.ngrok.app"

        Postles.initialize(
            apiKey: apiKey,
            urlEndpoint: urlEndpoint,
            inAppDelegate: CustomInAppDelegate(),
            launchOptions: launchOptions
        )

        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("PV | Got Token", deviceToken)
        Postles.shared.register(token: deviceToken)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        Postles.shared.handle(userInfo: userInfo)
        return .newData
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        guard let url = userActivity.webpageURL else {
            return false
        }

        return Postles.shared.handle(universalLink: url)
    }
}

