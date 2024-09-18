import Foundation
import UIKit

/**
 A value that collects and reduces a multiple changes to allow them
 to be applied in a single batch of updated.

 The logic of how to reduce the changes is designed to match that of `UICollectionView`. It may
 also work for `UITableView` but this has not been tested.

 `ChangesReducer` uses the generalised terms "group" and "element", which can be mapped directly
 to "section" and "row" for `UITableView`s and "section" and "item" for `UICollectionView`.

 The documentation on how updates are applied by `UICollectionView` is incomplete and does not
 account for all scenarios.

 https://developer.apple.com/videos/play/wwdc2018/225/ provides some good insight in to how `UICollectionView`
 applies batched changes. Page 62 of the slides PDF provides a useful – although incomplete – table that describes the
 order changes are applied, along with the context that each kind of change is applied using.

 Element removals are handled _before_ section removals, which is validated by the `testGroupAndElementRemoves`
 tests in both the `ChangesReducerTests` and `CollectionCoordinatorTests`.
 */
internal struct ChangesReducer: CustomReflectable {
    /// `true` when `beginUpdating` has been called more than `endUpdating`.
    internal var hasActiveUpdates: Bool {
        return activeBatches > 0
    }

    internal var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "activeBatches": activeBatches,
                "changeset": changeset,
            ]
        )
    }

    /// A count of active update batches, e.g. how many
    /// more times `beginUpdating` has been called than `endUpdating`.
    private var activeBatches = 0

    /// The changeset for the current batch of updates.
    private var changeset: Changeset = Changeset()

    internal init() {}

    /// Clears existing updates, keeping active updates count.
    internal mutating func clearUpdates() {
        changeset = Changeset()
    }

    /// Begin a batch of updates. This must be called prior to making updates.
    ///
    /// It is possible to call this function multiple times to build up a batch of changes.
    ///
    /// All calls to this must be balanced with a call to `endUpdating`.
    internal mutating func beginUpdating() {
        activeBatches += 1
    }

    /// End a batch of updates. There may be more than 1 batch of updates at the same time.
    ///
    /// - Returns: The completed changeset, if this is the last batch of updates.
    internal mutating func endUpdating() -> Changeset? {
        activeBatches -= 1

        guard activeBatches == 0 else {
            assert(activeBatches > 0, "`endUpdating` calls must be balanced with `beginUpdating`")
            return nil
        }

        let changeset = self.changeset
        self.changeset = Changeset()
        return changeset
    }

    internal func groupIndexBeforeChanges(currentGroup: Int) -> Int {
        transformSection(currentGroup)
    }

    internal mutating func insertGroups(_ groups: IndexSet) {
        groups.forEach { insertedGroup in
            let insertedGroup = insertedGroup

            changeset.groupsInserted = Set(changeset.groupsInserted.map { existingInsertedGroup in
                if existingInsertedGroup >= insertedGroup {
                    return existingInsertedGroup + 1
                }

                return existingInsertedGroup
            })

            changeset.groupsInserted.insert(insertedGroup)

            changeset.elementsInserted = Set(changeset.elementsInserted.map { insertedIndexPath in
                var insertedIndexPath = insertedIndexPath

                if insertedIndexPath.section >= insertedGroup {
                    insertedIndexPath.section += 1
                }

                return insertedIndexPath
            })

            changeset.elementsUpdated = Set(changeset.elementsUpdated.map { updatedIndexPath in
                var updatedIndexPath = updatedIndexPath

                if updatedIndexPath.section >= insertedGroup {
                    updatedIndexPath.section += 1
                }

                return updatedIndexPath
            })

            changeset.supplementaryViewUpdates = Set(changeset.supplementaryViewUpdates.map { updatedSupplementaryView in
                var updatedSupplementaryView = updatedSupplementaryView

                if updatedSupplementaryView.indexPath.section >= insertedGroup {
                    updatedSupplementaryView.indexPath.section += 1
                }

                return updatedSupplementaryView
            })

            changeset.elementsMoved = Set(changeset.elementsMoved.map { move in
                var move = move

                if move.from.section > insertedGroup {
                    move.from.section += 1
                }

                if move.to.section > insertedGroup {
                    move.to.section += 1
                }

                return move
            })
        }
    }

    internal mutating func removeGroups(_ groups: [Int]) {
        removeGroups(IndexSet(groups))
    }

    internal mutating func removeGroups(_ groups: IndexSet) {
        groups.sorted(by: >).forEach { removedGroup in
            changeset.elementsUpdated = Set(changeset.elementsUpdated.compactMap { updatedIndexPath in
                guard updatedIndexPath.section != removedGroup else { return nil }

                var updatedIndexPath = updatedIndexPath

                if updatedIndexPath.section > removedGroup {
                    updatedIndexPath.section -= 1
                }

                return updatedIndexPath
            })

            changeset.supplementaryViewUpdates = Set(changeset.supplementaryViewUpdates.compactMap { updatedSupplementaryView in
                guard updatedSupplementaryView.indexPath.section != removedGroup else { return nil }

                var updatedSupplementaryView = updatedSupplementaryView

                if updatedSupplementaryView.indexPath.section > removedGroup {
                    updatedSupplementaryView.indexPath.section -= 1
                }

                return updatedSupplementaryView
            })

            if changeset.groupsInserted.remove(removedGroup) != nil {
                changeset.groupsInserted = Set(changeset.groupsInserted.map { insertedGroup in
                    if insertedGroup > removedGroup {
                        return insertedGroup - 1
                    }

                    return insertedGroup
                })
            } else {
                let transformedRemovedGroup = transformSection(removedGroup)

                changeset.groupsInserted = Set(changeset.groupsInserted.map { insertedGroup in
                    if insertedGroup > removedGroup {
                        return insertedGroup - 1
                    }

                    return insertedGroup
                })

                changeset.groupsRemoved.insert(transformedRemovedGroup)
            }

            changeset.elementsRemoved = Set(changeset.elementsRemoved.filter { $0.section != removedGroup })

            changeset.elementsInserted = Set(changeset.elementsInserted.compactMap { insertedIndexPath in
                guard insertedIndexPath.section != removedGroup else { return nil }

                var batchedRowInsert = insertedIndexPath

                if batchedRowInsert.section > removedGroup {
                    batchedRowInsert.section -= 1
                }

                return batchedRowInsert
            })

            changeset.elementsMoved = Set(changeset.elementsMoved.compactMap { move in
                guard move.to.section != removedGroup else { return nil }

                var move = move

                if move.from.section > removedGroup {
                    move.from.section -= 1
                }

                if move.to.section > removedGroup {
                    move.to.section -= 1
                }

                return move
            })
        }
    }

    internal mutating func insertElements(at indexPaths: [IndexPath]) {
        indexPaths.forEach { insertedIndexPath in
            guard !changeset.groupsInserted.contains(insertedIndexPath.section) else { return }

            changeset.elementsInserted = Set(changeset.elementsInserted.map { existingInsertedIndexPath in
                guard existingInsertedIndexPath.section == insertedIndexPath.section else {
                    // Different section; don't modify
                    return existingInsertedIndexPath
                }

                var existingInsertedIndexPath = existingInsertedIndexPath

                if existingInsertedIndexPath.item >= insertedIndexPath.item {
                    existingInsertedIndexPath.item += 1
                }

                return existingInsertedIndexPath
            })

            changeset.elementsUpdated = Set(changeset.elementsUpdated.map { existingUpdatedIndexPath in
                guard existingUpdatedIndexPath.section == insertedIndexPath.section else {
                    // Different section; don't modify
                    return existingUpdatedIndexPath
                }

                var existingUpdatedIndexPath = existingUpdatedIndexPath

                if existingUpdatedIndexPath.item >= insertedIndexPath.item {
                    existingUpdatedIndexPath.item += 1
                }

                return existingUpdatedIndexPath
            })

            changeset.elementsInserted.insert(insertedIndexPath)
        }
    }

    internal mutating func removeElements(at indexPaths: [IndexPath]) {
        /**
         Element removals are handled before all other updates.
         */
        indexPaths.sorted(by: { $0.item > $1.item }).forEach { removedIndexPath in
            let originalRemovedIndexPath = removedIndexPath
            let removedIndexPath = transformIndexPath(removedIndexPath)

            guard !changeset.groupsInserted.contains(removedIndexPath.section) else { return }

            let originalWasInInserted = changeset.elementsInserted.contains(originalRemovedIndexPath)

            if !originalWasInInserted {
                changeset.elementsRemoved.insert(removedIndexPath)
            }

            changeset.elementsInserted = Set(changeset.elementsInserted.compactMap { existingInsertedIndexPath in
                guard existingInsertedIndexPath.section == originalRemovedIndexPath.section else {
                    // Different section; don't modify
                    return existingInsertedIndexPath
                }

                var existingInsertedIndexPath = existingInsertedIndexPath

                if existingInsertedIndexPath.item > originalRemovedIndexPath.item {
                    existingInsertedIndexPath.item -= 1
                } else if existingInsertedIndexPath.item == originalRemovedIndexPath.item {
                    return nil
                }

                return existingInsertedIndexPath
            })

            changeset.elementsUpdated = Set(changeset.elementsUpdated.compactMap { existingUpdatedIndexPath in
                guard existingUpdatedIndexPath.section == originalRemovedIndexPath.section else {
                    // Different section; don't modify
                    return existingUpdatedIndexPath
                }

                var existingUpdatedIndexPath = existingUpdatedIndexPath

                if existingUpdatedIndexPath.item > originalRemovedIndexPath.item {
                    existingUpdatedIndexPath.item -= 1
                } else if existingUpdatedIndexPath.item == originalRemovedIndexPath.item {
                    return nil
                }

                return existingUpdatedIndexPath
            })
        }
    }

    internal mutating func updateElements(at indexPaths: [IndexPath]) {
        indexPaths.sorted(by: { $0.item > $1.item }).forEach { updatedElement in
            guard !changeset.elementsInserted.contains(updatedElement) else { return }
            guard !changeset.groupsInserted.contains(updatedElement.section) else { return }

            changeset.elementsUpdated.insert(updatedElement)
        }
    }

    internal mutating func moveElements(_ moves: [Changeset.Move]) {
        changeset.elementsMoved.formUnion(moves)
    }

    internal mutating func moveElements(_ moves: [(from: IndexPath, to: IndexPath)]) {
        moveElements(moves.map { Changeset.Move(from: $0.from, to: $0.to) })
    }

    @MainActor
    internal mutating func reloadHeader(_ indexPath: IndexPath) {
        changeset.supplementaryViewUpdates.insert(Changeset.SupplementaryViewUpdate(indexPath: indexPath, kind: UICollectionView.elementKindSectionHeader))
    }

    private func transformIndexPath(_ indexPath: IndexPath) -> IndexPath {
        var indexPath = indexPath

        indexPath.section = transformSection(indexPath.section)
        indexPath.item = transformItem(indexPath.item, inSection: indexPath.section)

        return indexPath
    }

    /// Transforms the provided section to be the index it would have been prior to
    /// all currently applied changes.
    ///
    /// - Parameter section: The section index to transform.
    /// - Returns: The transformed section index.
    private func transformSection(_ section: Int) -> Int {
        let groupsRemoved = changeset.groupsRemoved
        let groupsInserted = changeset.groupsInserted

        guard !groupsRemoved.isEmpty || !groupsInserted.isEmpty else { return section }

        let availableSpaces = (0..<Int.max)
            .lazy
            .filter { !groupsRemoved.contains($0) }
        let section = section - groupsInserted.filter { $0 < section }.count
        let availableSpaceIndex = availableSpaces.index(availableSpaces.startIndex, offsetBy: section)

        return availableSpaces[availableSpaceIndex]
    }

    /// Transforms the provided item to be the index it would have been prior to
    /// all currently applied changes.
    ///
    /// - Parameter item: The item index to transform.
    /// - Parameter section: The section index to the item belongs to.
    /// - Returns: The transformed item index.
    private func transformItem(_ item: Int, inSection section: Int) -> Int {
        func isIncluded(indexPath: IndexPath) -> Bool {
            indexPath.section == section
        }

        let itemsRemoved = changeset.elementsRemoved.filter(isIncluded(indexPath:))
        let itemsInserted = changeset.elementsInserted.filter(isIncluded(indexPath:))

        let availableSpaces = (0..<Int.max)
            .lazy
            .filter { !itemsRemoved.contains(IndexPath(item: $0, section: section)) }
        let item = item - itemsInserted.filter({ $0.item < item }).count
        let availableSpaceIndex = availableSpaces.index(availableSpaces.startIndex, offsetBy: item)

        return availableSpaces[availableSpaceIndex]
    }
}
