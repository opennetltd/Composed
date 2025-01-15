import Composed
import XCTest

final class SectionProviderMappingPerformanceTests: XCTestCase {
    func testPerformanceWithManyChildAggregateSectionProviders() {
        let rootSectionProvider = ComposedSectionProvider()
        let mapping = SectionProviderMapping(provider: rootSectionProvider)

        measure {
            let maxDepth = 2
            let childrenPerChild = 5
            var depth = 1
            var parents: [ComposedSectionProvider] = [rootSectionProvider]
            var lastSection: Section!

            var childCount = 0

            while depth <= maxDepth {
                var newParents: [ComposedSectionProvider] = []

                for parent in parents {
                    for _ in 0 ..< childrenPerChild {
                        let child = ComposedSectionProvider()
                        parent.append(child)
                        newParents.append(child)
                        // Test the performance of a child section provider adding a new section.
                        let section = SingleElementSection<String>(element: "Test section")
                        child.append(section)
                        lastSection = section
                        childCount += 1
                    }
                }

                parents = newParents
                depth += 1
            }

            XCTAssertEqual(mapping.sectionOffset(of: lastSection), childCount - 1)

            let lastSectionProvider = parents.last!
            XCTAssertEqual(mapping.sectionOffset(of: lastSectionProvider), childCount - 1)
        }
    }
}
