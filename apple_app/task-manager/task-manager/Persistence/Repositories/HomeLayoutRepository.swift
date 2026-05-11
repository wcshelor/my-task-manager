import Foundation

@MainActor
protocol HomeLayoutRepository {
    func loadLayout() throws -> HomeLayout
    func saveLayout(_ layout: HomeLayout) throws
}
