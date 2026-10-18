import XCTest
@testable import CommuteLogger

final class CommuteAnalyticsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func trip(day: Int, leave: Int, minutes: Double, causes: [DelayCause] = []) -> CommuteSample {
        let departure = calendar.date(from: DateComponents(year: 2025, month: 9, day: day, hour: leave / 60, minute: leave % 60))!
        return CommuteSample(direction: .toWork, departure: departure, arrival: departure.addingTimeInterval(minutes * 60), causes: causes)
    }

    func testPercentileInterpolates() {
        XCTAssertEqual(CommuteAnalytics.percentile([10, 20, 30, 40], 0.5), 25)
        XCTAssertEqual(CommuteAnalytics.percentile([5], 0.9), 5)
        XCTAssertNil(CommuteAnalytics.percentile([], 0.5))
    }

    func testStatsAndDelayLevels() {
        let samples = [30, 31, 29, 30, 32, 52, 37].enumerated().map { trip(day: $0.offset + 1, leave: 480, minutes: Double($0.element)) }
        let analytics = CommuteAnalytics(samples: samples, direction: .toWork, calendar: calendar)
        let stats = try! XCTUnwrap(analytics.stats)
        XCTAssertEqual(stats.count, 7)
        XCTAssertEqual(stats.median, 31 * 60)
        XCTAssertEqual(stats.severeCount, 1) // 52 is 21 min over typical
        XCTAssertEqual(stats.minorCount, 1) // 37 is 6 min over
        XCTAssertEqual(stats.best, 29 * 60)
        XCTAssertEqual(stats.worst, 52 * 60)
    }

    func testOtherDirectionIsExcluded() {
        var home = trip(day: 1, leave: 1050, minutes: 90)
        home.direction = .toHome
        let analytics = CommuteAnalytics(samples: [trip(day: 1, leave: 480, minutes: 30), home], direction: .toWork, calendar: calendar)
        XCTAssertEqual(analytics.samples.count, 1)
    }

    func testLeaveByUsesOverallWhenSlotsAreSparse() {
        let samples = (1...10).map { trip(day: $0, leave: 450 + $0 * 7, minutes: Double(30 + $0)) }
        let analytics = CommuteAnalytics(samples: samples, direction: .toWork, reliability: 0.9, calendar: calendar)
        let rec = try! XCTUnwrap(analytics.leaveBy(arriveByMinutes: 540))
        XCTAssertEqual(rec.basis, .overall)
        // 90th percentile of 31...40 is 39.1 min -> plan 40 min -> leave by 8:20.
        XCTAssertEqual(rec.leaveAtMinutes, 540 - 40)
        XCTAssertEqual(rec.historicalOnTime, 10)
    }

    func testLeaveByAccountsForRushHour() {
        // Leaving at 7:30 takes ~25 min; leaving at 8:15 takes ~45 min.
        var samples: [CommuteSample] = []
        for day in 1...5 {
            samples.append(trip(day: day, leave: 450, minutes: 24 + Double(day % 3)))
            samples.append(trip(day: day + 7, leave: 495, minutes: 44 + Double(day % 3)))
        }
        let analytics = CommuteAnalytics(samples: samples, direction: .toWork, reliability: 0.9, calendar: calendar)
        let rec = try! XCTUnwrap(analytics.leaveBy(arriveByMinutes: 540))
        XCTAssertEqual(rec.basis, .departureTime)
        // The 8:15 slot's bad day (~46 min) would arrive 9:01, so the 7:30 slot wins and you can leave as late as 7:44.
        XCTAssertEqual(rec.leaveAtMinutes, 464)
    }

    func testNoLeaveByWithTooFewTrips() {
        let analytics = CommuteAnalytics(samples: [trip(day: 1, leave: 480, minutes: 30)], direction: .toWork, calendar: calendar)
        XCTAssertNil(analytics.leaveBy(arriveByMinutes: 540))
    }

    func testCauseImpactsRankByFrequency() {
        let samples = [
            trip(day: 1, leave: 480, minutes: 30),
            trip(day: 2, leave: 480, minutes: 30),
            trip(day: 3, leave: 480, minutes: 30),
            trip(day: 4, leave: 480, minutes: 50, causes: [.accident]),
            trip(day: 5, leave: 480, minutes: 40, causes: [.traffic]),
            trip(day: 8, leave: 480, minutes: 42, causes: [.traffic]),
        ]
        let impacts = CommuteAnalytics(samples: samples, direction: .toWork, calendar: calendar).causeImpacts()
        XCTAssertEqual(impacts.first?.cause, .traffic)
        XCTAssertEqual(impacts.first?.count, 2)
    }

    func testWeekdayAveragesFollowCalendarOrder() {
        // 1 Sep 2025 is a Monday.
        let samples = [trip(day: 1, leave: 480, minutes: 40), trip(day: 5, leave: 480, minutes: 25), trip(day: 2, leave: 480, minutes: 30)]
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let days = CommuteAnalytics(samples: samples, direction: .toWork, calendar: mondayFirst).weekdayAverages()
        XCTAssertEqual(days.map(\.weekday), [2, 3, 6])
        XCTAssertEqual(days.first?.mean, 40 * 60)
    }

    func testSampleDataProducesUsefulDashboard() {
        let samples = SampleData.generate(weeks: 8, now: Date(timeIntervalSince1970: 1_760_000_000), calendar: calendar)
        let analytics = CommuteAnalytics(samples: samples, direction: .toWork, calendar: calendar)
        XCTAssertGreaterThan(analytics.samples.count, 30)
        XCTAssertNotNil(analytics.leaveBy(arriveByMinutes: 540))
        XCTAssertFalse(analytics.insights(now: Date(timeIntervalSince1970: 1_760_000_000)).isEmpty)
    }
}
