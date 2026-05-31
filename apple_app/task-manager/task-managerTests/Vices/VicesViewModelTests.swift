import Foundation
import Testing
@testable import task_manager

@MainActor
struct VicesViewModelTests {
    @Test func tappingViceCardLogsOneEventAndUpdatesSummary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 12))!
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let viewModel = VicesViewModel(
            viceRepository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)

        #expect(viewModel.summaries.first?.todayCount == 1)
        #expect(viewModel.pendingUndoLogID != nil)
        #expect(viewModel.pendingUndoViceName == "Dab Pen")
    }

    @Test func undoWithinWindowDeletesNewLog() {
        let now = Date(timeIntervalSince1970: 2_000)
        let vice = Vice(name: "Alcohol", unitLabel: "Drinks")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let viewModel = VicesViewModel(
            viceRepository: repository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)
        let logCountBeforeUndo = viewModel.logs.count
        viewModel.undoLastLog()

        #expect(logCountBeforeUndo == 1)
        #expect(viewModel.logs.isEmpty)
        #expect(viewModel.pendingUndoLogID == nil)
    }

    @Test func undoExpiresAfterFiveSeconds() async {
        let now = Date(timeIntervalSince1970: 3_000)
        let vice = Vice(name: "Social Media", unitLabel: "Sessions")
        let repository = InMemoryViceRepository(vices: [vice], logs: [])
        let viewModel = VicesViewModel(
            viceRepository: repository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.logViceHit(viceID: vice.id)
        #expect(viewModel.pendingUndoLogID != nil)

        try? await Task.sleep(nanoseconds: 5_300_000_000)

        #expect(viewModel.pendingUndoLogID == nil)
        #expect(viewModel.logs.count == 1)
    }
}

@MainActor
private final class InMemoryViceRepository: ViceRepository {
    var vices: [Vice]
    var logs: [ViceLog]

    init(vices: [Vice], logs: [ViceLog]) {
        self.vices = vices
        self.logs = logs
    }

    func fetchVices(includeArchived: Bool) throws -> [Vice] {
        let values = includeArchived ? vices : vices.filter { $0.isArchived == false }
        return values.sortedForVices()
    }

    func vice(withID id: UUID) throws -> Vice? {
        vices.first { $0.id == id }
    }

    func saveVice(_ vice: Vice, replacingViceWithID originalID: UUID?) throws {
        let targetID = originalID ?? vice.id
        if let index = vices.firstIndex(where: { $0.id == targetID || $0.id == vice.id }) {
            vices[index] = vice
        } else {
            vices.append(vice)
        }
    }

    func archiveVice(withID id: UUID, archivedAt: Date) throws {
        guard let index = vices.firstIndex(where: { $0.id == id }) else {
            return
        }

        vices[index].isArchived = true
        vices[index].updatedAt = archivedAt
    }

    func fetchViceLogs() throws -> [ViceLog] {
        logs.sortedForViceLogs()
    }

    func fetchViceLogs(for viceID: UUID, from startDate: Date, to endDate: Date) throws -> [ViceLog] {
        logs.filter { log in
            log.viceID == viceID && log.timestamp >= startDate && log.timestamp <= endDate
        }
    }

    func saveViceLog(_ log: ViceLog) throws {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
    }

    func deleteViceLog(withID id: UUID) throws {
        logs.removeAll { $0.id == id }
    }
}
