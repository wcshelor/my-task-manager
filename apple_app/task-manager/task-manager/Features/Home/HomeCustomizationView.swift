import Combine
import SwiftUI

@MainActor
final class HomeLayoutEditorViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var errorMessage: String?

    private let projectRepository: any ProjectRepository
    private let routineRepository: any RoutineRepository

    init(
        projectRepository: any ProjectRepository,
        routineRepository: any RoutineRepository
    ) {
        self.projectRepository = projectRepository
        self.routineRepository = routineRepository
    }

    func load() {
        do {
            projects = try projectRepository.fetchProjects(includeArchived: false)
            routines = try routineRepository.fetchRoutines()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load Home customization: \(error.localizedDescription)"
        }
    }
}

struct HomeLayoutEditorView: View {
    @StateObject private var layoutViewModel: HomeLayoutViewModel
    @StateObject private var viewModel: HomeLayoutEditorViewModel
    @State private var isShowingAddWidget = false

    init(
        homeLayoutRepository: any HomeLayoutRepository,
        projectRepository: any ProjectRepository,
        routineRepository: any RoutineRepository
    ) {
        _layoutViewModel = StateObject(
            wrappedValue: HomeLayoutViewModel(homeLayoutRepository: homeLayoutRepository)
        )
        _viewModel = StateObject(
            wrappedValue: HomeLayoutEditorViewModel(
                projectRepository: projectRepository,
                routineRepository: routineRepository
            )
        )
    }

    var body: some View {
        List {
            if let errorMessage = combinedErrorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if layoutViewModel.widgets.isEmpty {
                    Text("Home is empty. Add widgets or reset to the default layout.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(layoutViewModel.widgets) { widget in
                        widgetRow(for: widget)
                    }
                    .onDelete(perform: deleteWidgets)
                    .onMove(perform: layoutViewModel.moveWidgets)
                }
            } header: {
                Text("Current Widgets")
            } footer: {
                Text("Reorder widgets, remove what you do not need, or resize supported widgets.")
            }

            Section("Layout") {
                Button {
                    isShowingAddWidget = true
                } label: {
                    Label("Add Widget", systemImage: "plus.circle")
                }

                Button(role: .destructive) {
                    layoutViewModel.resetToDefaultLayout()
                } label: {
                    Label("Reset to Default Layout", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Home Screen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $isShowingAddWidget) {
            NavigationStack {
                AddHomeWidgetView(
                    viewModel: layoutViewModel,
                    projects: viewModel.projects,
                    routines: viewModel.routines
                ) {
                    viewModel.load()
                }
            }
        }
        .task {
            layoutViewModel.load()
            viewModel.load()
        }
    }

    private var combinedErrorMessage: String? {
        layoutViewModel.errorMessage ?? viewModel.errorMessage
    }

    @ViewBuilder
    private func widgetRow(for widget: HomeWidgetInstance) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(
                layoutViewModel.descriptor(for: widget)?.displayName ?? widget.kind.rawValue,
                systemImage: layoutViewModel.descriptor(for: widget)?.iconSystemName ?? "square.grid.2x2"
            )

            Spacer()

            Text(widget.size == .large ? "Large" : "Small")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let alternateSize = layoutViewModel.alternateSize(for: widget) {
                Button(alternateSize == .large ? "Make Large" : "Make Small") {
                    layoutViewModel.resizeWidget(withID: widget.id, to: alternateSize)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
    }

    private func deleteWidgets(at offsets: IndexSet) {
        for index in offsets {
            layoutViewModel.removeWidget(withID: layoutViewModel.widgets[index].id)
        }
    }
}

#Preview {
    NavigationStack {
        HomeLayoutEditorView(
            homeLayoutRepository: AppContainer.makePreview().homeLayoutRepository,
            projectRepository: AppContainer.makePreview().projectRepository,
            routineRepository: AppContainer.makePreview().routineRepository
        )
    }
}
