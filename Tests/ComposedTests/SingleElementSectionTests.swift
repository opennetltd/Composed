import XCTest
import Composed

@MainActor
final class SingleElementSectionTests: XCTestCase {
    func testNumberOfElementsWithOptional() {
        let section = SingleElementSection<String?>(element: nil)

        XCTAssertEqual(section.numberOfElements, 0)

        section.replace(element: "")

        XCTAssertEqual(section.numberOfElements, 1)

        section.replace(element: .none)

        XCTAssertEqual(section.numberOfElements, 0)
    }
}
