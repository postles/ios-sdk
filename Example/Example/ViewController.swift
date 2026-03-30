import UIKit
import Postles

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let id = "1"
        Postles.shared.identify(id: id, traits: [
            "first_name": "Chris",
            "last_name": "Doe"
        ])

        Postles.shared.track(event: "Application Opened", properties: [ "property": true ])
    }

    @IBAction func registerPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("PV | Notification Status: \(granted)")
            DispatchQueue.main.async {
                if granted { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    @IBAction func getNotifications() {
        Task { @MainActor in
            await Postles.shared.showLatestNotification()
        }
    }
}

