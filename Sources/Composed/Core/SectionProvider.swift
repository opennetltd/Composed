import Foundation

/// Represents a collection of `Section`'s.
@MainActor
public protocol SectionProvider: AnyObject {
    /// The child sections contained in this provider
    var sections: [Section] { get }

    /// The delegate that will respond to updates
    var updateDelegate: SectionProviderUpdateDelegate? { get set }

    /// Calculates the offset to be used for the provided section.
    ///
    /// This should always be the index of the `section` within ``sections``. This API allows for
    /// implementers to provide an optimised version of this lookup, if possible.
    ///
    /// - parameter section: The section to find the index for.
    /// - returns: The index of the `section`, or `nil` if it is not included in ``sections``.
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
        // A quick test for if this is the last child is a small optimisation, mainly beneficial
        // when the section has just been appended.
        if sections.last === section {
            return numberOfSections - 1
        }

        return sections.firstIndex(where: { $0 === section })
    }

    /// Perform multiple updates in a single batch, allowing the data to be kept in-sync with the UI
    /// layer and the updates are applied in a single action.
    ///
    /// Changes will be reduced in to the minimal total changes required, based on the calls made to
    /// the `updateDelegate`. If no `updateDelegate` has been set the `updates` closure is called
    /// with `nil`, allowing the data changes to still be made.
    ///
    /// If `forceReloadData` is used then all batching of UI updates will be ignored. This
    /// effectively bypasses calculation of the minimal total changes required and can cause a lot
    /// of extra work for the UI. This option is not recommended.
    ///
    /// - parameter forceReloadData: If `true` all individual updates will be ignored and
    ///   `reloadData` will be called after the `updates` closure finishes.
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

/// A delegate that will respond to update events from a `SectionProvider`.
///
/// For performance reasons it is expected that the `provider` parameter for all of these functions
/// should be `self`; if a child provider triggered the changes any indexes should be mapped to that
/// of the provider making the delegate call.
@MainActor
public protocol SectionProviderUpdateDelegate: AnyObject {
    /// Notifies the delegate that the section provider will perform a series of updates. These
    /// updates will be applied to the UI in a single action with the minimal diff that can be
    /// inferred.
    ///
    /// All data changes, namely inserting and removing sections, must be done from inside the
    /// `updates` closure.
    ///
    /// The delegate must call the `updates` closure synchronously.
    ///
    /// - parameter provider: The section provider that will be updated. Should always be `self`.
    /// - parameter updates: A closure that will perform the updates.
    /// - parameter forceReloadData: When `true` the full structure of the data – and any
    ///   corresponding UI – will be fully reloaded. This is not recommended as this can be very
    ///   expensive to perform.
    func provider(_ provider: SectionProvider, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool)

    /// Notifies the delegate that all sections should be invalidated, ignoring individual updates.
    ///
    /// In most cases this is the same as calling
    /// ``provider(_:willPerformBatchUpdates:forceReloadData:)`` with `forceReloadData: true` and
    /// should not be used.
    ///
    /// - parameter provider: The provider that requested the invalidation. Should always be `self`.
    func invalidateAll(_ provider: SectionProvider)

    /// Notifies the delegate that a collection of sections were inserted at the provided indices.
    ///
    /// The length of `sections` and `indices` must be equal.
    ///
    /// - parameter provider: The provider where the sections were inserted. Should always be
    ///   `self`.
    /// - parameter sections: The sections that were inserted.
    /// - parameter indices: The indices of the sections that were inserted.
    func provider(_ provider: SectionProvider, didInsertSections sections: [Section], at indices: IndexSet)

    /// Notifies the delegate that a collection of sections were removed from the provided indices.
    ///
    /// The length of `sections` and `indices` must be equal.
    ///
    /// - parameter provider: The provider where the sections were removed. Should always be `self`.
    /// - parameter sections: The sections that were removed.
    /// - parameter indices: The indices of the sections that were removed.
    func provider(_ provider: SectionProvider, didRemoveSections sections: [Section], at indexes: IndexSet)
}

// Default implementations to minimise `SectionProvider` implementation requirements
extension SectionProviderUpdateDelegate where Self: SectionProvider {
    public func provider(_ provider: SectionProvider, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool) {
        if let updateDelegate = updateDelegate {
            updateDelegate.provider(self, willPerformBatchUpdates: updates, forceReloadData: forceReloadData)
        } else {
            updates()
        }
    }

    public func invalidateAll(_ provider: SectionProvider) {
        updateDelegate?.invalidateAll(self)
    }
}
