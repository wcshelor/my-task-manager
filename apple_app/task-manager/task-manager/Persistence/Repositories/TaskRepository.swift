import Foundation

@MainActor
protocol TaskRepository {
    func fetchTasks() throws -> [MyTask]
    func task(withID id: UUID) throws -> MyTask?
    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws
    func deleteTask(withID id: UUID) throws
}

@MainActor
protocol ProjectRepository {
    func fetchProjects(includeArchived: Bool) throws -> [Project]
    func project(withID id: UUID) throws -> Project?
    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) throws
    func archiveProject(withID id: UUID, archivedAt: Date) throws
    func deleteProject(withID id: UUID) throws
}

@MainActor
protocol CaptureRepository {
    func fetchCaptures(includeProcessed: Bool, includeArchived: Bool) throws -> [CaptureItem]
    func capture(withID id: UUID) throws -> CaptureItem?
    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID?) throws
    func deleteCapture(withID id: UUID) throws
}

@MainActor
protocol ProjectItemRepository {
    func fetchProjectItems(includeArchived: Bool) throws -> [ProjectItem]
    func fetchProjectItems(for projectID: UUID, includeArchived: Bool) throws -> [ProjectItem]
    func projectItem(withID id: UUID) throws -> ProjectItem?
    func saveProjectItem(_ item: ProjectItem, replacingProjectItemWithID originalID: UUID?) throws
    func archiveProjectItem(withID id: UUID, archivedAt: Date) throws
    func deleteProjectItem(withID id: UUID) throws
}

@MainActor
protocol CalendarBlockFocusRepository {
    func fetchFocus(forEventIdentifier eventIdentifier: String, calendarIdentifier: String) throws -> CalendarBlockFocus?
    func fetchFocuses(in dateRange: DateInterval) throws -> [CalendarBlockFocus]
    func fetchFocuses(linkedTo projectID: UUID) throws -> [CalendarBlockFocus]
    func saveFocus(_ focus: CalendarBlockFocus, replacingFocusWithID originalID: UUID?) throws
    func setLinkedProject(
        _ projectID: UUID?,
        for event: CalendarEventSnapshot,
        isUserConfirmed: Bool
    ) throws
    func setSelectedTaskIDs(
        _ taskIDs: [UUID],
        for event: CalendarEventSnapshot
    ) throws
    func updateIntentionNote(
        _ note: String?,
        for event: CalendarEventSnapshot
    ) throws
    func markNoFocusNeeded(
        for event: CalendarEventSnapshot,
        isNoFocusNeeded: Bool
    ) throws
}
