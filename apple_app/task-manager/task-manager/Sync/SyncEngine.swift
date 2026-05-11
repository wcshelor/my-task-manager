import Foundation

@MainActor
struct SyncEngine {
    // Planned orchestration:
    // 1. Read manifest and remote device cursors from the selected folder.
    // 2. Pull unapplied immutable change batches.
    // 3. Write a compact pre-merge backup.
    // 4. Merge remote changes into SwiftData through repository protocols.
    // 5. Push local unsynced changes as a new device-owned batch.
    // 6. Pull once more to catch changes that arrived during the push.
    // 7. Update SyncStateRecord and user-visible SyncStatus.

    func run(reason: SyncReason) async throws -> SyncStatus {
        // Stubbed until the export/import, folder access, and merge machinery exists.
        .idle(lastSyncAt: nil)
    }
}
