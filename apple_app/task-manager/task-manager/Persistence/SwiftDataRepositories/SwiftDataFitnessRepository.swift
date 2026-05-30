import Foundation
import SwiftData

@MainActor
final class SwiftDataFitnessRepository: FitnessRepository {
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        modelContext = modelContainer.mainContext
    }

    func fetchExercises() throws -> [FitnessExercise] {
        try modelContext.fetch(FetchDescriptor<FitnessExerciseRecord>())
            .map(\.exercise)
            .sortedAlphabetically()
    }

    func exercise(withID id: UUID) throws -> FitnessExercise? {
        try fetchExerciseRecord(withID: id)?.exercise
    }

    func saveExercise(_ exercise: FitnessExercise, replacingExerciseWithID originalID: UUID?) throws {
        let record = try fetchExerciseRecord(withID: originalID ?? exercise.id)
            ?? fetchExerciseRecord(withID: exercise.id)

        if let record {
            record.update(from: exercise)
        } else {
            modelContext.insert(FitnessExerciseRecord(exercise: exercise))
        }

        try modelContext.save()
    }

    func fetchWorkoutTemplates() throws -> [WorkoutTemplate] {
        try modelContext.fetch(FetchDescriptor<WorkoutTemplateRecord>())
            .map(\.template)
            .sorted { leftTemplate, rightTemplate in
                if leftTemplate.createdAt != rightTemplate.createdAt {
                    return leftTemplate.createdAt < rightTemplate.createdAt
                }

                return leftTemplate.id.uuidString < rightTemplate.id.uuidString
            }
    }

    func workoutTemplate(withID id: UUID) throws -> WorkoutTemplate? {
        try fetchWorkoutTemplateRecord(withID: id)?.template
    }

    func saveWorkoutTemplate(_ template: WorkoutTemplate, replacingWorkoutTemplateWithID originalID: UUID?) throws {
        let record = try fetchWorkoutTemplateRecord(withID: originalID ?? template.id)
            ?? fetchWorkoutTemplateRecord(withID: template.id)

        if let record {
            record.update(from: template)
        } else {
            modelContext.insert(WorkoutTemplateRecord(template: template))
        }

        try modelContext.save()
    }

    func deleteWorkoutTemplate(withID id: UUID) throws {
        guard let record = try fetchWorkoutTemplateRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchExerciseSessions() throws -> [ExerciseSession] {
        try modelContext.fetch(FetchDescriptor<ExerciseSessionRecord>())
            .map(\.session)
            .sortedForExerciseHistory()
    }

    func exerciseSession(withID id: UUID) throws -> ExerciseSession? {
        try fetchExerciseSessionRecord(withID: id)?.session
    }

    func saveExerciseSession(_ session: ExerciseSession, replacingExerciseSessionWithID originalID: UUID?) throws {
        let record = try fetchExerciseSessionRecord(withID: originalID ?? session.id)
            ?? fetchExerciseSessionRecord(withID: session.id)

        if let record {
            record.update(from: session)
        } else {
            modelContext.insert(ExerciseSessionRecord(session: session))
        }

        try modelContext.save()
    }

    func deleteExerciseSession(withID id: UUID) throws {
        guard let record = try fetchExerciseSessionRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    private func fetchExerciseRecord(withID id: UUID) throws -> FitnessExerciseRecord? {
        try modelContext.fetch(FetchDescriptor<FitnessExerciseRecord>()).first { $0.id == id }
    }

    private func fetchWorkoutTemplateRecord(withID id: UUID) throws -> WorkoutTemplateRecord? {
        try modelContext.fetch(FetchDescriptor<WorkoutTemplateRecord>()).first { $0.id == id }
    }

    private func fetchExerciseSessionRecord(withID id: UUID) throws -> ExerciseSessionRecord? {
        try modelContext.fetch(FetchDescriptor<ExerciseSessionRecord>()).first { $0.id == id }
    }
}
