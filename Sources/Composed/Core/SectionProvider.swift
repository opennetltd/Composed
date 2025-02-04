import Foundation

/// Represents a collection of `Section`'s.
@MainActor
public protocol SectionProvider: AnyObject {
    /// The child sections contained in this provider
    var sections: [Section] { get }

    /// The delegate that will respond to updates
    var updateDelegate: SectionProviderUpdateDelegate? { get set }

    func sectionOffset(for section: Section) -> Int?
}

public extension SectionProvider {
    /// Returns true if the provider contains no sections or all of its sections are empty, false otherwise
    var isEmpty: Bool {
        return sections.isEmpty || sections.allSatisfy { $0.isEmpty }
    }

    var numberOfSections: Int {
        return sections.count
    }

    func sectionOffset(for section: Section) -> Int? {
        // A quick test for if this is the last child is a small optimisation, mainly
        // beneficial when the section has just been appended.
        if sections.last === section {
            return numberOfSections - 1
        }

        return sections.firstIndex(where: { $0 === section })
    }

    /// Perform multiple updates in a single batch, ensuring a single layout pass and animation is used for all updates.
    ///
    /// Changes will be reduced in to the minimal total changes required, based on the calls made to the `updateDelegate`. If
    /// no `updateDelegate` has been set the `updates` closure is called with `nil`, allowing changes to still be made.
    ///
    /// Some updates are not correct reduced, or you may wish to avoid this batching behaviour. To enable this the `forceReloadData`
    /// parameter can be set to `true`. Note that passing `true` is not supported if another batch updates that does not force reload
    /// data is currently being performed.
    ///
    /// - Parameter forceReloadData: If `true` all updates will be ignored and `reloadData` will be called after all updates are applied.
    /// - Parameter updates: A closure that applies the updates.
    func performBatchUpdates(forceReloadData: Bool = false, _ updates: (_ updateDelegate: SectionProviderUpdateDelegate?) -> Void) {
        if let updateDelegate = updateDelegate {
            updateDelegate.provider(self, willPerformBatchUpdates: {
                updates(updateDelegate)
            }, forceReloadData: forceReloadData)
        } else {
            updates(nil)
        }
    }
}

/// A delegate that will respond to update events from a `SectionProvider`
@MainActor
public protocol SectionProviderUpdateDelegate: AnyObject {
    /// Notifies the delegate that the section provider will perform a series of updates.
    ///
    /// The delegate must call the `updates` closure synchronously.
    ///
    /// - Parameter provider: The section provider that will be updated.
    /// - Parameter updates: A closure that will perform the updates.
    func provider(_ provider: SectionProvider, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool)

    /// Notifies the delegate that all sections should be invalidated, ignoring individual updates
    /// - Parameter provider: The provider that requested the invalidation
    func invalidateAll(_ provider: SectionProvider)

    /// Notifies the delegate that sections were inserted
    /// - Parameters:
    ///   - provider: The provider where the inserts occurred
    ///   - sections: The sections that were inserted
    ///   - indexes: The indexes of the sections that were inserted
    func provider(_ provider: SectionProvider, didInsertSections sections: [Section], at indexes: IndexSet)

    /// Notifies the delegate that sections were removed
    /// - Parameters:
    ///   - provider: The provider where the removes occurred
    ///   - sections: The sections that were removed
    ///   - indexes: The indexes of the sections that were removed
    func provider(_ provider: SectionProvider, didRemoveSections sections: [Section], at indexes: IndexSet)
}

// Default implementations to minimise `SectionProvider` implementation requirements
public extension SectionProviderUpdateDelegate where Self: SectionProvider {
    func provider(_ provider: SectionProvider, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool) {
        if let updateDelegate = updateDelegate {
            updateDelegate.provider(self, willPerformBatchUpdates: updates, forceReloadData: forceReloadData)
        } else {
            updates()
        }
    }

    func invalidateAll(_ provider: SectionProvider) {
        updateDelegate?.invalidateAll(self)
    }

//    func provider(_ provider: SectionProvider, didInsertSections sections: [Section], at indexes: IndexSet) {
//        updateDelegate?.provider(provider, didInsertSections: sections, at: indexes)
//    }
//
//    func provider(_ provider: SectionProvider, didRemoveSections sections: [Section], at indexes: IndexSet) {
//        updateDelegate?.provider(provider, didRemoveSections: sections, at: indexes)
//    }

}
