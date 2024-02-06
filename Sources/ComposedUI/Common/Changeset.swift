import Foundation

/**
 A collection of changes to be applied in batch.
 */
public struct Changeset: CustomDebugStringConvertible {
    public struct Move: Hashable {
        public var from: IndexPath
        public var to: IndexPath

        public init(from: IndexPath, to: IndexPath) {
            self.from = from
            self.to = to
        }
    }

    public var groupsInserted: Set<Int> = []
    public var groupsRemoved: Set<Int> = []
    public var groupsUpdated: Set<Int> = []
    public var elementsRemoved: Set<IndexPath> = []
    public var elementsInserted: Set<IndexPath> = []
    public var elementsMoved: Set<Move> = []
    public var elementsUpdated: Set<IndexPath> = []

    public var debugDescription: String {
        func compareMoves(lhs: Move, rhs: Move) -> Bool {
            lhs.from < rhs.from
        }

        return """
        Changeset(
            groupsInserted: \(groupsInserted.sorted(by: <)),
            groupsRemoved: \(groupsRemoved.sorted(by: <)),
            groupsUpdated: \(groupsUpdated.sorted(by: <)),
            elementsRemoved: \(elementsRemoved.sorted(by: <)),
            elementsInserted: \(elementsInserted.sorted(by: <)),
            elementsMoved: \(elementsMoved.sorted(by: compareMoves(lhs:rhs:))),
            elementsUpdated: \(elementsUpdated.sorted(by: <)),
        )
        """
    }
}
