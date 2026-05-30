import Foundation
import Testing
@testable import task_manager

@MainActor
struct FitnessViewModelTests {
    @Test func fitnessViewModelLoadsAndSortsExercises() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 12))!
        let squat = FitnessExercise(name: "Squat", tag: .legs, trackingStyle: .strengthSets, weightUnit: .pounds)
        let bike = FitnessExercise(
            name: "Bike",
            tag: .cardio,
            trackingStyle: .metricSummary,
            selectableMetricFields: [.durationMinutes],
            distanceUnit: nil
        )
        let earlierSession = ExerciseSession(
            exerciseID: squat.id,
            performedAt: calendar.date(byAdding: .day, value: -1, to: now)!,
            strengthSets: [StrengthSet(reps: 5, weight: 225)]
        )
        let latestSession = ExerciseSession(
            exerciseID: bike.id,
            performedAt: now,
            durationMinutes: 20
        )
        let template = WorkoutTemplate(name: "Mixed Day", exerciseIDs: [squat.id, bike.id])
        let repository = FakeFitnessRepository(
            exercises: [squat, bike],
            templates: [template],
            sessions: [earlierSession, latestSession]
        )
        let viewModel = FitnessViewModel(
            fitnessRepository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.sortedExercises.map(\.id) == [bike.id, squat.id])
        viewModel.sortOption = .alphabetical
        #expect(viewModel.sortedExercises.map(\.name) == ["Bike", "Squat"])
        viewModel.sortOption = .tag
        #expect(viewModel.sortedExercises.map(\.tag) == [.cardio, .legs])
        #expect(viewModel.homeSummary.value == "Today")
    }

    @Test func fitnessViewModelBuildsWorkoutDayRowsAndLoggedToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 30, hour: 12))!
        let bench = FitnessExercise(name: "Bench", tag: .push, trackingStyle: .strengthSets, weightUnit: .pounds)
        let dip = FitnessExercise(name: "Dip", tag: .push, trackingStyle: .strengthSets, weightUnit: .pounds)
        let firstSession = ExerciseSession(
            exerciseID: bench.id,
            performedAt: now,
            strengthSets: [StrengthSet(reps: 5, weight: 185)]
        )
        let priorSession = ExerciseSession(
            exerciseID: bench.id,
            performedAt: calendar.date(byAdding: .day, value: -2, to: now)!,
            strengthSets: [StrengthSet(reps: 5, weight: 175)]
        )
        let template = WorkoutTemplate(name: "Push Day", exerciseIDs: [bench.id, dip.id])
        let repository = FakeFitnessRepository(
            exercises: [bench, dip],
            templates: [template],
            sessions: [priorSession, firstSession]
        )
        let viewModel = FitnessViewModel(
            fitnessRepository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.load()
        let rows = viewModel.templateRows(for: template).rows

        #expect(rows.count == 2)
        #expect(rows.first?.latestSession?.id == firstSession.id)
        #expect(rows.first?.priorSessions == [priorSession])
        #expect(rows.first?.loggedToday == true)
        #expect(rows.last?.latestSession == nil)
    }

    @Test func fitnessViewModelRefreshesAfterSaveDeleteFlows() {
        let exercise = FitnessExercise(name: "Row", tag: .pull, trackingStyle: .strengthSets, weightUnit: .kilograms)
        let repository = FakeFitnessRepository(exercises: [exercise])
        let viewModel = FitnessViewModel(fitnessRepository: repository)
        let session = ExerciseSession(
            exerciseID: exercise.id,
            strengthSets: [StrengthSet(reps: 8, weight: 60)]
        )
        let template = WorkoutTemplate(name: "Pull Day", exerciseIDs: [exercise.id])

        viewModel.load()
        viewModel.saveWorkoutTemplate(template)
        viewModel.saveExerciseSession(session)

        #expect(viewModel.workoutTemplates == [template])
        #expect(viewModel.latestSession(for: exercise.id)?.id == session.id)

        viewModel.deleteExerciseSession(withID: session.id)
        #expect(viewModel.recentSessions(for: exercise.id).isEmpty)
    }
}

@MainActor
private final class FakeFitnessRepository: FitnessRepository {
    var exercises: [FitnessExercise]
    var templates: [WorkoutTemplate]
    var sessions: [ExerciseSession]

    init(
        exercises: [FitnessExercise] = [],
        templates: [WorkoutTemplate] = [],
        sessions: [ExerciseSession] = []
    ) {
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions
    }

    func fetchExercises() throws -> [FitnessExercise] {
        exercises.sortedAlphabetically()
    }

    func exercise(withID id: UUID) throws -> FitnessExercise? {
        exercises.first { $0.id == id }
    }

    func saveExercise(_ exercise: FitnessExercise, replacingExerciseWithID originalID: UUID?) throws {
        let targetID = originalID ?? exercise.id
        if let index = exercises.firstIndex(where: { $0.id == targetID || $0.id == exercise.id }) {
            exercises[index] = exercise
        } else {
            exercises.append(exercise)
        }
    }

    func fetchWorkoutTemplates() throws -> [WorkoutTemplate] {
        templates.sorted { $0.createdAt < $1.createdAt }
    }

    func workoutTemplate(withID id: UUID) throws -> WorkoutTemplate? {
        templates.first { $0.id == id }
    }

    func saveWorkoutTemplate(_ template: WorkoutTemplate, replacingWorkoutTemplateWithID originalID: UUID?) throws {
        let targetID = originalID ?? template.id
        if let index = templates.firstIndex(where: { $0.id == targetID || $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
    }

    func deleteWorkoutTemplate(withID id: UUID) throws {
        templates.removeAll { $0.id == id }
    }

    func fetchExerciseSessions() throws -> [ExerciseSession] {
        sessions.sortedForExerciseHistory()
    }

    func exerciseSession(withID id: UUID) throws -> ExerciseSession? {
        sessions.first { $0.id == id }
    }

    func saveExerciseSession(_ session: ExerciseSession, replacingExerciseSessionWithID originalID: UUID?) throws {
        let targetID = originalID ?? session.id
        if let index = sessions.firstIndex(where: { $0.id == targetID || $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func deleteExerciseSession(withID id: UUID) throws {
        sessions.removeAll { $0.id == id }
    }
}
