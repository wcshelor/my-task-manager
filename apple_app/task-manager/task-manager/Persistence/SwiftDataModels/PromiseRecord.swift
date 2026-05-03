import Foundation
import SwiftData

@Model
final class PromiseRecord {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var startAt: Date = Date.distantPast
    var checkInAt: Date = Date.distantPast
    var whyItMatters: String?
    var expectedFriction: String?
    var statusRawValue: String = PromiseStatus.active.rawValue
    var outcomeRawValue: String?
    var reflection: String?
    var parentPromiseID: UUID?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var resolvedAt: Date?

    init(promise: Promise) {
        update(from: promise)
    }

    var promise: Promise {
        Promise(
            id: id,
            title: title,
            notes: notes,
            startAt: startAt,
            checkInAt: checkInAt,
            whyItMatters: whyItMatters,
            expectedFriction: expectedFriction,
            status: PromiseStatus(rawValue: statusRawValue) ?? .active,
            outcome: outcomeRawValue.flatMap(PromiseOutcome.init(rawValue:)),
            reflection: reflection,
            parentPromiseID: parentPromiseID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            resolvedAt: resolvedAt
        )
    }

    func update(from promise: Promise) {
        id = promise.id
        title = promise.title
        notes = promise.notes
        startAt = promise.startAt
        checkInAt = promise.checkInAt
        whyItMatters = promise.whyItMatters
        expectedFriction = promise.expectedFriction
        statusRawValue = promise.status.rawValue
        outcomeRawValue = promise.outcome?.rawValue
        reflection = promise.reflection
        parentPromiseID = promise.parentPromiseID
        createdAt = promise.createdAt
        updatedAt = promise.updatedAt
        resolvedAt = promise.resolvedAt
    }
}
