import Composed
import UIKit

/// A type that handles taps on individual cells.
///
/// When conforming to this protocol do not implement any of the methods from
/// ``CollectionSelectionHandler``; only implement ``didTapElement(at:cell:)`` or
/// `didTapElement(at:)` and handle the tap there.
public protocol CollectionTapSelectionHandler: CollectionSelectionHandler, TapSelectionHandler {
    /// A function called when the user taps a cell.
    ///
    /// - parameter cell: The cell that was tapped.
    /// - parameter index: The index of the cell that was tapped.
    func didTapCell(_ cell: UICollectionViewCell, at index: Int)
}

extension CollectionTapSelectionHandler {
    public func shouldSelectCell(_ cell: UICollectionViewCell, at index: Int) -> Bool {
        didTapCell(cell, at: index)
        return false
    }
}
