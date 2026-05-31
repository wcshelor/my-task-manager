import Foundation
import SwiftData

@MainActor
final class SwiftDataDebriefRepository: DebriefRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchDebriefs() throws -> [CalendarDebriefRecord] {
        try fetchAllRecords()
            .map(\.debrief)
            .sorted { lhs, rhs in
                if lhs.endDateSnapshot != rhs.endDateSnapshot {
                    return lhs.endDateSnapshot > rhs.endDateSnapshot
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    func debrief(withID id: UUID) throws -> CalendarDebriefRecord? {
        try fetchRecord(withID: id)?.debrief
    }

    func debrief(withEventKey eventKey: String) throws -> CalendarDebriefRecord? {
        try fetchAllRecords().first { $0.eventKey == eventKey }?.debrief
    }

    func saveDebrief(
        _ debrief: CalendarDebriefRecord,
        replacingDebriefWithID originalID: UUID?
    ) throws {
        let record =
            try fetchRecord(withID: originalID ?? debrief.id)
            ?? fetchRecord(withID: debrief.id)
            ?? fetchRecord(withEventKey: debrief.eventKey)

        if let record {
            record.update(from: debrief)
        } else {
            modelContext.insert(CalendarDebriefRecordModel(debrief: debrief))
        }

        try modelContext.save()
    }

    func deleteDebrief(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [CalendarDebriefRecordModel] {
        try modelContext.fetch(FetchDescriptor<CalendarDebriefRecordModel>())
    }

    private func fetchRecord(withID id: UUID) throws -> CalendarDebriefRecordModel? {
        try fetchAllRecords().first { $0.id == id }
    }

    private func fetchRecord(withEventKey eventKey: String) throws -> CalendarDebriefRecordModel? {
        try fetchAllRecords().first { $0.eventKey == eventKey }
    }
}
