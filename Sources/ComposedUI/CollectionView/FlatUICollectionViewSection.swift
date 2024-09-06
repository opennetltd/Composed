import Composed
import UIKit

/// A `Composed.FlatSection` conforming to `UICollectionViewSection`
open class FlatUICollectionViewSection: FlatSection, UICollectionViewSection {
    public var header: CollectionSupplementaryElement? {
        didSet {
            updateDelegate?.sectionDidInvalidateHeader(self)
        }
    }

    public var footer: CollectionSupplementaryElement? {
        didSet {
            updateDelegate?.sectionDidInvalidateFooter(self)
        }
    }

    private var cachedElementsProvider: (elementsProvider: FlatUICollectionViewSectionElementsProvider, traitCollection: UITraitCollection)?

    public init(header: CollectionSupplementaryElement? = nil, footer: CollectionSupplementaryElement? = nil) {
        self.header = header
        self.footer = footer

        super.init()
    }

    open func collectionViewElementsProvider(with traitCollection: UITraitCollection) -> UICollectionViewSectionElementsProvider {
        if let cachedElementsProvider, cachedElementsProvider.traitCollection == traitCollection {
            return cachedElementsProvider.elementsProvider
        } else {
            let elementsProvider = FlatUICollectionViewSectionElementsProvider(
                section: self,
                traitCollection: traitCollection
            )
            cachedElementsProvider = (elementsProvider, traitCollection)
            return elementsProvider
        }
    }
}

extension FlatUICollectionViewSection: CollectionSelectionHandler {
    public func didSelect(at index: Int, cell: UICollectionViewCell) {
        guard let sectionMeta = self.sectionForElementIndex(index) else { return }

        let sectionIndex = index - sectionMeta.offset

        if let section = sectionMeta.section as? CollectionSelectionHandler {
            section.didSelect(at: sectionIndex, cell: cell)
        } else if let section = sectionMeta.section as? SelectionHandler {
            section.didSelect(at: sectionIndex)
        }
    }

    public func didDeselect(at index: Int, cell: UICollectionViewCell) {
        guard let sectionMeta = self.sectionForElementIndex(index) else { return }

        let sectionIndex = index - sectionMeta.offset

        if let section = sectionMeta.section as? CollectionSelectionHandler {
            section.didDeselect(at: sectionIndex, cell: cell)
        } else if let section = sectionMeta.section as? SelectionHandler {
            section.didDeselect(at: sectionIndex)
        }
    }
}
