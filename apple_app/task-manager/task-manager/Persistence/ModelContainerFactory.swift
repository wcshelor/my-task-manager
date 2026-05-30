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
            ProjectRecord.self,
            CaptureItemRecord.self,
            ProjectItemRecord.self,
            ScheduledBlockRecord.self,
            AppSettingsRecord.self,
            HomeLayoutRecord.self,
            PromiseRecord.self,
            RoutineRecord.self,
            RoutineCompletionLogRecord.self,
            ShoppingItemRecord.self,
            SleepCheckInRecord.self,
            MealLogRecord.self,
            WorkoutLogRecord.self,
            PVTSessionRecord.self,
            PracticePieceRecord.self,
            PracticeSessionRecord.self,
            FitnessExerciseRecord.self,
            WorkoutTemplateRecord.self,
            ExerciseSessionRecord.self,
            PersonMemoryRecord.self,
            PersonTagRecord.self,
        ])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(for: schema, configurations: configuration)
    }
}
