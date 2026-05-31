import Foundation
import Testing
@testable import task_manager

struct SwiftDataViceRepositoryTests {
    @Test @MainActor func repositoryRoundTripsViceAndLogs() throws {
        let repository = try makeRepository()
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let log = ViceLog(
            viceID: vice.id,
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveVice(vice, replacingViceWithID: nil)
        try repository.saveViceLog(log)

        #expect(try repository.vice(withID: vice.id) == vice)
        #expect(try repository.fetchVices(includeArchived: false) == [vice])
        #expect(try repository.fetchViceLogs() == [log])
    }

    @Test @MainActor func repositoryArchivesViceAndFiltersActiveList() throws {
        let repository = try makeRepository()
        let vice = Vice(name: "Alcohol", unitLabel: "Drinks")

        try repository.saveVice(vice, replacingViceWithID: nil)
        try repository.archiveVice(withID: vice.id, archivedAt: Date(timeIntervalSince1970: 2_000))

        #expect(try repository.fetchVices(includeArchived: false).isEmpty)
        #expect(try repository.fetchVices(includeArchived: true).first?.isArchived == true)
    }

    @Test @MainActor func repositoryFetchesLogsInWindowAndDeletesLog() throws {
        let repository = try makeRepository()
        let vice = Vice(name: "Social Media", unitLabel: "Sessions")
        let start = Date(timeIntervalSince1970: 5_000)
        let inWindow = ViceLog(viceID: vice.id, timestamp: start.addingTimeInterval(120))
        let outWindow = ViceLog(viceID: vice.id, timestamp: start.addingTimeInterval(10_000))

        try repository.saveVice(vice, replacingViceWithID: nil)
        try repository.saveViceLog(inWindow)
        try repository.saveViceLog(outWindow)

        let filtered = try repository.fetchViceLogs(
            for: vice.id,
            from: start,
            to: start.addingTimeInterval(3_600)
        )
        #expect(filtered == [inWindow])

        try repository.deleteViceLog(withID: inWindow.id)
        #expect(try repository.fetchViceLogs().contains(inWindow) == false)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataViceRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataViceRepository(modelContainer: container)
    }
}
