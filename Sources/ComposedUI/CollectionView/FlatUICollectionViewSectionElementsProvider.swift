import UIKit
import Composed

open class FlatUICollectionViewSectionElementsProvider: UICollectionViewSectionElementsProvider {
    /// The header configuration element
    public var header: CollectionSupplementaryElement? {
        guard let flatSection = flatSection else { return nil }
        guard let header = flatSection.header else { return nil }
        let kind: CollectionElementKind
        if case .automatic = header.kind {
            kind = .custom(kind: UICollectionView.elementKindSectionHeader)
        } else {
            kind = header.kind
        }

        return CollectionSupplementaryElement(
            section: flatSection,
            dequeueMethod: header.dequeueMethod,
            reuseIdentifier: header.reuseIdentifier,
            kind: kind,
            configure: header.configure
        )
    }

    /// The footer configuration element
    public var footer: CollectionSupplementaryElement? {
        guard let flatSection = flatSection else { return nil }
        guard let footer = flatSection.footer else { return nil }
        let kind: CollectionElementKind
        if case .automatic = footer.kind {
            kind = .custom(kind: UICollectionView.elementKindSectionFooter)
        } else {
            kind = footer.kind
        }

        return CollectionSupplementaryElement(
            section: flatSection,
            dequeueMethod: footer.dequeueMethod,
            reuseIdentifier: footer.reuseIdentifier,
            kind: kind,
            configure: footer.configure
        )
    }

    /// The number of elements in this section
    open var numberOfElements: Int {
        return flatSection?.numberOfElements ?? 0
    }

    // The underlying section associated with this section
    private weak var flatSection: FlatUICollectionViewSection?

    private let traitCollection: UITraitCollection

    /// Makes a new configuration with the specified cell, header and/or footer elements
    /// - Parameters:
    ///   - section: The section this will be associated with
    ///   - cell: The cell configuration element
    ///   - header: The header configuration element
    ///   - footer: The footer configuration element
    public init(
        section: FlatUICollectionViewSection,
        traitCollection: UITraitCollection
    ) {
        self.flatSection = section
        self.traitCollection = traitCollection
    }

    open func cell(for index: Int) -> CollectionCellElement {
        guard let (section, offset) = flatSection?.sectionForElementIndex(index) else {
            fatalError("No section for index \(index) exists")
        }

        guard let collectionSectionProvider = section as? UICollectionViewSection else {
            fatalError("Child must conform to `CollectionSectionProvider`")
        }

        let indexInSection = index - offset
        let collectionSection = collectionSectionProvider.collectionViewElementsProvider(with: traitCollection)
        let collectionCellElement = collectionSection.cell(for: indexInSection)
        return FlattenedCollectionCellElement(collectionElement: collectionCellElement, section: section, sectionOffset: offset)
    }
}

private final class FlattenedCollectionCellElement: CollectionCellElement {
    fileprivate init(collectionElement element: CollectionCellElement, section: Section, sectionOffset: Int) {
        super.init(
            dequeueMethod: element.dequeueMethod,
            reuseIdentifier: element.reuseIdentifier,
            configure: { [weak section] cell, index in
                guard let section = section else { return }

                let sectionIndex = index - sectionOffset
                element.configure(cell, sectionIndex, section)
            },
            willAppear: { [weak section] cell, index in
                guard let section = section else { return }

                let sectionIndex = index - sectionOffset
                element.willAppear?(cell, sectionIndex, section)
            },
            didDisappear: { [weak section] cell, index in
                guard let section = section else { return }

                let sectionIndex = index - sectionOffset
                element.didDisappear?(cell, sectionIndex, section)
            }
        )
    }
}
