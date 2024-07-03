import UIKit
import Composed

/// Provides selection handling for `UICollectionView`'s
@MainActor
public protocol CollectionSelectionHandler: SelectionHandler, UICollectionViewSection {
    /// A function called when the user tries to select a cell by tapping it.
    ///
    /// - parameter cell: The cell that was tapped.
    /// - parameter index: The index of the tapped cell.
    /// - returns: `true` if the cell should be selected, otherwise `false`.
    func shouldSelectCell(_ cell: UICollectionViewCell, at index: Int) -> Bool

    /// When a selection occurs, this method will be called to notify the section
    /// - Parameters:
    ///   - index: The element index
    ///   - cell: The cell that was selected
    func didSelect(at index: Int, cell: UICollectionViewCell)

    /// When a deselection occurs, this method will be called to notify the section
    /// - Parameters:
    ///   - index: The element index
    ///   - cell: The cell that was deselected
    func didDeselect(at index: Int, cell: UICollectionViewCell)

}

public extension CollectionSelectionHandler {
    func shouldSelect(at index: Int, cell: UICollectionViewCell) -> Bool {
        shouldSelect(at: index)
    }

    func didSelect(at index: Int, cell: UICollectionViewCell) {
        didSelect(at: index)
    }
    
    func didDeselect(at index: Int, cell: UICollectionViewCell) {
        didSelect(at: index)
    }
}
