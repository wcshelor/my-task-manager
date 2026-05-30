import Foundation
import Testing
@testable import task_manager

struct SwiftDataFitnessRepositoryTests {
    @Test @MainActor func fitnessRepositoryRoundTripsExercisesTemplatesAndSessions() throws {
        let repository = try makeRepository()
        let exercise = FitnessExercise(
            name: "Bench Press",
            tag: .push,
            trackingStyle: .strengthSets,
            weightUnit: .pounds
        )
        let template = WorkoutTemplate(name: "Push Day", exerciseIDs: [exercise.id])
        let session = ExerciseSession(
            exerciseID: exercise.id,
            performedAt: Date(timeIntervalSince1970: 1_000),
            strengthSets: [StrengthSet(reps: 5, weight: 185)]
        )

        try repository.saveExercise(exercise, replacingExerciseWithID: nil)
        try repository.saveWorkoutTemplate(template, replacingWorkoutTemplateWithID: nil)
        try repository.saveExerciseSession(session, replacingExerciseSessionWithID: nil)

        #expect(try repository.exercise(withID: exercise.id) == exercise)
        #expect(try repository.workoutTemplate(withID: template.id) == template)
        #expect(try repository.exerciseSession(withID: session.id) == session)
        #expect(try repository.fetchExercises() == [exercise])
        #expect(try repository.fetchWorkoutTemplates() == [template])
        #expect(try repository.fetchExerciseSessions() == [session])
    }

    @Test @MainActor func fitnessRepositoryPersistsTemplateReorderAndSessionOrdering() throws {
        let repository = try makeRepository()
        let firstExercise = FitnessExercise(
            name: "Squat",
            tag: .legs,
            trackingStyle: .strengthSets,
            weightUnit: .kilograms
        )
        let secondExercise = FitnessExercise(
            name: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: [.durationMinutes],
            distanceUnit: nil
        )
        let firstSession = ExerciseSession(
            exerciseID: firstExercise.id,
            performedAt: Date(timeIntervalSince1970: 1_000),
            strengthSets: [StrengthSet(reps: 5, weight: 100)]
        )
        let laterSession = ExerciseSession(
            exerciseID: firstExercise.id,
            performedAt: Date(timeIntervalSince1970: 2_000),
            strengthSets: [StrengthSet(reps: 3, weight: 110)]
        )
        let template = WorkoutTemplate(
            name: "Leg Day",
            exerciseIDs: [firstExercise.id, secondExercise.id]
        )
        let reorderedTemplate = WorkoutTemplate(
            id: template.id,
            name: template.name,
            exerciseIDs: [secondExercise.id, firstExercise.id],
            createdAt: template.createdAt,
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        try repository.saveExercise(firstExercise, replacingExerciseWithID: nil)
        try repository.saveExercise(secondExercise, replacingExerciseWithID: nil)
        try repository.saveWorkoutTemplate(template, replacingWorkoutTemplateWithID: nil)
        try repository.saveExerciseSession(firstSession, replacingExerciseSessionWithID: nil)
        try repository.saveExerciseSession(laterSession, replacingExerciseSessionWithID: nil)
        try repository.saveWorkoutTemplate(reorderedTemplate, replacingWorkoutTemplateWithID: template.id)

        #expect(try repository.fetchWorkoutTemplates().first?.exerciseIDs == [secondExercise.id, firstExercise.id])
        #expect(try repository.fetchExerciseSessions().map(\.id) == [laterSession.id, firstSession.id])
    }

    @Test @MainActor func fitnessRepositoryEditsAndDeletesSessions() throws {
        let repository = try makeRepository()
        let exercise = FitnessExercise(
            name: "Row",
            tag: .pull,
            trackingStyle: .strengthSets,
            weightUnit: .pounds
        )
        let originalSession = ExerciseSession(
            exerciseID: exercise.id,
            performedAt: Date(timeIntervalSince1970: 1_000),
            strengthSets: [StrengthSet(reps: 8, weight: 95)]
        )
        let editedSession = ExerciseSession(
            id: originalSession.id,
            exerciseID: exercise.id,
            performedAt: originalSession.performedAt,
            strengthSets: [StrengthSet(reps: 10, weight: 100)],
            createdAt: originalSession.createdAt,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveExercise(exercise, replacingExerciseWithID: nil)
        try repository.saveExerciseSession(originalSession, replacingExerciseSessionWithID: nil)
        try repository.saveExerciseSession(editedSession, replacingExerciseSessionWithID: originalSession.id)

        #expect(try repository.exerciseSession(withID: originalSession.id)?.strengthSets == editedSession.strengthSets)

        try repository.deleteExerciseSession(withID: originalSession.id)
        #expect(try repository.fetchExerciseSessions().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataFitnessRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataFitnessRepository(modelContainer: container)
    }
}
