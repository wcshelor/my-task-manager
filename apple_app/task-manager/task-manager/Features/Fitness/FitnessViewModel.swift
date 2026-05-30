import Combine
import Foundation

nonisolated struct HomeFitnessSummary: Equatable, Sendable {
    let exercises: [FitnessExercise]
    let templates: [WorkoutTemplate]
    let sessions: [ExerciseSession]
    let now: Date
    let calendar: Calendar

    init(
        exercises: [FitnessExercise] = [],
        templates: [WorkoutTemplate] = [],
        sessions: [ExerciseSession] = [],
        now: Date,
        calendar: Calendar
    ) {
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions.sortedForExerciseHistory()
        self.now = now
        self.calendar = calendar
    }

    var detail: String {
        if let latestSession = sessions.first {
            return "Last \(latestSession.performedAt.formatted(date: .abbreviated, time: .omitted))"
        }

        if templates.isEmpty == false {
            return "\(templates.count) workout day\(templates.count == 1 ? "" : "s")"
        }

        if exercises.isEmpty == false {
            return "\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")"
        }

        return "No sessions logged"
    }

    var value: String {
        sessions.contains { $0.isForSameDay(as: now, calendar: calendar) }
            ? "Today"
            : "Open"
    }
}

nonisolated struct FitnessTemplateRowSummary: Identifiable, Equatable, Sendable {
    let template: WorkoutTemplate
    let rows: [FitnessTemplateExerciseRow]

    var id: UUID { template.id }
}

nonisolated struct FitnessTemplateExerciseRow: Identifiable, Equatable, Sendable {
    let exercise: FitnessExercise
    let latestSession: ExerciseSession?
    let priorSessions: [ExerciseSession]
    let loggedToday: Bool

    var id: UUID { exercise.id }
}

@MainActor
final class FitnessViewModel: ObservableObject {
    @Published private(set) var exercises: [FitnessExercise] = []
    @Published private(set) var workoutTemplates: [WorkoutTemplate] = []
    @Published private(set) var sessions: [ExerciseSession] = []
    @Published var sortOption: ExerciseSortOption = .recent
    @Published private(set) var errorMessage: String?

    private let fitnessRepository: any FitnessRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        fitnessRepository: any FitnessRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fitnessRepository = fitnessRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var exercisesByID: [UUID: FitnessExercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    var sessionsByExerciseID: [UUID: [ExerciseSession]] {
        Dictionary(grouping: sessions, by: \.exerciseID)
    }

    var sortedExercises: [FitnessExercise] {
        switch sortOption {
        case .alphabetical:
            return exercises.sortedAlphabetically()
        case .tag:
            return exercises.sorted { leftExercise, rightExercise in
                if leftExercise.tag != rightExercise.tag {
                    return leftExercise.tag.displayName < rightExercise.tag.displayName
                }

                let comparison = leftExercise.name.localizedCaseInsensitiveCompare(rightExercise.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }

                return leftExercise.id.uuidString < rightExercise.id.uuidString
            }
        case .recent:
            let latestByExercise = Dictionary(uniqueKeysWithValues: exercises.map { exercise in
                (exercise.id, sessionsByExerciseID[exercise.id]?.first?.performedAt)
            })
            return exercises.sorted { leftExercise, rightExercise in
                let leftDate = latestByExercise[leftExercise.id] ?? nil
                let rightDate = latestByExercise[rightExercise.id] ?? nil
                switch (leftDate, rightDate) {
                case let (leftDate?, rightDate?):
                    if leftDate != rightDate {
                        return leftDate > rightDate
                    }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                let comparison = leftExercise.name.localizedCaseInsensitiveCompare(rightExercise.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }

                return leftExercise.id.uuidString < rightExercise.id.uuidString
            }
        }
    }

    var homeSummary: HomeFitnessSummary {
        HomeFitnessSummary(
            exercises: exercises,
            templates: workoutTemplates,
            sessions: sessions,
            now: nowProvider(),
            calendar: calendar
        )
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            exercises = try fitnessRepository.fetchExercises()
            workoutTemplates = try fitnessRepository.fetchWorkoutTemplates()
            sessions = try fitnessRepository.fetchExerciseSessions()
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load Fitness: \(error.localizedDescription)"
        }
    }

    func recentSessions(for exerciseID: UUID, limit: Int = 3) -> [ExerciseSession] {
        Array((sessionsByExerciseID[exerciseID] ?? []).prefix(max(0, limit)))
    }

    func latestSession(for exerciseID: UUID) -> ExerciseSession? {
        sessionsByExerciseID[exerciseID]?.first
    }

    func loggedToday(for exerciseID: UUID) -> Bool {
        recentSessions(for: exerciseID, limit: 20)
            .contains { $0.isForSameDay(as: nowProvider(), calendar: calendar) }
    }

    func templateRows(for template: WorkoutTemplate) -> FitnessTemplateRowSummary {
        let rows = template.exerciseIDs.compactMap { exerciseID -> FitnessTemplateExerciseRow? in
            guard let exercise = exercisesByID[exerciseID] else {
                return nil
            }

            let history = sessionsByExerciseID[exerciseID] ?? []
            return FitnessTemplateExerciseRow(
                exercise: exercise,
                latestSession: history.first,
                priorSessions: Array(history.dropFirst().prefix(2)),
                loggedToday: history.contains { $0.isForSameDay(as: nowProvider(), calendar: calendar) }
            )
        }

        return FitnessTemplateRowSummary(template: template, rows: rows)
    }

    func saveExercise(_ exercise: FitnessExercise, replacingExerciseWithID originalID: UUID? = nil) {
        do {
            try fitnessRepository.saveExercise(exercise, replacingExerciseWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save exercise: \(error.localizedDescription)"
        }
    }

    func saveWorkoutTemplate(_ template: WorkoutTemplate, replacingWorkoutTemplateWithID originalID: UUID? = nil) {
        do {
            try fitnessRepository.saveWorkoutTemplate(template, replacingWorkoutTemplateWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save workout day: \(error.localizedDescription)"
        }
    }

    func deleteWorkoutTemplate(withID id: UUID) {
        do {
            try fitnessRepository.deleteWorkoutTemplate(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete workout day: \(error.localizedDescription)"
        }
    }

    func saveExerciseSession(_ session: ExerciseSession, replacingExerciseSessionWithID originalID: UUID? = nil) {
        do {
            try fitnessRepository.saveExerciseSession(session, replacingExerciseSessionWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save session: \(error.localizedDescription)"
        }
    }

    func deleteExerciseSession(withID id: UUID) {
        do {
            try fitnessRepository.deleteExerciseSession(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete session: \(error.localizedDescription)"
        }
    }
}
