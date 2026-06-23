# Postles iOS SDK

## Installation
Installing the Postles iOS SDK will provide you with user identification, deeplink unwrapping and basic tracking functionality. The iOS SDK is available through common package managers (SPM & Cocoapods) or through manual installation.

### Version Information
- The Postles iOS SDK supports
  - iOS 12.0+
  - Mac Catalyst 13.0+
- Xcode 13.2.1 (13C100) or newer

### Swift Package Manager
Go to File -> Swift Packages -> Add Package Dependency and enter:
```https://github.com/postles/ios-sdk```

## Usage
### Initialize
Before using any methods, the library must be initialized with an API key and URL endpoint.

Start by importing the Postles SDK:
```swift
import Postles
```

Then you can initialize the library:
```swift
Postles.initialize(apiKey: "API_KEY", urlEndpoint: "URL_ENDPOINT")
```

### Identify
You can handle the user identity of your users by using the `identify` method. This method works in combination either/or associate a given user to your internal user ID (`external_id`) or to associate attributes (traits) to the user. By default all events and traits are associated with an anonymous ID until a user is identified with an `external_id`. From that point moving forward, all updates to the user and events will be associated to your provider identifier.
```swift
Postles.shared.identify(id: "USER_ID", traits: [
    "first_name": "John",
    "last_name": "Doe"
])
```

### Events
If you want to trigger a journey and list updates off of things a user does within your app, you can pass up those events by using the `track` method.
```swift
Postles.shared.track(
    event: "Event Name",
    properties: [
        "Key": "Value"
    ]
)
```

### Notifications
#### Register Device
In order to send push notifications to a given device you need to register for notifications and then register the device with Postles. You can do so by using the `register(token: Data?)` method. If a user does not grant access to send notifications, you can also call this method without a token to register device characteristics.
```swift
Postles.shared.register(token: "APN_TOKEN_DATA")
```

#### Handle Notifications
When a notification is received it can contain a deeplink that will trigger when a user opens it. To properly handle the routing you need to pass the received push notification to the Postles handler.
```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any]
) async -> UIBackgroundFetchResult {
    Postles.shared.handle(application, userInfo: userInfo)
    return .newData
}                     
```

### In-App Notifications
To allow for your app to receive custom UI in-app notifications you need to configure your app to properly parse and display them. This is handled by a custom delegate that you set when you initialize the SDK called `InAppDelegate`.
```swift

class CustomInAppDelegate: InAppDelegate {
    func handle(action: InAppAction, context: [String : AnyObject], notification: PostlesNotification) {
        print("PV | Action: \(action) \(context)")
    }
}

Postles.initialize(
    apiKey: apiKey,
    urlEndpoint: urlEndpoint,
    inAppDelegate: CustomInAppDelegate(),
    launchOptions: launchOptions
)
```

This delegate contains three methods that you can configure to help you determine how and when notifications should display.
```swift
public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    func onNew(notification: PostlesNotification) -> InAppDisplayState
    func handle(action: InAppAction, context: [String: Any], notification: PostlesNotification)
    func onError(error: Error)
}
```
- `autoShow: boolean`: Should notifications automatically display upon receipt and app open
- `onNew(notification: PostlesNotification) -> InAppDisplayState`: When a notification is received (and `autoShow` is true), what should the SDK do? Options are:
    - `show`: Display the notification to the user
    - `skip`: Iterate to the next notification if there is one, otherwise do nothing. This does not mark the notification as read
    - `consume`: Mark the notification as read and never show again
- `handle(action: InAppAction, context: [String: Any], notification: PostlesNotification)`: Triggered when an action is taken inside of a notification. Possible actions are:
    - `close`: Triggered to dismiss and consume a displayed notification
    - `custom`: Triggered with custom data for the app to utilize
- `onError(error: Error)`: Provide errors if any have been encountered

If you would like to manually handle showing notifications, this can be achieved by turning `autoShow` to false and then calling `Postles.shared.showLatestNotification()`

### Preference Center
Let users manage which subscriptions they belong to without building any UI of your own. `getSubscriptions()` returns the project's public subscriptions along with the current user's state for each, and `setSubscription(id:state:)` (or the `subscribe`/`unsubscribe` helpers) flips a single subscription. The user must be identified first (via `identify`).

```swift
// Read the current preferences
let page = try await Postles.shared.getSubscriptions()
for preference in page.results {
    print(preference.name, preference.channel, preference.state)
}

// Update a preference
try await Postles.shared.unsubscribe(id: 123)
try await Postles.shared.subscribe(id: 123)

// Or set an explicit state
try await Postles.shared.setSubscription(id: 123, state: .unsubscribed)
```

#### Subscription Methods
- `getSubscriptions() async throws -> Page<SubscriptionPreference>`: Returns a page of the user's subscription preferences
- `setSubscription(id: Int, state: SubscriptionState) async throws`: Set a subscription to `.subscribed` or `.unsubscribed`
- `subscribe(id: Int) async throws`: Subscribe the user to a subscription
- `unsubscribe(id: Int) async throws`: Unsubscribe the user from a subscription

#### Helper Methods
- `getNofications() async throws -> Page<PostlesNotification>`: Returns a page of notifications
- `showLatestNotification() async`: Display the latest notification to the user
- `show(notification: PostlesNotification) async`: Display a provided notification to the user
- `consume(notification: PostlesNotification) async`: Mark a notification as being read
- `dismiss(notification: PostlesNotification) async`: Dismiss a notification if it is being displayed and mark it as being read

#### Handling In-App Actions
The SDK handles actions in a couple of different ways. At its simplest, to close a notification you can use the `postles://dismiss` deeplink.

If you'd like to pass information from the in-app notification to the app (for example based on what button they click, etc) you can use the JS trigger `window.custom(obj)` or use any other deeplink using the `postles://` scheme such as `postles://special/custom`

### Deeplink & Universal Link Navigation
To allow for click tracking links in emails can be click-wrapped in a Postles url that then needs to be unwrapped for navigation purposes. For information on setting this up on your platform, please see our [deeplink documentation](https://docs.postles.app/advanced/deeplinking).

Postles includes a method which checks to see if a given URL is a Postles URL and if so, unwraps the url, triggers the unwrapped URL and calls the Postles API to register that the URL was executed.

To start using deeplinking in your app, add your Postles deployment URL as an Associated Domain to your app. To do so, navigate to Project -> Target -> Select your primary target -> Signing & Capabilities. From there, scroll down to Associated Domains and hit the plus button. Enter the domain in the format `applinks:YOURDOMAIN.com` i.e. `applinks:postles.app`.

Next, you'll need to update your apps code to support unwrapping the Postles URLs that open your app. To do so, use the `handle(universalLink: URL)` method. In your app delegate's `application(_:continue:restorationHandler:)` method, unwrap the URL and pass it to the handler:

```swift
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

    guard let url = userActivity.webpageURL else {
        return false
    }

    return Postles.shared.handle(universalLink: url)
}
```

Postles links will now be automatically read and opened in your application.

## Example

Explore our [example project](/Example) which includes basic usage.
