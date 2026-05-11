import Foundation

enum SyncStatus: Equatable, Sendable {
    case disabled
    case idle(lastSyncAt: Date?)
    case syncing(reason: SyncReason)
    case failed(message: String, lastSyncAt: Date?)
}
