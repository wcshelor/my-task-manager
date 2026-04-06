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
        TabView {
            TaskListView(taskRepository: appEnvironment.taskRepository)
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
                calendarReconciler: appEnvironment.calendarReconciler
            )
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
        }
    }
}

#Preview {
    ContentView(appEnvironment: AppEnvironment(container: .makePreview()))
}
