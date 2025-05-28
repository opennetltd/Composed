import Quick
import Nimble
import Foundation

@testable import Composed

final class ArraySection_Spec: AsyncSpec {
    override static func spec() {
        describe("ArraySection") {
            var arraySection: ArraySection<String>!
            var mockDelegate: MockSectionUpdateDelegate!

            beforeEach { @MainActor in
                arraySection = ArraySection()
                mockDelegate = MockSectionUpdateDelegate()
                arraySection.updateDelegate = mockDelegate
            }

            context("after an array with 3 items has been appended") {
                beforeEach { @MainActor in
                    arraySection.append(contentsOf: ["a", "b", "c"])
                }

                it("should contain 3 elements") { @MainActor in
                    expect(arraySection.numberOfElements) == 3
                }

                it("should return the correct first element indexes") { @MainActor in
                    expect(mockDelegate.didInsertElementCalls.count) == 3
                    expect(mockDelegate.didInsertElementCalls.map(\.index).sorted()) == [0, 1, 2]
                }

                context("then all elements are removed") {
                    beforeEach { @MainActor in
                        arraySection.removeAll()
                    }

                    it("should contain 0 elements") { @MainActor in
                        expect(arraySection.numberOfElements) == 0
                    }

                    it("should return the correct first element indexes") { @MainActor in
                        expect(mockDelegate.didInsertElementCalls.count) == 3
                        expect(mockDelegate.didInsertElementCalls.map(\.index).sorted()) == [
                            0,
                            1,
                            2
                        ]
                        expect(mockDelegate.didRemoveElementCalls.count) == 3
                        expect(mockDelegate.didRemoveElementCalls.map(\.index).sorted()) == [0, 1, 2]
                    }
                }
            }
        }
    }

}

private final class MockSectionUpdateDelegate: SectionUpdateDelegate {
    private(set) var invalidateAllCalls: [Section] = []
    private(set) var didInsertElementCalls: [(section: Section, index: Int)] = []
    private(set) var didRemoveElementCalls: [(section: Section, index: Int)] = []

    func section(_ section: Section, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool) {
        updates()
    }

    func invalidateAll(_ section: Section) {
        invalidateAllCalls.append(section)
    }

    func section(_ section: Section, didInsertElementAt index: Int) {
        didInsertElementCalls.append((section, index))
    }

    func section(_ section: Section, didRemoveElementAt index: Int) {
        didRemoveElementCalls.append((section, index))
    }

    func section(_ section: Section, didUpdateElementAt index: Int) {}

    func section(_ section: Section, didMoveElementAt index: Int, to newIndex: Int) {}

    func selectedIndexes(in section: Section) -> [Int] { [] }

    func section(_ section: Section, select index: Int) {}

    func section(_ section: Section, deselect index: Int) {}

    func section(_ section: Section, move sourceIndex: Int, to destinationIndex: Int) {}

    func sectionDidInvalidateHeader(_ section: Section) {}
    func sectionDidInvalidateFooter(_ section: Section) {}
}
