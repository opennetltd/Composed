import Composed
import UIKit

/// A `Composed.FlatSection` conforming to `UICollectionViewSection`
@MainActor
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

    public init(header: CollectionSupplementaryElement? = nil, footer: CollectionSupplementaryElement? = nil) {
        self.header = header
        self.footer = footer

        super.init()
    }

    open func collectionViewElementsProvider(with traitCollection: UITraitCollection) -> UICollectionViewSectionElementsProvider {
        FlatUICollectionViewSectionElementsProvider(section: self, traitCollection: traitCollection)
    }
}

extension FlatUICollectionViewSection: CollectionSelectionHandler {
    public func shouldSelect(at index: Int, cell: UICollectionViewCell) -> Bool {
        guard let sectionMeta = self.sectionForElementIndex(index) else {
            return shouldSelect(at: index)
        }

        let sectionIndex = index - sectionMeta.offset

        if let section = sectionMeta.section as? CollectionSelectionHandler {
            return section.shouldSelect(at: sectionIndex, cell: cell)
        } else if let section = sectionMeta.section as? SelectionHandler {
            return section.shouldSelect(at: sectionIndex)
        } else {
            return shouldSelect(at: index)
        }
    }

    public func didSelect(at index: Int, cell: UICollectionViewCell) {
        guard let sectionMeta = self.sectionForElementIndex(index) else {
            didSelect(at: index)
            return
        }

        let sectionIndex = index - sectionMeta.offset

        if let section = sectionMeta.section as? CollectionSelectionHandler {
            section.didSelect(at: sectionIndex, cell: cell)
        } else if let section = sectionMeta.section as? SelectionHandler {
            section.didSelect(at: sectionIndex)
        } else {
            didSelect(at: index)
        }
    }

    public func didDeselect(at index: Int, cell: UICollectionViewCell) {
        guard let sectionMeta = self.sectionForElementIndex(index) else {
            didDeselect(at: index)
            return
        }

        let sectionIndex = index - sectionMeta.offset

        if let section = sectionMeta.section as? CollectionSelectionHandler {
            section.didDeselect(at: sectionIndex, cell: cell)
        } else if let section = sectionMeta.section as? SelectionHandler {
            section.didDeselect(at: sectionIndex)
        } else {
            didDeselect(at: index)
        }
    }
}
