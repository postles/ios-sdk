import Foundation

public enum InAppDisplayState {
    case show, skip, consume
}

public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    var useDarkMode: Bool { get }
    func onNew(notification: PostlesNotification) async -> InAppDisplayState
    func didDisplay(notification: PostlesNotification)
    func handle(action: InAppAction, context: [String: Any], notification: PostlesNotification)
    func onError(error: Error, source: Postles.ErrorSource)
}

extension InAppDelegate {
    public var autoShow: Bool { true }
    public var useDarkMode: Bool { false }
    public func onNew(notification: PostlesNotification) async -> InAppDisplayState { .show }
    public func didDisplay(notification: PostlesNotification) {}
    public func onError(error: Error, source: Postles.ErrorSource) {}
}
