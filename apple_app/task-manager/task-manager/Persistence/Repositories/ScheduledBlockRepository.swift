import Foundation

@MainActor
protocol ScheduledBlockRepository {
    func fetchScheduledBlocks() throws -> [ScheduledBlock]
    func fetchScheduledBlocks(for taskID: UUID) throws -> [ScheduledBlock]
    func saveScheduledBlock(_ block: ScheduledBlock, replacingBlockWithID originalID: UUID?) throws
    func deleteScheduledBlock(withID id: UUID) throws
}
