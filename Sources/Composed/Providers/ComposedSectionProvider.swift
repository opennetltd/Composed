import Foundation

/**
 Represents an collection of `Section`'s and `SectionProvider`'s. The provider supports infinite nesting, including other `ComposedSectionProvider`'s. All children will be active at all times, so `numberOfSections` and `numberOfElements(in:)` will return values representative of all children.

 let provider = ComposedSectionProvider()
 provider.append(section1) // 5 elements
 provider.append(section2) // 3 elements

 provider.numberOfSections        // returns 2
 provider.numberOfElements(in: 0) // returns 5
 provider.numberOfElements(in: 1) // return2 3
 */
@MainActor
open class ComposedSectionProvider: SectionProvider, SectionProviderUpdateDelegate {
    /// An opaque type representing the index of a direct child, either a ``Section`` or
    /// ``SectionProvider``.
    public struct Index: Hashable {
        private enum Kind: Hashable {
            case section
            case provider
        }

        /// The index of the element in the `children` array.
        private let childrenIndex: Int

        private let kind: Kind

        private let correspondingKindIndex: Int
    }

    /// Represents either a section or a provider
    private enum Child: Equatable {
        case provider(SectionProvider)
        case section(Section)

        static func == (lhs: Child, rhs: Child) -> Bool {
            switch (lhs, rhs) {
            case let (.provider(lhs), .provider(rhs)): return lhs === rhs
            case let (.section(lhs), .section(rhs)): return lhs === rhs
            default: return false
            }
        }

        @MainActor
        var numberOfSections: Int {
            switch self {
            case .provider(let sectionProvider):
                return sectionProvider.numberOfSections
            case .section:
                return 1
            }
        }

        var isSectionProvider: Bool {
            switch self {
            case .provider:
                return true
            case .section:
                return false
            }
        }
    }

    open weak var updateDelegate: SectionProviderUpdateDelegate?

    /// Returns all the sections this provider contains
    public private(set) var sections: [Section] = []

    public private(set) var numberOfSections: Int = 0

    /// Returns all the providers this provider contains, in the order they were inserted.
    public private(set) var providers: [SectionProvider] = []

    /// Represents all of the children this provider contains
    private var children: [Child] = []

    public init() { }

    /// Returns the number of elements in the specified section
    /// - Parameter section: The section index
    /// - Returns: The number of elements
    public func numberOfElements(in section: Int) -> Int {
        sections[section].numberOfElements
    }

    /// Calculate the offset for the first section of `provider`, relative to this section provider.
    ///
    /// - parameter provider: The provide to calculate the offset of.
    /// - returns: The offset for the provider, or `nil` if it is not in the hierarchy.
    public func sectionOffset(for provider: SectionProvider) -> Int? {
        guard provider !== self else { return 0 }

        var offset: Int = 0
        /// A boolean indicating whether this provider is a direct descendant of this section
        /// provider.
        ///
        /// This is used to optimise the hot path that occurs when a child section providers
        /// notifies us of a change; rather than querying all children for the section offset of
        /// `provider` we can skip over them
        lazy var isDirectDescendant: Bool = providers.contains(where: { $0 === provider })

        for child in children {
            switch child {
            case .section:
                offset += 1
            case .provider(let childProvider):
                if isDirectDescendant, childProvider === provider {
                    return offset
                } else if !isDirectDescendant, let composedSectionProvider = childProvider as? ComposedSectionProvider, let sectionOffset = composedSectionProvider.sectionOffset(for: provider) {
                    // Nothing within Composed should ever reach this point because this is a very
                    // expensive code path. This is mostly provided for full correctness and in case
                    // any clients rely on this being possible.
                    return offset + sectionOffset
                }

                offset += childProvider.numberOfSections
            }
        }

        // Provider is not in the hierarchy.
        return nil
    }

    /// Returns the first index of the `section`, or `nil` if the section is not a child of this
    /// composed section provider.
    ///
    /// - Parameter section: The section to return the first index of.
    /// - Returns: The first index of `section`, or `nil` if the section is not a child.
    public func firstIndex(of section: Section) -> Int? {
        children.firstIndex(of: .section(section))
    }

    /// Returns the first index of the `sectionProvider`, or `nil` if the section is not a child of
    /// this composed section provider.
    ///
    /// - Parameter sectionProvider: The section provider to return the first index of.
    /// - Returns: The first index of `sectionProvider`, or `nil` if the section provider is not a child.
    public func firstIndex(of sectionProvider: SectionProvider) -> Int? {
        children.firstIndex(of: .provider(sectionProvider))
    }

    /// Appends the specified `SectionProvider` to the provider
    /// - Parameter child: The `SectionProvider` to append
    public func append(_ child: SectionProvider) {
        insert(child, at: children.count)
    }

    /// Appends the specified `Section` to the provider
    /// - Parameter child: The `Section` to append
    public func append(_ child: Section) {
        insert(child, at: children.count)
    }

    /// Inserts the specified `Section` at the given index
    /// - Parameters:
    ///   - child: The `Section` to insert
    ///   - index: The index where the `Section` should be inserted
    public func insert(_ child: Section, at index: Int) {
        assert(!contains(child), "Attempting to insert a section that is already a child")
        guard (0...children.count).contains(index) else { fatalError("Index out of bounds: \(index)") }

        performBatchUpdates { updateDelegate in
            children.insert(.section(child), at: index)
            numberOfSections += 1
            let sectionOffset = children[0..<index].reduce(into: 0) { result, child in
                result += child.numberOfSections
            }
            sections.insert(child, at: sectionOffset)
            updateDelegate?.provider(self, didInsertSections: [child], at: IndexSet(integer: sectionOffset))
        }
    }

    /// Inserts the specified `SectionProvider` at the given index
    /// - Parameters:
    ///   - child: The `SectionProvider` to insert
    ///   - index: The index where the `SectionProvider` should be inserted
    public func insert(_ child: SectionProvider, at index: Int) {
        assert(!contains(child), "Attempting to append a section provider that is already a child")
        assert(child !== self, "Attempting to append a self as a child")
        guard (0...children.count).contains(index) else { fatalError("Index out of bounds: \(index)") }

        child.updateDelegate = self

        performBatchUpdates { updateDelegate in
            children.insert(.provider(child), at: index)
            numberOfSections += child.sections.count
            #if compiler(>=6)
            let providerIndex = children[0..<index].count(where: \.isSectionProvider)
            #else
            let providerIndex = children[0..<index].filter(\.isSectionProvider).count
            #endif
            providers.insert(child, at: providerIndex)
            let firstIndex = children[0..<index].reduce(into: 0) { result, child in
                result += child.numberOfSections
            }
            let endIndex = firstIndex + child.sections.count
            sections.insert(contentsOf: child.sections, at: firstIndex)
            updateDelegate?.provider(self, didInsertSections: child.sections, at: IndexSet(integersIn: firstIndex..<endIndex))
        }
    }

    /// Removes the specified `Section`
    /// - Parameter child: The `Section` to remove
    public func remove(_ child: Section) {
        remove(.section(child))
    }

    /// Removes the specified `SectionProvider`
    /// - Parameter child: The `SectionProvider` to remove
    public func remove(_ child: SectionProvider) {
        remove(.provider(child))
    }

    private func remove(_ child: Child) {
        guard let index = children.firstIndex(of: child) else { return }
        remove(at: index)
    }

    /// Remove the child at the specified index
    /// - Parameter index: The index to remove
    public func remove(at index: Int) {
        guard children.indices.contains(index) else { return }
        let child = children[index]
        let removedSections: [Section]
        let sectionOffset: Int
        let providerIndex: Int?

        switch child {
        case let .section(child):
            removedSections = [child]
            sectionOffset = self.sectionOffset(for: child)!
            providerIndex = nil
        case let .provider(sectionProvider):
            sectionProvider.updateDelegate = nil
            sectionOffset = self.sectionOffset(for: sectionProvider)!
            removedSections = sectionProvider.sections
            providerIndex = providers.firstIndex(where: { $0 === sectionProvider })
        }

        let firstIndex = sectionOffset
        let endIndex = sectionOffset + removedSections.count

        performBatchUpdates { _ in
            children.remove(at: index)
            numberOfSections -= removedSections.count
            sections.removeSubrange(firstIndex ..< endIndex)
            if let providerIndex {
                providers.remove(at: providerIndex)
            }
            updateDelegate?.provider(self, didRemoveSections: removedSections, at: IndexSet(integersIn: firstIndex..<endIndex))
        }
    }

    public func removeAll() {
        performBatchUpdates { updateDelegate in
            for child in children.reversed() {
                remove(child)
            }
        }
    }

    public func provider(_ provider: SectionProvider, didInsertSections sections: [Section], at indexes: IndexSet) {
        assert(sections.count == indexes.count, "Number of indexes must equal number of sections inserted")

        guard let sectionOffset = sectionOffset(for: provider) else {
            assertionFailure("\(self) was notified of sections being inserted by \(provider), which is not known to this provider.")
            return
        }

        numberOfSections += sections.count

        let mappedIndexes = IndexSet(indexes.map { $0 + sectionOffset })
        zip(sections, mappedIndexes)
            .forEach { element in
                self.sections.insert(element.0, at: element.1)
            }

        updateDelegate?.provider(self, didInsertSections: sections, at: mappedIndexes)
    }

    public func provider(_ provider: SectionProvider, didRemoveSections sections: [Section], at indexes: IndexSet) {
        assert(sections.count == indexes.count, "Number of indexes must equal number of sections removed")

        guard let sectionOffset = sectionOffset(for: provider) else {
            assertionFailure("\(self) was notified of sections being removed by \(provider), which is not known to this provider.")
            return
        }

        numberOfSections -= sections.count
        let mappedIndexes = IndexSet(indexes.map { $0 + sectionOffset })
        mappedIndexes.reversed().forEach { self.sections.remove(at: $0) }

        updateDelegate?.provider(self, didRemoveSections: sections, at: mappedIndexes)
    }
}

// MARK:- Convenience Functions

extension ComposedSectionProvider {
    /// Returns a bool indicating if the composed section provider contains `section`.
    ///
    /// - Parameter section: The section to search for.
    /// - Returns: `true` if the composed section provider contains `section`, otherwise `false`.
    public func contains(_ section: Section) -> Bool {
        firstIndex(of: section) != nil
    }

    /// Returns a bool indicating if the section provider contains `sectionProvider`.
    ///
    /// - Parameter sectionProvider: The section provider to search for.
    /// - Returns: `true` if the composed section provider contains `sectionProvider`, otherwise `false`.
    public func contains(_ sectionProvider: SectionProvider) -> Bool {
        firstIndex(of: sectionProvider) != nil
    }

    /// Inserts the provided section after an existing section. If `existingSection` is not a child
    /// of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSection: The section to insert.
    ///   - existingSection: A child section of the composed section provider.
    /// - Returns: The index of the inserted section, or `nil` if `existingSection` is not a child
    ///     of this composed section.
    @discardableResult
    public func insert(_ newSection: Section, after existingSection: Section) -> Int? {
        guard let existingSectionIndex = firstIndex(of: existingSection) else { return nil }

        let newIndex = existingSectionIndex + 1
        insert(newSection, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section provider after an existing section. If `existingSection` is not
    /// a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSectionProvider: The section provider to insert.
    ///   - existingSection: A child section of the composed section provider.
    /// - Returns: The index of the inserted section provider, or `nil` if `existingSection` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSectionProvider: SectionProvider, after existingSection: Section) -> Int? {
        guard let existingSectionIndex = firstIndex(of: existingSection) else { return nil }

        let newIndex = existingSectionIndex + 1
        insert(newSectionProvider, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section after an existing section provider. If `existingSectionProvider`
    /// is not a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSection: The section to insert.
    ///   - existingSectionProvider: A child section provider of the composed section provider.
    /// - Returns: The index of the inserted section, or `nil` if `existingSectionProvider` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSection: Section, after existingSectionProvider: SectionProvider) -> Int? {
        guard let existingSectionProviderIndex = firstIndex(of: existingSectionProvider) else { return nil }

        let newIndex = existingSectionProviderIndex + 1
        insert(newSection, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section provider after an existing section provider. If `existingSectionProvider`
    /// is not a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSectionProvider: The section provider to insert.
    ///   - existingSectionProvider: A child section provider of the composed section provider.
    /// - Returns: The index of the inserted section provider, or `nil` if `existingSection` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSectionProvider: SectionProvider, after existingSectionProvider: SectionProvider) -> Int? {
        guard let existingSectionProviderIndex = firstIndex(of: existingSectionProvider) else { return nil }

        let newIndex = existingSectionProviderIndex + 1
        insert(newSectionProvider, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section before an existing section. If `existingSection` is not a child
    /// of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSection: The section to insert.
    ///   - existingSection: A child section of the composed section provider.
    /// - Returns: The index of the inserted section, or `nil` if `existingSection` is not a child
    ///     of this composed section.
    @discardableResult
    public func insert(_ newSection: Section, before existingSection: Section) -> Int? {
        guard let newIndex = firstIndex(of: existingSection) else { return nil }

        insert(newSection, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section provider before an existing section. If `existingSection` is not
    /// a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSectionProvider: The section provider to insert.
    ///   - existingSection: A child section of the composed section provider.
    /// - Returns: The index of the inserted section provider, or `nil` if `existingSection` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSectionProvider: SectionProvider, before existingSection: Section) -> Int? {
        guard let newIndex = firstIndex(of: existingSection) else { return nil }

        insert(newSectionProvider, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section before an existing section provider. If `existingSectionProvider`
    /// is not a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSection: The section to insert.
    ///   - existingSectionProvider: A child section provider of the composed section provider.
    /// - Returns: The index of the inserted section, or `nil` if `existingSectionProvider` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSection: Section, before existingSectionProvider: SectionProvider) -> Int? {
        guard let newIndex = firstIndex(of: existingSectionProvider) else { return nil }

        insert(newSection, at: newIndex)

        return newIndex
    }

    /// Inserts the provided section provider before an existing section provider. If `existingSectionProvider`
    /// is not a child of this composed section provider this function does nothing.
    ///
    /// - Parameters:
    ///   - newSectionProvider: The section provider to insert.
    ///   - existingSectionProvider: A child section provider of the composed section provider.
    /// - Returns: The index of the inserted section provider, or `nil` if `existingSection` is not
    ///     a child of this composed section.
    @discardableResult
    public func insert(_ newSectionProvider: SectionProvider, before existingSectionProvider: SectionProvider) -> Int? {
        guard let newIndex = firstIndex(of: existingSectionProvider) else { return nil }

        insert(newSectionProvider, at: newIndex)

        return newIndex
    }
}
