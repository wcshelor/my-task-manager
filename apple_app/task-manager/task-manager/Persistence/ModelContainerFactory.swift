import SwiftData

enum ModelContainerFactory {
    private static let cloudKitContainerIdentifier = "iCloud.camp.task-manager"

    static func makeDefaultContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    private static func makeContainer(
        isStoredInMemoryOnly: Bool
    ) throws -> ModelContainer {
        let schema = Schema([
            TaskRecord.self,
            ScheduledBlockRecord.self,
            AppSettingsRecord.self,
        ])
        let configuration: ModelConfiguration

        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
        }

        return try ModelContainer(for: schema, configurations: configuration)
    }
}
