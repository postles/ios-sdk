import XCTest
@testable import Postles

final class TopicTests: XCTestCase {

    private let channelsJson = """
    {
      "channels": [
        {
          "channel": "text",
          "label": "All Text Messages",
          "master": { "subscription_id": 1, "name": "All Text Messages", "channel": "text", "kind": "channel", "is_opt_in": false, "state": "unsubscribed" },
          "topics": [ { "subscription_id": 11, "name": "Daily Recap", "channel": "text", "kind": "topic", "is_opt_in": true, "state": "not_opted_in" } ],
          "paused": true,
          "can_resubscribe": false,
          "resubscribe_text_number": "+1 312 555 0100"
        }
      ]
    }
    """

    private let legacyRowJson = """
    { "subscription_id": 7, "name": "Weekly Digest", "channel": "email", "state": "subscribed" }
    """

    private let lockedErrorJson = """
    { "status": "error", "error": "Text messages can only be turned back on by replying START from your phone.", "code": 4004 }
    """

    func testDecodesChannelsResponse() throws {
        let list = try JSONDecoder.postles.decode(TopicChannelList.self, from: Data(channelsJson.utf8))

        let channel = try XCTUnwrap(list.channels.first)
        XCTAssertEqual(channel.channel, "text")
        XCTAssertEqual(channel.label, "All Text Messages")
        XCTAssertTrue(channel.paused)
        XCTAssertFalse(channel.canResubscribe)
        XCTAssertEqual(channel.resubscribeTextNumber, "+1 312 555 0100")

        let master = try XCTUnwrap(channel.master)
        XCTAssertEqual(master.subscriptionId, 1)
        XCTAssertEqual(master.kind, .channel)
        XCTAssertFalse(master.isOptIn)
        XCTAssertEqual(master.state, .unsubscribed)

        let topic = try XCTUnwrap(channel.topics.first)
        XCTAssertEqual(topic.subscriptionId, 11)
        XCTAssertEqual(topic.kind, .topic)
        XCTAssertTrue(topic.isOptIn)
        XCTAssertEqual(topic.state, .notOptedIn)
    }

    func testDecodesRowWithoutKindOrOptIn() throws {
        let topic = try JSONDecoder.postles.decode(Topic.self, from: Data(legacyRowJson.utf8))

        XCTAssertEqual(topic.subscriptionId, 7)
        XCTAssertEqual(topic.kind, .topic)
        XCTAssertFalse(topic.isOptIn)
        XCTAssertEqual(topic.state, .subscribed)
    }

    @available(*, deprecated)
    func testNotOptedInReadsAsUnsubscribedThroughAlias() throws {
        let list = try JSONDecoder.postles.decode(TopicChannelList.self, from: Data(channelsJson.utf8))
        let topic = try XCTUnwrap(list.channels.first?.topics.first)

        XCTAssertEqual(SubscriptionPreference(topic: topic).state, .unsubscribed)
    }

    func testLockedResubscribeBodyMapsToTypedError() throws {
        let error = NetworkManager.error(body: Data(lockedErrorJson.utf8))

        guard case PostlesError.resubscribeLocked(let message) = error else {
            return XCTFail("expected resubscribeLocked, got \(error)")
        }
        XCTAssertEqual(message, "Text messages can only be turned back on by replying START from your phone.")
    }
}
