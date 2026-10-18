import XCTest
@testable import CommuteLogger

final class CommuteDetectorTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    /// Wednesday 15 Oct 2025 at the given time.
    private func wednesday(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: 10, day: 15, hour: hour, minute: minute))!
    }

    private func loggedTrips(_ actions: [DetectorAction]) -> [CompletedTrip] {
        actions.compactMap { action -> CompletedTrip? in
            if case let .log(trip) = action { return trip }
            return nil
        }
    }

    func testLeavingHomeAndReachingWorkLogsACommute() {
        var detector = CommuteDetector()
        let start = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        XCTAssertEqual(start, [.startRecording(.toWork, origin: .home)])

        let end = detector.handle(.entered(.work, at: wednesday(8, 34)), calendar: calendar)
        let trip = try! XCTUnwrap(loggedTrips(end).first)
        XCTAssertEqual(trip.direction, .toWork)
        XCTAssertEqual(trip.duration, 34 * 60)
        XCTAssertNil(detector.pending)
    }

    func testLeavingWorkLogsTripHome() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.work, at: wednesday(17, 30)), calendar: calendar)
        let trip = loggedTrips(detector.handle(.entered(.home, at: wednesday(18, 5)), calendar: calendar)).first
        XCTAssertEqual(trip?.direction, .toHome)
    }

    func testWeekendTripsAreIgnored() {
        var detector = CommuteDetector()
        let saturday = calendar.date(from: DateComponents(year: 2025, month: 10, day: 18, hour: 9))!
        XCTAssertEqual(detector.handle(.exited(.home, at: saturday), calendar: calendar), [])
        XCTAssertNil(detector.pending)
    }

    func testReturningHomeDiscardsTheTrip() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        let actions = detector.handle(.entered(.home, at: wednesday(8, 6)), calendar: calendar)
        XCTAssertTrue(loggedTrips(actions).isEmpty)
        XCTAssertTrue(actions.contains(.stopRecording))
        XCTAssertNil(detector.pending)
    }

    func testTripThatNeverArrivesExpires() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        XCTAssertEqual(detector.handle(.tick(wednesday(9, 0)), calendar: calendar), [])
        let actions = detector.handle(.tick(wednesday(11, 30)), calendar: calendar)
        XCTAssertTrue(actions.contains(.stopRecording))
        XCTAssertNil(detector.pending)
    }

    func testTooShortTripIsDiscarded() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        let actions = detector.handle(.entered(.work, at: wednesday(8, 1)), calendar: calendar)
        XCTAssertTrue(loggedTrips(actions).isEmpty)
    }

    func testVisitDepartureMovesStartToTheDoor() {
        var detector = CommuteDetector()
        // The geofence fires a few minutes after you actually walked out.
        _ = detector.handle(.exited(.home, at: wednesday(8, 4)), calendar: calendar)
        _ = detector.handle(.visitEnded(.home, at: wednesday(8, 0)), calendar: calendar)
        XCTAssertEqual(detector.pending?.departure, wednesday(8, 0))
    }

    func testEarlierVisitDepartureIsUsedWhenGeofenceFiresLater() {
        var detector = CommuteDetector()
        _ = detector.handle(.visitEnded(.home, at: wednesday(7, 58)), calendar: calendar)
        _ = detector.handle(.exited(.home, at: wednesday(8, 3)), calendar: calendar)
        XCTAssertEqual(detector.pending?.departure, wednesday(7, 58))
    }

    func testVisitArrivalRefinesLoggedTrip() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        let trip = loggedTrips(detector.handle(.entered(.work, at: wednesday(8, 30)), calendar: calendar)).first!
        // Parking and walking in took a few more minutes.
        let actions = detector.handle(.visitStarted(.work, at: wednesday(8, 36)), calendar: calendar)
        XCTAssertEqual(actions, [.refine(id: trip.id, departure: nil, arrival: wednesday(8, 36))])
    }

    func testManualTripFinishesOnArrival() {
        var detector = CommuteDetector()
        _ = detector.handle(.manualStart(.toWork, at: wednesday(8, 0)), calendar: calendar)
        let trip = loggedTrips(detector.handle(.entered(.work, at: wednesday(8, 40)), calendar: calendar)).first
        XCTAssertEqual(trip?.isManual, true)
    }

    func testRoutePointsAreCollectedAndMeasured() {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        let points = [
            RoutePoint(latitude: 42.3400, longitude: -71.0900, timestamp: wednesday(8, 1), speed: 10),
            RoutePoint(latitude: 42.3490, longitude: -71.0900, timestamp: wednesday(8, 3), speed: 10), // ~1 km
            RoutePoint(latitude: 42.3491, longitude: -71.0900, timestamp: wednesday(8, 8), speed: 0), // stuck 5 min
        ]
        for point in points { _ = detector.handle(.location(point), calendar: calendar) }
        let trip = loggedTrips(detector.handle(.entered(.work, at: wednesday(8, 20)), calendar: calendar)).first!
        XCTAssertEqual(trip.points.count, 3)
        XCTAssertEqual(TripMetrics.distance(of: trip.points), 1012, accuracy: 15)
        XCTAssertEqual(TripMetrics.stationarySeconds(of: trip.points), 300, accuracy: 1)
    }

    func testDetectorStateSurvivesRelaunch() throws {
        var detector = CommuteDetector()
        _ = detector.handle(.exited(.home, at: wednesday(8, 0)), calendar: calendar)
        let restored = try JSONDecoder().decode(CommuteDetector.self, from: JSONEncoder().encode(detector))
        XCTAssertEqual(restored.pending, detector.pending)
    }
}
