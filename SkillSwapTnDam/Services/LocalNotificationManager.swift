import Foundation
import UserNotifications

final class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private let permissionKey = "LocalNotificationManager.permissionRequested"

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.promptForPermission()
            case .denied:
                self.userDefaults.set(true, forKey: self.permissionKey)
            case .authorized, .provisional, .ephemeral:
                self.userDefaults.set(true, forKey: self.permissionKey)
            @unknown default:
                break
            }
        }
    }

    private func promptForPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.userDefaults.set(granted, forKey: self.permissionKey)
        }
    }

    func presentInAppNotification(
        identifier: String = UUID().uuidString,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            if let userInfo {
                content.userInfo = userInfo
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            self.notificationCenter.add(request, withCompletionHandler: nil)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
