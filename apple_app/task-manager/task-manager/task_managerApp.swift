//
//  task_managerApp.swift
//  task-manager
//
//  Created by Camp Shelor on 3/26/26.
//

import SwiftUI
import SwiftData

@main
struct task_managerApp: App {
    private let appEnvironment: AppEnvironment

    init() {
        do {
            appEnvironment = AppEnvironment(container: try AppContainer.makeLive())
        } catch {
            fatalError("Failed to create app container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appEnvironment: appEnvironment)
        }
        .modelContainer(appEnvironment.container.modelContainer)
    }
}
