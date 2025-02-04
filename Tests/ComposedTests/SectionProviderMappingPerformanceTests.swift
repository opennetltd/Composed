import Composed
import XCTest

@MainActor
final class SectionProviderMappingPerformanceTests: XCTestCase {
    func testPerformanceWithManyChildAggregateSectionProviders() {
        let rootSectionProvider = ComposedSectionProvider()
        let mapping = SectionProviderMapping(provider: rootSectionProvider)

        measure {
            let maxDepth = 2
            let childrenPerChild = 5
            var depth = 1
            var parents: [Int: [ComposedSectionProvider]] = [0: [rootSectionProvider]]
            var lastSection: Section!

            var childCount = 0

            while depth <= maxDepth {
                for parent in parents[depth - 1, default: []] {
                    for _ in 0 ..< childrenPerChild {
                        let child = ComposedSectionProvider()
                        parent.append(child)
                        parents[depth, default: []].append(child)
                        // Test the performance of a child section provider adding a new section.
                        let section = SingleElementSection<String>(element: "Test section")
                        child.append(section)
                        lastSection = section
                        childCount += 1
                    }
                }

                depth += 1
            }

            rootSectionProvider.printStructure()

            print(parents)

            print("childCount", childCount)
            XCTAssertEqual(mapping.sectionOffset(of: lastSection), childCount - 1)
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSection), childCount - 1)

            let lastSectionProvider = parents.max(by: { $0.key < $1.key })!.value.last!
            XCTAssertEqual(mapping.sectionOffset(of: lastSectionProvider), childCount - 1)
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSectionProvider), childCount - 1)
        }
    }
}
