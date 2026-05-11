import Foundation

struct SyncDeviceIdentity: Codable, Equatable, Sendable {
    var id: UUID
    var displayName: String
    var createdAt: Date

    static func newDevice(displayName: String, now: Date = .now) -> SyncDeviceIdentity {
        SyncDeviceIdentity(id: UUID(), displayName: displayName, createdAt: now)
    }
}
