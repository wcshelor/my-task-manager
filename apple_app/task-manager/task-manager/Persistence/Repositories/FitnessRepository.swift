import Foundation

@MainActor
protocol FitnessRepository {
    func fetchExercises() throws -> [FitnessExercise]
    func exercise(withID id: UUID) throws -> FitnessExercise?
    func saveExercise(_ exercise: FitnessExercise, replacingExerciseWithID originalID: UUID?) throws

    func fetchWorkoutTemplates() throws -> [WorkoutTemplate]
    func workoutTemplate(withID id: UUID) throws -> WorkoutTemplate?
    func saveWorkoutTemplate(_ template: WorkoutTemplate, replacingWorkoutTemplateWithID originalID: UUID?) throws
    func deleteWorkoutTemplate(withID id: UUID) throws

    func fetchExerciseSessions() throws -> [ExerciseSession]
    func exerciseSession(withID id: UUID) throws -> ExerciseSession?
    func saveExerciseSession(_ session: ExerciseSession, replacingExerciseSessionWithID originalID: UUID?) throws
    func deleteExerciseSession(withID id: UUID) throws
}
