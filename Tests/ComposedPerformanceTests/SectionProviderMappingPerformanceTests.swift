import Composed
import XCTest

@MainActor
final class SectionProviderMappingPerformanceTests: XCTestCase {
    private let maxDepth = 6
    private let childrenPerChild = 5

    func testPerformanceOfFindingLastSectionOffset() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
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

            startMeasuring()
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSection), childCount - 1)
            stopMeasuring()
        }
    }

    func testPerformanceOfFindingLastSectionProviderOffset() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
            var depth = 1
            var parents: [Int: [ComposedSectionProvider]] = [0: [rootSectionProvider]]
            var lastSectionProvider: ComposedSectionProvider!

            var childCount = 0

            while depth <= maxDepth {
                for parent in parents[depth - 1, default: []] {
                    for _ in 0 ..< childrenPerChild {
                        let child = ComposedSectionProvider()
                        parent.append(child)
                        lastSectionProvider = child
                        parents[depth, default: []].append(child)
                        // Test the performance of a child section provider adding a new section.
                        let section = SingleElementSection<String>(element: "Test section")
                        child.append(section)
                        childCount += 1
                    }
                }

                depth += 1
            }

            startMeasuring()
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSectionProvider), childCount - 1)
            stopMeasuring()
        }
    }

    func testPerformanceOfFindingSectionProviderBeforeLastOffset() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
            var depth = 1
            var parents: [Int: [ComposedSectionProvider]] = [0: [rootSectionProvider]]
            var sections: [Section] = []

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
                        sections.append(section)
                        childCount += 1
                    }
                }

                depth += 1
            }

            let sectionBeforeLast = sections[sections.index(before: sections.indices.last!)]
            startMeasuring()
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: sectionBeforeLast), childCount - 2)
            stopMeasuring()
        }
    }

    func testPerformanceOfFindingSectionBeforeLastOffset() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
            var depth = 1
            var parents: [Int: [ComposedSectionProvider]] = [0: [rootSectionProvider]]
            var sectionProviders: [ComposedSectionProvider] = []

            var childCount = 0

            while depth <= maxDepth {
                for parent in parents[depth - 1, default: []] {
                    for _ in 0 ..< childrenPerChild {
                        let child = ComposedSectionProvider()
                        parent.append(child)
                        sectionProviders.append(child)
                        parents[depth, default: []].append(child)
                        // Test the performance of a child section provider adding a new section.
                        let section = SingleElementSection<String>(element: "Test section")
                        child.append(section)
                        childCount += 1
                    }
                }

                depth += 1
            }

            let sectionProviderBeforeLast = sectionProviders[sectionProviders.index(before: sectionProviders.indices.last!)]
            startMeasuring()
            XCTAssertEqual(rootSectionProvider.sectionOffset(for: sectionProviderBeforeLast), childCount - 2)
            stopMeasuring()
        }
    }

    func testPerformanceOfAddingManyChildrenWithManyNodesInTree() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
            var depth = 1
            var parents: [Int: [ComposedSectionProvider]] = [0: [rootSectionProvider]]
            var lastSection: Section!
            var lastSectionProvider: ComposedSectionProvider!

            var childCount = 0

            startMeasuring()
            while depth <= maxDepth {
                for parent in parents[depth - 1, default: []] {
                    for _ in 0 ..< childrenPerChild {
                        let child = ComposedSectionProvider()
                        parent.append(child)
                        lastSectionProvider = child
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
            stopMeasuring()

            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSection), childCount - 1)

            XCTAssertEqual(rootSectionProvider.sectionOffset(for: lastSectionProvider), childCount - 1)
        }
    }

    func testPerformanceOfAddingManyChildrenToSingleComposedSectionProvider() {
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions.update(with: .manuallyStart)
        measureOptions.invocationOptions.update(with: .manuallyStop)
        measure(options: measureOptions) {
            let rootSectionProvider = ComposedSectionProvider()
            var depth = 1

            startMeasuring()
            while depth <= maxDepth {
                for _ in 0 ..< depth * childrenPerChild {
                    for _ in 0 ..< childrenPerChild {
                        let child = SingleElementSection<String>(element: "Test section")
                        rootSectionProvider.append(child)
                    }
                }

                depth += 1
            }
            stopMeasuring()
        }
    }
}
