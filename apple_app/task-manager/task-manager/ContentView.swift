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
            TodayView(
                promiseRepository: appEnvironment.promiseRepository,
                routineRepository: appEnvironment.routineRepository
            )
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            TaskListView(
                taskRepository: appEnvironment.taskRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                calendarWriter: appEnvironment.calendarWriter,
                promiseRepository: appEnvironment.promiseRepository
            )
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            PlannerView(
                taskRepository: appEnvironment.taskRepository,
                scheduledBlockRepository: appEnvironment.scheduledBlockRepository,
                settingsRepository: appEnvironment.settingsRepository,
                calendarPermissionProvider: appEnvironment.calendarPermissionProvider,
                calendarListingService: appEnvironment.calendarListingService,
                calendarReader: appEnvironment.calendarReader,
                calendarWriter: appEnvironment.calendarWriter,
                calendarReconciler: appEnvironment.calendarReconciler,
                calendarChangeObserver: appEnvironment.calendarChangeObserver,
                promiseRepository: appEnvironment.promiseRepository
            )
            .tabItem {
                Label("Calendar", systemImage: "calendar")
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
