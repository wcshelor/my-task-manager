import Foundation
import SwiftData

@Model
final class ViceLogRecord {
    var id: UUID = UUID()
    var viceID: UUID = UUID()
    var timestamp: Date = Date.distantPast
    var amount: Int = 1

    init(log: ViceLog) {
        update(from: log)
    }

    var log: ViceLog {
        ViceLog(
            id: id,
            viceID: viceID,
            timestamp: timestamp,
            amount: amount
        )
    }

    func update(from log: ViceLog) {
        id = log.id
        viceID = log.viceID
        timestamp = log.timestamp
        amount = log.amount
    }
}
