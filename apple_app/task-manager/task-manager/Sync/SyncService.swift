import Foundation

@MainActor
protocol SyncServicing {
    var status: SyncStatus { get }

    func syncOnStartupIfEnabled() async
    func syncIfEnabled(reason: SyncReason) async
    func syncNow() async
}

enum SyncReason: String, Codable, Sendable {
    case startup
    case foreground
    case manual
    case timer
}

@MainActor
final class SyncService: SyncServicing {
    private(set) var status: SyncStatus = .disabled

    func syncOnStartupIfEnabled() async {
        await syncIfEnabled(reason: .startup)
    }

    func syncIfEnabled(reason: SyncReason) async {
        // Planned: check saved folder access, acquire a sync lock, then run SyncEngine.
        status = .disabled
    }

    func syncNow() async {
        await syncIfEnabled(reason: .manual)
    }
}
