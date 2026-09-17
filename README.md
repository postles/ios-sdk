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
Read and modify a user's topic preferences directly through SDK methods. No UI is included, so you can build your own preference center (or manage preferences programmatically). The user must be identified first (via `identify`).

`getTopicChannels()` returns one section per channel, already grouped the way a preference center renders it: the channel's master switch, the topics nested under it, whether those topics are paused because the master is off, and whether the master can be turned back on from the app. `setTopics(_:)` then saves the whole screen in a single request.

Render a section as follows. Show the nested topic toggles only when the channel has more than one topic or any opt-in topic, otherwise the channel toggle is the whole story. While the channel is `paused`, its topics are disabled and keep their last value. When `canResubscribe` is false, consent has to come from the handset, so show a notice with `resubscribeTextNumber` instead of a control.

```swift
let channels = try await Postles.shared.getTopicChannels()

for channel in channels {
    if let master = channel.master {
        if channel.canResubscribe {
            addToggle(title: channel.label, isOn: master.state == .subscribed, id: master.subscriptionId)
        } else {
            addNotice("Text messages are turned off. To turn them back on, text START to \(channel.resubscribeTextNumber ?? "our number").")
        }
    }

    if channel.topics.count > 1 || channel.topics.contains(where: { $0.isOptIn }) {
        for topic in channel.topics {
            addToggle(title: topic.name, isOn: topic.state == .subscribed, id: topic.subscriptionId, enabled: !channel.paused)
        }
    }
}
```

Saving submits every channel master that is not locked, plus only the topics whose master was on when the screen rendered. A paused topic is left out entirely, otherwise it would read as unticked and opt the user out behind their back.

```swift
var updates: [TopicUpdate] = []

for channel in channels {
    if let master = channel.master, channel.canResubscribe {
        updates.append(TopicUpdate(subscriptionId: master.subscriptionId, state: isOn(master.subscriptionId) ? .subscribed : .unsubscribed))
    }
    guard !channel.paused else { continue }
    for topic in channel.topics {
        updates.append(TopicUpdate(subscriptionId: topic.subscriptionId, state: isOn(topic.subscriptionId) ? .subscribed : .unsubscribed))
    }
}

try await Postles.shared.setTopics(updates)
```

A single toggle can also be flipped on its own. Turning a channel master back on where consent must come from the handset throws `PostlesError.resubscribeLocked`, so branch on it and show the message the API returned:

```swift
do {
    try await Postles.shared.subscribeTopic(id: 1)
} catch PostlesError.resubscribeLocked(let message) {
    addNotice(message)
}
```

#### Topic Methods
- `getTopicChannels() async throws -> [TopicChannel]`: Returns the user's topics grouped into one section per channel
- `getTopics(cursor: String?) async throws -> Page<Topic>`: Returns a flat page of the user's topics, masters included
- `setTopics(_ updates: [TopicUpdate]) async throws`: Saves up to 100 topics in one request
- `setTopic(id: Int, state: TopicState) async throws`: Set a single topic to `.subscribed` or `.unsubscribed`
- `subscribeTopic(id: Int) async throws`: Subscribe the user to a topic
- `unsubscribeTopic(id: Int) async throws`: Unsubscribe the user from a topic

A `Topic` carries a `kind` of `.channel` (the per-channel master switch) or `.topic`, and a `state` of `.subscribed`, `.unsubscribed` or `.notOptedIn`. `.notOptedIn` appears only on opt-in topics the user has never chosen and is never sent back on a save.

#### Migrating from subscription names
Subscriptions were renamed to topics. The old names still work and behave the same, but they are deprecated and will be removed in a future release.

| Old name | New name |
|---|---|
| `getSubscriptions(cursor:)` | `getTopicChannels()` or `getTopics(cursor:)` |
| `setSubscription(id:state:)` | `setTopic(id:state:)` |
| `subscribe(id:)` | `subscribeTopic(id:)` |
| `unsubscribe(id:)` | `unsubscribeTopic(id:)` |
| `SubscriptionPreference` | `Topic` |
| `SubscriptionState` | `TopicState` |

`SubscriptionState` has no `.notOptedIn` case, so a topic the user has never opted in to reads as `.unsubscribed` through the old names. Move to `TopicState` to tell the two apart.

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
