import Foundation
import Testing
@testable import task_manager

struct PeopleMemoryModelTests {
    @Test func personAndTagCleanInputsAndDetectEnrichment() {
        let tag = PersonTag(name: "  Conference  ")
        let person = PersonMemory(
            name: "  Jamie  ",
            pronunciationNote: "  Jay-mee  ",
            whereMet: "   ",
            context: "  Swift meetup  ",
            recognitionCues: "  red glasses  ",
            conversationHooks: "  hiking  ",
            notes: "  asked about thesis  ",
            tagIDs: [tag.id, tag.id],
            studyStage: 99,
            reviewCount: -1
        )
        let emptyCuePerson = PersonMemory(name: "Alex")

        #expect(tag.name == "Conference")
        #expect(tag.normalizedKey == "conference")
        #expect(person.name == "Jamie")
        #expect(person.pronunciationNote == "Jay-mee")
        #expect(person.whereMet == nil)
        #expect(person.context == "Swift meetup")
        #expect(person.recognitionCues == "red glasses")
        #expect(person.conversationHooks == "hiking")
        #expect(person.notes == "asked about thesis")
        #expect(person.tagIDs == [tag.id])
        #expect(person.studyStage == 5)
        #expect(person.reviewCount == 0)
        #expect(person.isStudyReady)
        #expect(person.needsEnrichment == false)
        #expect(emptyCuePerson.isStudyReady == false)
        #expect(emptyCuePerson.needsEnrichment)
        #expect(PersonMemory(newName: "  ") == nil)
        #expect(PersonTag(newName: "  ") == nil)
    }

    @Test func personSearchMatchesNameCueFieldsAndTags() {
        let tag = PersonTag(name: "Choir")
        let person = PersonMemory(
            name: "Nora",
            whereMet: "Coffee shop",
            context: "Friend of Sam",
            recognitionCues: "green scarf",
            conversationHooks: "Berlin trains",
            tagIDs: [tag.id]
        )

        #expect(person.matchesSearchText("nora", tags: [tag]))
        #expect(person.matchesSearchText("green", tags: [tag]))
        #expect(person.matchesSearchText("choir", tags: [tag]))
        #expect(person.matchesSearchText("missing", tags: [tag]) == false)
    }

    @Test func studySchedulingTransitionsForRatings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let reviewedAt = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12))!
        let person = PersonMemory(name: "Mika", whereMet: "Class", studyStage: 1)

        let easy = person.applyingStudyRating(.easy, reviewedAt: reviewedAt, calendar: calendar)
        let almost = person.applyingStudyRating(.almost, reviewedAt: reviewedAt, calendar: calendar)
        let missed = person.applyingStudyRating(.missed, reviewedAt: reviewedAt, calendar: calendar)

        #expect(easy.studyStage == 2)
        #expect(easy.reviewCount == 1)
        #expect(easy.lastStudyRating == .easy)
        #expect(easy.nextReviewAt == calendar.date(byAdding: .day, value: 3, to: reviewedAt))
        #expect(almost.studyStage == 1)
        #expect(almost.nextReviewAt == calendar.date(byAdding: .day, value: 1, to: reviewedAt))
        #expect(missed.studyStage == 0)
        #expect(missed.nextReviewAt == reviewedAt)
    }

    @Test func studyQueueOrdersDueThenNeverReviewedThenLeastRecent() {
        let now = Date(timeIntervalSince1970: 10_000)
        let due = PersonMemory(name: "Due", whereMet: "Office", nextReviewAt: now.addingTimeInterval(-60))
        let neverReviewed = PersonMemory(name: "New", whereMet: "Gym", createdAt: now.addingTimeInterval(-30))
        let oldReview = PersonMemory(name: "Old", whereMet: "Cafe", lastReviewedAt: now.addingTimeInterval(-500))
        let recentReview = PersonMemory(name: "Recent", whereMet: "Cafe", lastReviewedAt: now.addingTimeInterval(-100))
        let noCues = PersonMemory(name: "No Cues")

        let cards = PeopleStudyQueue.cards(
            from: [recentReview, noCues, neverReviewed, oldReview, due],
            tags: [],
            now: now,
            limit: 5
        )

        #expect(cards.map(\.person.name) == ["Due", "New", "Old", "Recent"])
    }
}
