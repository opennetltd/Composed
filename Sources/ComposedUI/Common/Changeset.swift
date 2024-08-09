import Foundation

/**
 A collection of changes to be applied in batch.
 */
public struct Changeset {
    public struct Move: Hashable {
        public var from: IndexPath
        public var to: IndexPath

        public init(from: IndexPath, to: IndexPath) {
            self.from = from
            self.to = to
        }
    }

    public struct SupplementaryViewUpdate: Hashable {
        public var indexPath: IndexPath
        public let kind: String
    }

    public var groupsInserted: Set<Int> = []
    public var groupsRemoved: Set<Int> = []
    public var elementsRemoved: Set<IndexPath> = []
    public var elementsInserted: Set<IndexPath> = []
    public var elementsMoved: Set<Move> = []

    /// The elements that have been updated. When applied in a batch of updates to a collection view
    /// these would use the index paths from _before_ the updates are applied, however these will
    /// use the index paths _after_ the updates are applied; UICollectionView has a bug that can
    /// cause updates to not be applied when applied in the same batch as deletions and Composed
    /// works around this by applying updates in a second batch.
    public var elementsUpdated: Set<IndexPath> = []

    /// The supplementary views that have been updated. This could be a layout or a contents
    /// update. All the index paths used here are the index paths _after_ all other updates have
    /// been applied and should only be used once all other batch updates have been applied.
    public var supplementaryViewUpdates: Set<SupplementaryViewUpdate> = []
}
