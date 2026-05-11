import Combine
import Foundation
import SwiftUI

@MainActor
final class HomeLayoutViewModel: ObservableObject {
    @Published private(set) var layout: HomeLayout
    @Published private(set) var errorMessage: String?

    let registry: HomeWidgetRegistry
    private let homeLayoutRepository: any HomeLayoutRepository

    init(
        homeLayoutRepository: any HomeLayoutRepository,
        registry: HomeWidgetRegistry = .standard
    ) {
        self.homeLayoutRepository = homeLayoutRepository
        self.registry = registry
        self.layout = HomeLayout.defaultLayout.normalized(using: registry)
    }

    var widgets: [HomeWidgetInstance] {
        layout.orderedWidgets
    }

    func load() {
        do {
            layout = try homeLayoutRepository.loadLayout()
                .normalized(using: registry)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load Home layout: \(error.localizedDescription)"
        }
    }

    func addWidget(
        from descriptor: HomeWidgetDescriptor,
        size: HomeWidgetSize? = nil,
        configuration: HomeWidgetConfiguration = .empty
    ) {
        guard registry.canAdd(
            descriptor: descriptor,
            configuration: configuration,
            to: layout
        ) else {
            errorMessage = descriptor.isAvailable
                ? "\(descriptor.displayName) is already on Home."
                : "\(descriptor.displayName) is not available yet."
            return
        }

        let resolvedSize = resolvedSize(
            size ?? descriptor.defaultSize,
            for: descriptor
        )
        var widgets = layout.orderedWidgets
        var removedWidgets = layout.removedWidgets
        let restoredWidget = removedWidgets.first {
            $0.kind == descriptor.kind && $0.configuration == configuration
        }
        removedWidgets.removeAll {
            $0.kind == descriptor.kind && $0.configuration == configuration
        }
        if var restoredWidget {
            restoredWidget.size = resolvedSize
            restoredWidget.sortOrder = widgets.count
            widgets.append(restoredWidget)
            save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
            return
        }

        widgets.append(
            HomeWidgetInstance(
                kind: descriptor.kind,
                size: resolvedSize,
                sortOrder: widgets.count,
                configuration: configuration
            )
        )
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
    }

    func removeWidget(withID id: UUID) {
        var widgets = layout.orderedWidgets
        var removedWidgets = layout.removedWidgets
        guard let removedWidget = widgets.first(where: { $0.id == id }) else {
            return
        }

        widgets.removeAll { $0.id == id }
        removedWidgets.removeAll {
            $0.kind == removedWidget.kind && $0.configuration == removedWidget.configuration
        }
        removedWidgets.append(removedWidget)
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: removedWidgets))
    }

    func moveWidgets(
        from source: IndexSet,
        to destination: Int
    ) {
        var widgets = layout.orderedWidgets
        widgets.move(fromOffsets: source, toOffset: destination)
        widgets = widgets.enumerated().map { index, widget in
            var updatedWidget = widget
            updatedWidget.sortOrder = index
            return updatedWidget
        }
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: layout.removedWidgets))
    }

    func moveWidget(withID movingID: UUID, beforeID targetID: UUID) {
        guard movingID != targetID else {
            return
        }

        var widgets = layout.orderedWidgets
        guard let sourceIndex = widgets.firstIndex(where: { $0.id == movingID }),
              let targetIndex = widgets.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let widget = widgets.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        widgets.insert(widget, at: adjustedTargetIndex)
        widgets = widgets.enumerated().map { index, widget in
            var updatedWidget = widget
            updatedWidget.sortOrder = index
            return updatedWidget
        }
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: layout.removedWidgets))
    }

    func resizeWidget(
        withID id: UUID,
        to size: HomeWidgetSize
    ) {
        var widgets = layout.orderedWidgets
        guard let index = widgets.firstIndex(where: { $0.id == id }),
              let descriptor = registry.descriptor(for: widgets[index].kind),
              descriptor.supportedSizes.contains(size) else {
            return
        }

        widgets[index].size = size
        save(HomeLayout(version: layout.version, widgets: widgets, removedWidgets: layout.removedWidgets))
    }

    func canAdd(
        descriptor: HomeWidgetDescriptor,
        configuration: HomeWidgetConfiguration = .empty
    ) -> Bool {
        registry.canAdd(descriptor: descriptor, configuration: configuration, to: layout)
    }

    func resetToDefaultLayout() {
        save(HomeLayout.defaultLayout)
    }

    func alternateSize(for widget: HomeWidgetInstance) -> HomeWidgetSize? {
        guard let descriptor = registry.descriptor(for: widget.kind),
              descriptor.supportedSizes.count > 1 else {
            return nil
        }

        return descriptor.supportedSizes.first { $0 != widget.size }
    }

    func descriptor(for widget: HomeWidgetInstance) -> HomeWidgetDescriptor? {
        registry.descriptor(for: widget.kind)
    }

    private func resolvedSize(
        _ size: HomeWidgetSize,
        for descriptor: HomeWidgetDescriptor
    ) -> HomeWidgetSize {
        descriptor.supportedSizes.contains(size) ? size : descriptor.defaultSize
    }

    private func save(_ newLayout: HomeLayout) {
        do {
            let normalizedLayout = newLayout.normalized(using: registry)
            try homeLayoutRepository.saveLayout(normalizedLayout)
            layout = normalizedLayout
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save Home layout: \(error.localizedDescription)"
        }
    }
}
