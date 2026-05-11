import Combine
import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
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
        let resolvedSize = resolvedSize(
            size ?? descriptor.defaultSize,
            for: descriptor
        )
        var widgets = layout.orderedWidgets
        widgets.append(
            HomeWidgetInstance(
                kind: descriptor.kind,
                size: resolvedSize,
                sortOrder: widgets.count,
                configuration: configuration
            )
        )
        save(HomeLayout(version: layout.version, widgets: widgets))
    }

    func removeWidget(withID id: UUID) {
        let widgets = layout.orderedWidgets.filter { $0.id != id }
        save(HomeLayout(version: layout.version, widgets: widgets))
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
        save(HomeLayout(version: layout.version, widgets: widgets))
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
        save(HomeLayout(version: layout.version, widgets: widgets))
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
