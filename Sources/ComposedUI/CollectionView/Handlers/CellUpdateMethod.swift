/// A method of updating a cell in a collection view.
public enum CellUpdateMethod {
    /// Perform a full reload of the cell via `UICollectionView.reloadItems(at:)`. This will also
    /// trigger the cell's layout to be updated, e.g. to accommodate size changes.
    case reload

    /// Reconfigure the cell via `UICollectionView.reconfigureItems(at:)`. Unlike a reload this will
    /// trigger the cell's layout to be updated.
    ///
    /// On iOS versions prior to 15 this will update the cell directly, if one is provided by the
    /// collection view.
    case reconfigure
}
