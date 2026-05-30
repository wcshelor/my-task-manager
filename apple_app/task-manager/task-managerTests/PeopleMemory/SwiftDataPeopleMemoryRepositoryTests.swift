import Foundation
import Testing
@testable import task_manager

struct SwiftDataPeopleMemoryRepositoryTests {
    @Test @MainActor func peopleMemoryRepositoryRoundTripsPersonAndTag() throws {
        let repository = try makeRepository()
        let tag = PersonTag(name: "Workshop")
        let person = PersonMemory(
            name: "Leah",
            whereMet: "Design sprint",
            recognitionCues: "silver laptop",
            tagIDs: [tag.id],
            studyStage: 2,
            reviewCount: 3,
            lastReviewedAt: Date(timeIntervalSince1970: 100),
            nextReviewAt: Date(timeIntervalSince1970: 200),
            lastStudyRating: .easy
        )

        try repository.saveTag(tag, replacingTagWithID: nil)
        try repository.savePerson(person, replacingPersonWithID: nil)

        #expect(try repository.tag(withID: tag.id) == tag)
        #expect(try repository.person(withID: person.id) == person)
        #expect(try repository.fetchTags() == [tag])
        #expect(try repository.fetchPeople() == [person])
    }

    @Test @MainActor func repositoryUpdatesPersonPreservingIDAndReviewState() throws {
        let repository = try makeRepository()
        let original = PersonMemory(name: "Sam", whereMet: "Library")
        let reviewed = original.applyingStudyRating(
            .almost,
            reviewedAt: Date(timeIntervalSince1970: 500),
            calendar: Calendar(identifier: .gregorian)
        )

        try repository.savePerson(original, replacingPersonWithID: nil)
        try repository.savePerson(reviewed, replacingPersonWithID: original.id)

        let fetched = try repository.person(withID: original.id)
        #expect(fetched?.id == original.id)
        #expect(fetched?.reviewCount == 1)
        #expect(fetched?.lastStudyRating == .almost)
        #expect(fetched?.studyStage == 1)
    }

    @Test @MainActor func repositoryDedupesTagsByNormalizedKeyAndDeletingPersonKeepsTags() throws {
        let repository = try makeRepository()
        let firstTag = PersonTag(name: "Choir")
        let duplicateTag = PersonTag(name: " choir ")
        let person = PersonMemory(name: "Ari", whereMet: "Concert", tagIDs: [firstTag.id])

        try repository.saveTag(firstTag, replacingTagWithID: nil)
        try repository.saveTag(duplicateTag, replacingTagWithID: nil)
        try repository.savePerson(person, replacingPersonWithID: nil)
        try repository.deletePerson(withID: person.id)

        #expect(try repository.fetchTags().count == 1)
        #expect(try repository.fetchTags().first?.normalizedKey == "choir")
        #expect(try repository.fetchPeople().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataPeopleMemoryRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataPeopleMemoryRepository(modelContainer: container)
    }
}
