import Foundation

@MainActor
protocol DebriefRepository {
    func fetchDebriefs() throws -> [CalendarDebriefRecord]
    func debrief(withID id: UUID) throws -> CalendarDebriefRecord?
    func debrief(withEventKey eventKey: String) throws -> CalendarDebriefRecord?
    func saveDebrief(_ debrief: CalendarDebriefRecord, replacingDebriefWithID originalID: UUID?) throws
    func deleteDebrief(withID id: UUID) throws
}
