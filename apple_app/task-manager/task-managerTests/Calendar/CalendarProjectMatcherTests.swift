import Foundation
import Testing
@testable import task_manager

struct CalendarProjectMatcherTests {
    @Test func matcherRecognizesExactAndMeaningfulPhraseMatches() {
        let project = Project(name: "BERThoven")
        let eventTitle = "BERThoven work block"

        let result = CalendarProjectMatcher().match(
            eventTitle: eventTitle,
            projects: [project]
        )

        #expect(result.matchedProjectID == project.id)
        #expect(result.status == .inferred)
    }

    @Test func matcherAvoidsVeryShortGenericProjectNames() {
        let project = Project(name: "AI")
        let result = CalendarProjectMatcher().match(
            eventTitle: "AI planning block",
            projects: [project]
        )

        #expect(result.matchedProjectID == nil)
        #expect(result.status == .none)
    }

    @Test func matcherMarksMultipleProjectMatchesAsAmbiguous() {
        let first = Project(name: "Product")
        let second = Project(name: "Product Work")

        let result = CalendarProjectMatcher().match(
            eventTitle: "Product work block",
            projects: [first, second]
        )

        #expect(result.isAmbiguous)
        #expect(result.status == .ambiguous)
        #expect(Set(result.matchingProjectIDs) == Set([first.id, second.id]))
    }
}
