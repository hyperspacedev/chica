import XCTest
@testable import Chica
import SwiftUI

final class chicaTests: XCTestCase {

    /// An EnvironmentValue that allows us to open a URL using the appropriate system service.
    ///
    /// Can be used as follows:
    /// ```
    /// openURL(URL(string: "url")!)
    /// ```
    /// or
    ///```
    /// openURL(url) // Where URL.type == URL
    /// ```
    @Environment(\.openURL) private var openURL

    func testBasicRequests() async throws {

        let account = try! await getAccount(id: "1")
        XCTAssertEqual(account!.username, "Gargron")
        XCTAssertEqual(account!.id, "1")

//        XCTAssertThrowsError(async { try await getAccount(id: "0932840923890482309409238409380948") })

    }
}

func getAccount(id: String) async throws -> Account? {
    let account: Account? = try await Chica().request(.get, for: .account(id: id))

    return account
}

