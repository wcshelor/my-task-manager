import Foundation
import Testing
@testable import task_manager

struct PromiseModelTests {
    @Test func promiseCleansTextAndPreservesActiveState() {
        let startAt = Date(timeIntervalSince1970: 1_000)
        let checkInAt = Date(timeIntervalSince1970: 2_000)
        let promise = Promise(
            title: "  No weed until 6 PM  ",
            notes: "  Keep it simple  ",
            startAt: startAt,
            checkInAt: checkInAt,
            whyItMatters: "  Trust  ",
            expectedFriction: "  Boredom  "
        )

        #expect(promise.title == "No weed until 6 PM")
        #expect(promise.notes == "Keep it simple")
        #expect(promise.whyItMatters == "Trust")
        #expect(promise.expectedFriction == "Boredom")
        #expect(promise.status == .active)
        #expect(promise.outcome == nil)
        #expect(promise.resolvedAt == nil)
    }

    @Test func promiseCheckInDateDoesNotPrecedeStartDate() {
        let startAt = Date(timeIntervalSince1970: 2_000)
        let checkInAt = Date(timeIntervalSince1970: 1_000)

        let promise = Promise(title: "Stay present", startAt: startAt, checkInAt: checkInAt)

        #expect(promise.checkInAt == startAt)
    }

    @Test func resolvingPromiseStoresOutcomeAndTimestamp() {
        let promise = Promise(
            title: "Stay present",
            startAt: Date(timeIntervalSince1970: 1_000),
            checkInAt: Date(timeIntervalSince1970: 2_000),
            createdAt: Date(timeIntervalSince1970: 500)
        )
        let resolvedAt = Date(timeIntervalSince1970: 3_000)

        let resolvedPromise = promise.resolved(
            outcome: .missed,
            reflection: "Caved when bored",
            resolvedAt: resolvedAt
        )

        #expect(resolvedPromise.status == .resolved)
        #expect(resolvedPromise.outcome == .missed)
        #expect(resolvedPromise.reflection == "Caved when bored")
        #expect(resolvedPromise.resolvedAt == resolvedAt)
        #expect(resolvedPromise.updatedAt == resolvedAt)
    }
}
