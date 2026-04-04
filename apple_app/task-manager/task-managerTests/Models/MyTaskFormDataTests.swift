import Foundation
import Testing
@testable import task_manager

struct MyTaskFormDataTests {
    @Test func initFromTaskCopiesAllEditableFields() {
        let taskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let createdAt = Date(timeIntervalSince1970: 1_234)
        let task = MyTask(
            id: taskID,
            title: "Finish report",
            isDone: true,
            createdAt: createdAt
        )

        let formData = MyTaskFormData(task: task)

        #expect(formData.idText == taskID.uuidString)
        #expect(formData.title == "Finish report")
        #expect(formData.isDone == true)
        #expect(formData.createdAt == createdAt)
    }

    @Test func makeTaskBuildsTaskFromFormFields() {
        let createdAt = Date(timeIntervalSince1970: 1_234)
        let formData = MyTaskFormData(
            idText: "123E4567-E89B-12D3-A456-426614174000",
            title: "  Finish report  ",
            isDone: true,
            createdAt: createdAt
        )

        let task = formData.makeTask()

        #expect(task?.id == UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        #expect(task?.title == "Finish report")
        #expect(task?.isDone == true)
        #expect(task?.createdAt == createdAt)
    }

    @Test func makeTaskRejectsInvalidID() {
        let formData = MyTaskFormData(idText: "not-a-uuid", title: "Read")

        #expect(formData.makeTask() == nil)
        #expect(formData.canSave == false)
    }

    @Test func makeTaskRejectsBlankTitle() {
        let formData = MyTaskFormData(title: "   ")

        #expect(formData.makeTask() == nil)
        #expect(formData.validationMessage == "Enter a task title.")
    }

    @Test func validationRejectsDuplicateIDForAnotherTask() {
        let duplicateID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let formData = MyTaskFormData(
            idText: duplicateID.uuidString,
            title: "Finish report"
        )

        let message = formData.validationMessage(reservedTaskIDs: [duplicateID])

        #expect(message == "Task ID must be unique.")
        #expect(formData.canSave(reservedTaskIDs: [duplicateID]) == false)
    }

    @Test func validationAllowsOriginalIDDuringEdit() {
        let existingID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let formData = MyTaskFormData(
            idText: existingID.uuidString,
            title: "Finish report"
        )

        let message = formData.validationMessage(
            reservedTaskIDs: [existingID],
            originalTaskID: existingID
        )

        #expect(message == nil)
        #expect(
            formData.canSave(
                reservedTaskIDs: [existingID],
                originalTaskID: existingID
            )
        )
    }

    @Test func generateNewIDReplacesTheCurrentID() {
        var formData = MyTaskFormData(idText: "123E4567-E89B-12D3-A456-426614174000")

        formData.generateNewID()

        #expect(formData.idText != "123E4567-E89B-12D3-A456-426614174000")
        #expect(UUID(uuidString: formData.idText) != nil)
    }
}
