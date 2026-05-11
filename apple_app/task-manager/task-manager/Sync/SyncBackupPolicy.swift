import Foundation

struct SyncBackupPolicy: Equatable, Sendable {
    var recentBackupLimit: Int
    var dailyBackupLimit: Int

    static let conservativeDefault = SyncBackupPolicy(
        recentBackupLimit: 10,
        dailyBackupLimit: 30
    )
}
