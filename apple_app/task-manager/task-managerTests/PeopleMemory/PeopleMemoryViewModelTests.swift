import Foundation
import Testing
@testable import task_manager

@MainActor
struct PeopleMemoryViewModelTests {
    @Test func viewModelLoadsAndSearchesAcrossCuesAndTags() {
        let tag = PersonTag(name: "Running")
        let person = PersonMemory(
            name: "Elena",
            recognitionCues: "blue jacket",
            tagIDs: [tag.id]
        )
        let repository = FakePeopleMemoryRepository(people: [person], tags: [tag])
        let viewModel = PeopleMemoryViewModel(peopleMemoryRepository: repository)

        viewModel.load()
        viewModel.searchText = "blue"
        #expect(viewModel.filteredPeople == [person])
        viewModel.searchText = "running"
        #expect(viewModel.filteredPeople == [person])
    }

    @Test func viewModelCreatesAndReusesInlineTagsCaseInsensitively() {
        let now = Date(timeIntervalSince1970: 1_000)
        let existingTag = PersonTag(name: "Choir")
        let repository = FakePeopleMemoryRepository(tags: [existingTag])
        let viewModel = PeopleMemoryViewModel(
            peopleMemoryRepository: repository,
            nowProvider: { now }
        )
        let person = PersonMemory(name: "Iris", whereMet: "Concert")

        viewModel.savePerson(person, selectedTagNames: [" choir ", "Cycling"])

        #expect(repository.tags.count == 2)
        #expect(repository.people.first?.tagIDs.count == 2)
        #expect(repository.tags.map(\.normalizedKey).sorted() == ["choir", "cycling"])
    }

    @Test func viewModelStartsDueOrderedStudyAndAppliesRatings() {
        let now = Date(timeIntervalSince1970: 10_000)
        let due = PersonMemory(name: "Due", whereMet: "Office", nextReviewAt: now.addingTimeInterval(-60))
        let neverReviewed = PersonMemory(name: "New", whereMet: "Gym")
        let repository = FakePeopleMemoryRepository(people: [neverReviewed, due])
        let viewModel = PeopleMemoryViewModel(
            peopleMemoryRepository: repository,
            nowProvider: { now }
        )

        viewModel.load()
        viewModel.startStudy()
        #expect(viewModel.studyCards.map(\.person.name) == ["Due", "New"])

        viewModel.applyStudyRating(.easy, to: due.id)

        #expect(viewModel.studyCards.map(\.person.name) == ["New"])
        #expect(viewModel.studiedPersonIDs == [due.id])
        #expect(repository.people.first { $0.id == due.id }?.reviewCount == 1)
    }
}

@MainActor
final class FakePeopleMemoryRepository: PeopleMemoryRepository {
    var people: [PersonMemory]
    var tags: [PersonTag]

    init(people: [PersonMemory] = [], tags: [PersonTag] = []) {
        self.people = people
        self.tags = tags
    }

    func fetchPeople() throws -> [PersonMemory] {
        people.sortedForPeopleMemory()
    }

    func person(withID id: UUID) throws -> PersonMemory? {
        people.first { $0.id == id }
    }

    func savePerson(_ person: PersonMemory, replacingPersonWithID originalID: UUID?) throws {
        let id = originalID ?? person.id
        people.removeAll { $0.id == id || $0.id == person.id }
        people.append(person)
    }

    func deletePerson(withID id: UUID) throws {
        people.removeAll { $0.id == id }
    }

    func fetchTags() throws -> [PersonTag] {
        tags.sortedForPersonTags()
    }

    func tag(withID id: UUID) throws -> PersonTag? {
        tags.first { $0.id == id }
    }

    func tag(withNormalizedKey normalizedKey: String) throws -> PersonTag? {
        let key = PersonTag.normalizedKey(for: normalizedKey)
        return tags.first { $0.normalizedKey == key }
    }

    func saveTag(_ tag: PersonTag, replacingTagWithID originalID: UUID?) throws {
        let key = PersonTag.normalizedKey(for: tag.name)
        tags.removeAll { $0.id == (originalID ?? tag.id) || $0.normalizedKey == key }
        tags.append(tag)
    }

    func deleteTag(withID id: UUID) throws {
        tags.removeAll { $0.id == id }
    }
}
