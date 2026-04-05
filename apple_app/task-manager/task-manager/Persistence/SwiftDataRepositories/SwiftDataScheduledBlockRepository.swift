import Foundation
import SwiftData

@MainActor
final class SwiftDataScheduledBlockRepository: ScheduledBlockRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchScheduledBlocks() throws -> [ScheduledBlock] {
        try fetchAllRecords()
            .map(\.scheduledBlock)
            .sorted { leftBlock, rightBlock in
                if leftBlock.start != rightBlock.start {
                    return leftBlock.start < rightBlock.start
                }

                return leftBlock.id.uuidString < rightBlock.id.uuidString
            }
    }

    func fetchScheduledBlocks(for taskID: UUID) throws -> [ScheduledBlock] {
        try fetchScheduledBlocks().filter { $0.taskID == taskID }
    }

    func saveScheduledBlock(_ block: ScheduledBlock, replacingBlockWithID originalID: UUID?) throws {
        let record =
            try fetchRecord(withID: originalID ?? block.id)
            ?? fetchRecord(withID: block.id)

        if let record {
            record.update(from: block)
        } else {
            modelContext.insert(ScheduledBlockRecord(block: block))
        }

        try modelContext.save()
    }

    func deleteScheduledBlock(withID id: UUID) throws {
        guard let record = try fetchRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchAllRecords() throws -> [ScheduledBlockRecord] {
        try modelContext.fetch(FetchDescriptor<ScheduledBlockRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> ScheduledBlockRecord? {
        try fetchAllRecords().first { $0.id == id }
    }
}
