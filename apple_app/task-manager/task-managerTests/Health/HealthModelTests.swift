import Foundation
import Testing
@testable import task_manager

struct HealthModelTests {
    @Test func sleepCheckInCleansAndClampsValues() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!

        let checkIn = SleepCheckIn(
            day: date,
            sleepDurationMinutes: -15,
            sleepQualityRating: 8,
            tirednessRating: 0,
            energyRating: 3,
            contextTags: [.stress, .caffeine, .stress],
            notes: "  Woke up twice  ",
            calendar: calendar
        )

        #expect(checkIn.day == calendar.startOfDay(for: date))
        #expect(checkIn.sleepDurationMinutes == 0)
        #expect(checkIn.sleepQualityRating == 5)
        #expect(checkIn.tirednessRating == 1)
        #expect(checkIn.energyRating == 3)
        #expect(checkIn.contextTags == [.caffeine, .stress])
        #expect(checkIn.notes == "Woke up twice")
        #expect(checkIn.isForSameDay(as: date, calendar: calendar))
    }

    @Test func mealLogCleansSummaryAndSortsNewestFirst() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let base = Date(timeIntervalSince1970: 1_000)
        let older = MealLog(
            id: secondID,
            timestamp: base,
            mealType: .lunch,
            summary: "  Rice bowl  ",
            tags: [.takeout, .protein, .takeout],
            energyAfterRating: 9,
            notes: "  good  "
        )
        let newer = MealLog(
            id: firstID,
            timestamp: base.addingTimeInterval(60),
            summary: "Smoothie"
        )

        #expect(older.summary == "Rice bowl")
        #expect(older.tags == [.takeout, .protein])
        #expect(older.energyAfterRating == 5)
        #expect(older.notes == "good")
        #expect(MealLog(newSummary: "  ") == nil)
        #expect([older, newer].sortedForHealthHistory().map(\.id) == [firstID, secondID])
    }

    @Test func workoutLogClampsDurationAndSortsNewestFirst() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let base = Date(timeIntervalSince1970: 1_000)
        let older = WorkoutLog(
            id: secondID,
            timestamp: base,
            workoutType: .strength,
            durationMinutes: -20,
            intensityRating: 9,
            energyBeforeRating: 0,
            energyAfterRating: 4,
            notes: "  Deadlifts  "
        )
        let newer = WorkoutLog(
            id: firstID,
            timestamp: base.addingTimeInterval(60),
            workoutType: .walk
        )

        #expect(older.durationMinutes == 0)
        #expect(older.intensityRating == 5)
        #expect(older.energyBeforeRating == 1)
        #expect(older.energyAfterRating == 4)
        #expect(older.notes == "Deadlifts")
        #expect([older, newer].sortedForHealthHistory().map(\.id) == [firstID, secondID])
    }

    @Test func pvtSessionCleansValuesAndComputesMetrics() {
        let session = PVTSession(
            durationSeconds: -30,
            reactionTimesMilliseconds: [400, -20, 500, 200],
            falseStartCount: -2,
            missCount: -1,
            notes: "  distracted  "
        )

        #expect(session.durationSeconds == 0)
        #expect(session.reactionTimesMilliseconds == [400, 500, 200])
        #expect(session.falseStartCount == 0)
        #expect(session.missCount == 0)
        #expect(session.notes == "distracted")
        #expect(session.responseCount == 3)
        #expect(session.averageReactionMilliseconds == 1_100.0 / 3.0)
        #expect(session.medianReactionMilliseconds == 400)
        #expect(session.lapseCount == 1)
    }

    @Test func pvtSessionsSortAndKeepLatestSessionPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: morning)!
        let morningSession = PVTSession(id: secondID, startedAt: morning, reactionTimesMilliseconds: [350])
        let afternoonSession = PVTSession(id: firstID, startedAt: afternoon, reactionTimesMilliseconds: [300])
        let yesterdaySession = PVTSession(id: thirdID, startedAt: yesterday, reactionTimesMilliseconds: [400])

        #expect(
            [morningSession, yesterdaySession, afternoonSession]
                .sortedForHealthHistory()
                .map(\.id) == [firstID, secondID, thirdID]
        )
        #expect(
            [morningSession, yesterdaySession, afternoonSession]
                .latestSessionPerDay(calendar: calendar)
                .map(\.id) == [firstID, thirdID]
        )
    }

    @Test func healthTrendSummaryUsesLatestPVTSessionPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 18))!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!
        let morningSession = PVTSession(startedAt: morning, reactionTimesMilliseconds: [500, 600, 700])
        let afternoonSession = PVTSession(startedAt: afternoon, reactionTimesMilliseconds: [200, 300, 400])
        let summary = HealthTrendSummary(
            sleepCheckIns: [],
            pvtSessions: [morningSession, afternoonSession],
            mealLogs: [],
            workoutLogs: [],
            now: now,
            calendar: calendar
        )

        #expect(summary.sleepPVT.current7Days.pvtDaysLogged == 1)
        #expect(summary.sleepPVT.current7Days.averagePVTMedianMilliseconds == 300)
    }
}
