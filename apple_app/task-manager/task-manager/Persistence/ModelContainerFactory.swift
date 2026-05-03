import SwiftData

enum ModelContainerFactory {
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
            PromiseRecord.self,
            RoutineRecord.self,
            RoutineCompletionLogRecord.self,
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: configuration)
    }
}
