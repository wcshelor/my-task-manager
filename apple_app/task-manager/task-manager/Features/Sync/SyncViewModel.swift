import Combine
import Foundation

@MainActor
final class SyncViewModel: ObservableObject {
    @Published private(set) var status: SyncStatus

    private let syncService: any SyncServicing

    init(syncService: any SyncServicing) {
        self.syncService = syncService
        self.status = syncService.status
    }

    func syncNow() async {
        await syncService.syncNow()
        status = syncService.status
    }
}
