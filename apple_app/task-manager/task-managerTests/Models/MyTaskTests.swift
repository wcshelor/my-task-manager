import Testing
@testable import task_manager

struct MyTaskTests {
    @Test func cleanedTitleTrimsWhitespace() {
        #expect(MyTask.cleanedTitle(from: "  Buy milk  ") == "Buy milk")
    }

    @Test func cleanedTitleRejectsBlankInput() {
        #expect(MyTask.cleanedTitle(from: " \n\t ") == nil)
    }

    @Test func newTaskInitializerStartsIncomplete() {
        let task = MyTask(newTitle: "Read book")

        #expect(task?.title == "Read book")
        #expect(task?.isDone == false)
    }
}
