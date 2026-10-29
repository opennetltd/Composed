/// A section that wishes to customise how updates are performed on the collection view. If a
/// section does not conform to this protocol all updates will be treated as reloads.
///
/// This protocol should be conformed to when an update to a cell does not require a layout update.
/// For example, a section with fixed-size cells should implement ``updateMethod(forElementAt:)``
/// and return ``CellUpdateMethod/reconfigure``.
@MainActor
public protocol CollectionUpdateMethodProvider: UICollectionViewSection {
    /// Returns the update method to use for the element at the provided index.
    ///
    /// This will be called whenever the ``CollectionCoordinator`` is notified of a cell update via
    /// ``CollectionCoordinator/mapping(_:didUpdateElementsAt:)``.
    ///
    /// - parameter index: The index of the element being updated.
    /// - returns: The method to use when updating the element.
    func updateMethod(forElementAt index: Int) -> CellUpdateMethod
}
