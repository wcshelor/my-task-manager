import Foundation

struct SyncConflict: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var entityType: String
    var entityID: UUID
    var detectedAt: Date
    var localDeviceID: UUID
    var remoteDeviceID: UUID?
    var summary: String
    var localPayload: [String: String]
    var remotePayload: [String: String]
}
