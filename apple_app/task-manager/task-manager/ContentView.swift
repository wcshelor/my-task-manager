//
//  ContentView.swift
//  task-manager
//
//  Created by Camp Shelor on 3/26/26.
//

import SwiftUI

struct ContentView: View {
    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }

    var body: some View {
        TaskManagerTabShell(appEnvironment: appEnvironment)
    }
}

private struct TaskManagerTabShell: View {
    private let appEnvironment: AppEnvironment

    init(appEnvironment: AppEnvironment) {
        self.appEnvironment = appEnvironment
    }

    var body: some View {
        TabView {
            HomeView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                captureRepository: appEnvironment.captureRepository,
                projectItemRepository: appEnvironment.projectItemRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                settingsRepository: appEnvironment.settingsRepository,
                homeLayoutRepository: appEnvironment.homeLayoutRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarListingService: appEnvironment.calendarListingService,
                calendarReader: appEnvironment.calendarReader,
                calendarWriter: appEnvironment.calendarWriter,
                calendarReconciler: appEnvironment.calendarReconciler,
                calendarChangeObserver: appEnvironment.calendarChangeObserver,
                promiseRepository: appEnvironment.promiseRepository,
                routineRepository: appEnvironment.routineRepository,
                shoppingRepository: appEnvironment.shoppingRepository,
                healthRepository: appEnvironment.healthRepository,
                musicPracticeRepository: appEnvironment.musicPracticeRepository,
                fitnessRepository: appEnvironment.fitnessRepository,
                peopleMemoryRepository: appEnvironment.peopleMemoryRepository,
                debriefRepository: appEnvironment.debriefRepository
            )
                .tabItem {
                    Label("Home", systemImage: "square.grid.2x2.fill")
                }

            TaskListView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                calendarWriter: appEnvironment.calendarWriter,
                promiseRepository: appEnvironment.promiseRepository
            )
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            ProjectsView(
                taskRepository: appEnvironment.taskRepository,
                projectRepository: appEnvironment.projectRepository,
                captureRepository: appEnvironment.captureRepository,
                projectItemRepository: appEnvironment.projectItemRepository
            )
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            SettingsView(
                settingsRepository: appEnvironment.settingsRepository,
                homeLayoutRepository: appEnvironment.homeLayoutRepository,
                projectRepository: appEnvironment.projectRepository,
                routineRepository: appEnvironment.routineRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarListingService: appEnvironment.calendarListingService
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #endif
    }
}

#Preview {
    ContentView(appEnvironment: AppEnvironment(container: .makePreview()))
}
