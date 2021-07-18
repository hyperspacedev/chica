import XCTest
@testable import chica

final class chicaTests: XCTestCase {
    func testBasicRequests() async throws {

        let account: Account? = try await Chica().request(.get, for: .account(id: "1"))
        XCTAssertEqual(account!.username, "Gargron")
        XCTAssertEqual(account!.id, "1")

    }
}
