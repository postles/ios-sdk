import XCTest
@testable import Postles

final class EventTests: XCTestCase {

    private let network = NetworkManager(config: Config(apiKey: "pk_test", urlEndpoint: "https://postles.test", inAppDelegate: nil))

    private func sentEvent(geo: EventLocation?) throws -> [String: Any] {
        let event = Event(name: "opened", anonymousId: "anon-1", externalId: nil, data: [:], geo: geo)
        let body = try XCTUnwrap(network.request(path: "events", method: "POST", object: [event]).httpBody)
        let events = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        return try XCTUnwrap(events.first)
    }

    func testGeoIsOmittedNullOrSentAsGiven() throws {
        XCTAssertFalse(try sentEvent(geo: nil).keys.contains("geo"))

        let cleared = try sentEvent(geo: .noLocation)
        XCTAssertTrue(cleared.keys.contains("geo"))
        XCTAssertTrue(cleared["geo"] is NSNull)

        let located = try sentEvent(geo: .location(Geo(country: "US", region: "IL", city: "Chicago")))
        XCTAssertEqual(located["geo"] as? [String: String], ["country": "US", "region": "IL", "city": "Chicago"])
    }
}
