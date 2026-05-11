import SwiftUI

struct SyncStatusView: View {
    let status: SyncStatus

    var body: some View {
        Label(statusText, systemImage: systemImage)
    }

    private var statusText: String {
        switch status {
        case .disabled:
            return "Folder sync is not configured"
        case .idle(let lastSyncAt):
            guard let lastSyncAt else {
                return "Ready to sync"
            }

            return "Last synced \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))"
        case .syncing:
            return "Syncing"
        case .failed(let message, _):
            return message
        }
    }

    private var systemImage: String {
        switch status {
        case .disabled:
            return "icloud.slash"
        case .idle:
            return "icloud"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.icloud"
        }
    }
}
