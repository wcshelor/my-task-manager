import Foundation
import Testing
@testable import task_manager

struct RoutineModelTests {
    @Test func routineRequiresNameAndItemsInConvenienceInitializer() {
        #expect(Routine(newName: "  ", itemTitles: ["One"]) == nil)
        #expect(Routine(newName: "Morning", itemTitles: [" ", "\n"]) == nil)

        let routine = Routine(newName: "  Morning  ", itemTitles: [" Brush teeth ", "", "Plan day"])

        #expect(routine?.name == "Morning")
        #expect(routine?.orderedItems.map(\.title) == ["Brush teeth", "Plan day"])
    }

    @Test func routineSelectedWeekdaysControlActivation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4))!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 5, day: 5))!
        let routine = Routine(
            name: "Morning",
            activeWeekdays: [.monday],
            items: [RoutineItem(title: "Plan", position: 0)]
        )

        #expect(routine.isActive(on: monday, calendar: calendar))
        #expect(routine.isActive(on: tuesday, calendar: calendar) == false)
    }

    @Test func routineCompletionTracksItemLevelProgress() {
        let firstItem = RoutineItem(title: "One", position: 0)
        let secondItem = RoutineItem(title: "Two", position: 1)
        let routine = Routine(name: "Reset", items: [firstItem, secondItem])
        var log = RoutineCompletionLog(routineID: routine.id, date: Date(timeIntervalSince1970: 1_000))

        log.setItem(firstItem.id, state: .completed, updatedAt: Date(timeIntervalSince1970: 2_000))

        #expect(log.completionCount(for: routine) == 1)
        #expect(log.isComplete(for: routine) == false)
        #expect(log.state(for: firstItem.id) == .completed)

        log.setItem(secondItem.id, state: .skipped, updatedAt: Date(timeIntervalSince1970: 3_000))

        #expect(log.completionCount(for: routine) == 1)
        #expect(log.skippedCount(for: routine) == 1)
        #expect(log.state(for: secondItem.id) == .skipped)
        #expect(log.isComplete(for: routine))
    }

    @Test func routineCleansStepLinksAgainstExistingSteps() {
        let firstItem = RoutineItem(title: "One", position: 0)
        let secondItem = RoutineItem(title: "Two", position: 1)
        let routine = Routine(
            name: "Reset",
            items: [firstItem, secondItem],
            stepLinks: [
                RoutineStepLink(routineStepID: secondItem.id, kind: .promiseCheckIn, displayOrder: 1),
                RoutineStepLink(routineStepID: secondItem.id, kind: .pvtTest, displayOrder: 0),
                RoutineStepLink(
                    routineStepID: secondItem.id,
                    kind: .moduleWidget,
                    moduleWidgetKind: .shoppingModule,
                    displayTitle: "Shopping",
                    displayOrder: 2
                ),
                RoutineStepLink(routineStepID: UUID(), kind: .pvtTest, displayOrder: 0),
            ]
        )

        #expect(routine.stepLinks.count == 3)
        #expect(routine.orderedStepLinks(for: secondItem.id).map(\.kind) == [.pvtTest, .promiseCheckIn, .moduleWidget])
        #expect(routine.orderedStepLinks(for: secondItem.id).last?.moduleWidgetKind == .shoppingModule)
    }

    @Test func routineStepLinkRoundTripsModuleWidgetKind() throws {
        let originalLink = RoutineStepLink(
            routineStepID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            kind: .moduleWidget,
            moduleWidgetKind: .healthModule,
            displayTitle: "Health",
            displayOrder: 0
        )

        let encoded = try JSONEncoder().encode(originalLink)
        let decoded = try JSONDecoder().decode(RoutineStepLink.self, from: encoded)

        #expect(decoded.kind == .moduleWidget)
        #expect(decoded.moduleWidgetKind == .healthModule)
        #expect(decoded.displayTitle == "Health")
    }

    @Test func routineStepLinkDecodesLegacyPayloadWithoutModuleWidgetKind() throws {
        let json = """
        {
          "id": "123E4567-E89B-12D3-A456-426614174111",
          "routineStepID": "123E4567-E89B-12D3-A456-426614174112",
          "kind": "pvtTest",
          "displayTitle": "PVT Test",
          "displayOrder": 0
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(RoutineStepLink.self, from: data)

        #expect(decoded.kind == .pvtTest)
        #expect(decoded.moduleWidgetKind == nil)
    }
}
