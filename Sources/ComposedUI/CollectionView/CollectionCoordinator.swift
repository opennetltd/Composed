import UIKit
import Composed
import os.log

/// Conform to this protocol to receive `CollectionCoordinator` events
public protocol CollectionCoordinatorDelegate: AnyObject {

    /// Return a background view to be shown in the `UICollectionView` when its content is empty. Defaults to nil
    /// - Parameters:
    ///   - coordinator: The coordinator that manages this collection view
    ///   - collectionView: The collection view that will show this background view
    func coordinator(_ coordinator: CollectionCoordinator, backgroundViewInCollectionView collectionView: UICollectionView) -> UIView?

    /// Called whenever the coordinator's content updates
    /// - Parameter coordinator: The coordinator that manages the updates
    func coordinatorDidUpdate(_ coordinator: CollectionCoordinator)
}

public extension CollectionCoordinatorDelegate {
    func coordinator(_ coordinator: CollectionCoordinator, backgroundViewInCollectionView collectionView: UICollectionView) -> UIView? { return nil }
    func coordinatorDidUpdate(_ coordinator: CollectionCoordinator) { }
}

/// The coordinator that provides the 'glue' between a section provider and a `UICollectionView`
open class CollectionCoordinator: NSObject {
    private struct NIBRegistration: Hashable {
        let nibName: String
        let bundle: Bundle
        let reuseIdentifier: String
        let supplementaryViewKind: String?

        internal init(nibName: String, bundle: Bundle, reuseIdentifier: String, supplementaryViewKind: String? = nil) {
            self.nibName = nibName
            self.bundle = bundle
            self.reuseIdentifier = reuseIdentifier
            self.supplementaryViewKind = supplementaryViewKind
        }
    }

    private struct ClassRegistration: Equatable {
        static func == (lhs: CollectionCoordinator.ClassRegistration, rhs: CollectionCoordinator.ClassRegistration) -> Bool {
            lhs.class == rhs.class && lhs.reuseIdentifier == rhs.reuseIdentifier && lhs.supplementaryViewKind == rhs.supplementaryViewKind
        }

        let `class`: UIView.Type
        let reuseIdentifier: String
        let supplementaryViewKind: String?

        internal init(class: UIView.Type, reuseIdentifier: String, supplementaryViewKind: String? = nil) {
            self.class = `class`
            self.reuseIdentifier = reuseIdentifier
            self.supplementaryViewKind = supplementaryViewKind
        }
    }

    /// Get/set the delegate for this coordinator
    public weak var delegate: CollectionCoordinatorDelegate? {
        didSet { collectionView.backgroundView = delegate?.coordinator(self, backgroundViewInCollectionView: collectionView) }
    }

    /// Returns the root section provider associated with this coordinator
    public var sectionProvider: SectionProvider {
        return mapper.provider
    }

    /// If `true` this `CollectionCoordinator` instance will log changes to the system log.
    public var enableLogs: Bool = false

    /// A closure that will be called whenever a debug log message is produced.
    public var logger: ((_ message: String) -> Void)?

    internal var changesReducer = ChangesReducer()

    /// A flag indicating if the `updates` closure is currently being called in a call to `performBatchUpdates`.
    ///
    /// This is used to prevent multiple calls to `performBatchUpdates` once all the updates have been applied to
    /// the collection view, which can cause the data to be out of sync.
    fileprivate var isPerformingUpdates = false

    /// A (temporary) flag that is set to `true` when batch updates should be ignored because `reloadData`
    /// will be called after the updates.
    fileprivate var reloadDataBatchUpdates = false

    private var mapper: SectionProviderMapping

    private let collectionView: UICollectionView

    private weak var originalDelegate: UICollectionViewDelegate?
    private var delegateObserver: NSKeyValueObservation?

    private weak var originalDataSource: UICollectionViewDataSource?
    private var dataSourceObserver: NSKeyValueObservation?

    private weak var originalDragDelegate: UICollectionViewDragDelegate?
    private var dragDelegateObserver: NSKeyValueObservation?

    private weak var originalDropDelegate: UICollectionViewDropDelegate?
    private var dropDelegateObserver: NSKeyValueObservation?

    private var cachedElementsProviders: [UICollectionViewSectionElementsProvider] = []
    private var cellSectionMap = [UICollectionViewCell: (CollectionCellElement, Section)]()

    // Prevent registering the same cell multiple times; this might break reuse.
    // See: https://developer.apple.com/forums/thread/681739
    // The post applies to the newer API, but maybe it was always true?
    private var nibRegistrations = Set<NIBRegistration>()
    private var classRegistrations = [ClassRegistration]()

    /// Make a new coordinator with the specified collectionView and sectionProvider
    /// - Parameters:
    ///   - collectionView: The collectionView to associate with this coordinator
    ///   - sectionProvider: The sectionProvider to associate with this coordinator
    public init(collectionView: UICollectionView, sectionProvider: SectionProvider) {
        self.collectionView = collectionView
        mapper = SectionProviderMapping(provider: sectionProvider)

        super.init()
        prepareSections()

        delegateObserver = collectionView.observe(\.delegate, options: [.initial, .new]) { [weak self] collectionView, _ in
            guard collectionView.delegate !== self else { return }
            self?.originalDelegate = collectionView.delegate
            collectionView.delegate = self
        }

        dataSourceObserver = collectionView.observe(\.dataSource, options: [.initial, .new]) { [weak self] collectionView, _ in
            guard collectionView.dataSource !== self else { return }
            self?.originalDataSource = collectionView.dataSource
            collectionView.dataSource = self
        }

        dragDelegateObserver = collectionView.observe(\.dragDelegate, options: [.initial, .new]) { [weak self] collectionView, _ in
            guard collectionView.dragDelegate !== self else { return }
            self?.originalDragDelegate = collectionView.dragDelegate
            collectionView.dragDelegate = self
        }

        dropDelegateObserver = collectionView.observe(\.dropDelegate, options: [.initial, .new]) { [weak self] collectionView, _ in
            guard collectionView.dropDelegate !== self else { return }
            self?.originalDropDelegate = collectionView.dropDelegate
            collectionView.dropDelegate = self
        }

        collectionView.register(PlaceholderSupplementaryView.self,
                                forSupplementaryViewOfKind: PlaceholderSupplementaryView.kind,
                                withReuseIdentifier: PlaceholderSupplementaryView.reuseIdentifier)
    }

    /// Replaces the current sectionProvider with the specified provider
    /// - Parameter sectionProvider: The new sectionProvider
    open func replace(sectionProvider: SectionProvider) {
        mapper = SectionProviderMapping(provider: sectionProvider)
        prepareSections()
        collectionView.reloadData()
    }

    /// Enables / disables editing on this coordinator
    /// - Parameters:
    ///   - editing: True if editing should be enabled, false otherwise
    ///   - animated: If true, the change should be animated
    public func setEditing(_ editing: Bool, animated: Bool) {
        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: animated) }

        for (index, section) in sectionProvider.sections.enumerated() {
            guard let handler = section as? EditingHandler else { continue }
            handler.didSetEditing(editing)

            for item in 0..<section.numberOfElements {
                let indexPath = IndexPath(item: item, section: index)

                if let handler = handler as? CollectionEditingHandler, let cell = collectionView.cellForItem(at: indexPath) {
                    handler.didSetEditing(editing, at: item, cell: cell, animated: animated)
                } else {
                    handler.didSetEditing(editing, at: item)
                }
            }
        }
    }

    /// Invalidates the current layout with the specified context
    /// - Parameter context: The invalidation context to apply during the invalidate (optional)
    open func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext? = nil) {
        guard collectionView.window != nil else { return }

        if let context = context {
            collectionView.collectionViewLayout.invalidateLayout(with: context)
        } else {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    open func invalidateVisibleCells() {
        for (indexPath, cell) in zip(collectionView.indexPathsForVisibleItems, collectionView.visibleCells) {
            let elements = elementsProvider(for: indexPath.section)
            elements.cell(for: indexPath.item).configure(cell, indexPath.item, mapper.provider.sections[indexPath.section])
        }
    }

    // Prepares and caches the section to improve performance
    private func prepareSections() {
        debugLog("Preparing sections")

        cachedElementsProviders.removeAll()
        mapper.delegate = self

        for index in 0..<mapper.numberOfSections {
            guard let section = mapper.provider.sections[index] as? UICollectionViewSection else {
                fatalError("No provider available for section: \(index), or it does not conform to CollectionSectionProvider")
            }

            let elementsProvider = section.collectionViewElementsProvider(with: collectionView.traitCollection)
            let cells = (0..<section.numberOfElements).reduce(into: [CollectionCellElement](), { cells, index in
                let cell = elementsProvider.cell(for: index)

                guard !cells.contains(where: { $0.reuseIdentifier == cell.reuseIdentifier }) else { return }

                cells.append(cell)
            })

            for cell in cells {
                switch cell.dequeueMethod.method {
                case let .fromNib(type):
                    // `UINib(nibName:bundle:)` is an expensive call because it reads the NIB from the
                    // disk, which can have a large impact on performance when this is called multiple times.
                    //
                    // Each registration is cached to ensure that the same nib is not read from disk multiple times.

                    let nibName = String(describing: type)
                    let nibBundle = Bundle(for: type)
                    let nibRegistration = NIBRegistration(nibName: nibName, bundle: nibBundle, reuseIdentifier: cell.reuseIdentifier)

                    guard !nibRegistrations.contains(nibRegistration) else { break }

                    let nib = UINib(nibName: nibName, bundle: nibBundle)
                    collectionView.register(nib, forCellWithReuseIdentifier: cell.reuseIdentifier)
                    nibRegistrations.insert(nibRegistration)
                case let .fromClass(type):
                    let classRegistration = ClassRegistration(class: type, reuseIdentifier: cell.reuseIdentifier)
                    guard !classRegistrations.contains(classRegistration) else { break }

                    collectionView.register(type, forCellWithReuseIdentifier: cell.reuseIdentifier)
                    classRegistrations.append(classRegistration)
                case .fromStoryboard:
                    break
                }
            }

            [elementsProvider.header, elementsProvider.footer].compactMap { $0 }.forEach {
                switch $0.dequeueMethod.method {
                case let .fromNib(type):
                    let nibName = String(describing: type)
                    let nibBundle = Bundle(for: type)
                    let nibRegistration = NIBRegistration(
                        nibName: nibName,
                        bundle: nibBundle,
                        reuseIdentifier: $0.reuseIdentifier,
                        supplementaryViewKind: $0.kind.rawValue
                    )

                    guard !nibRegistrations.contains(nibRegistration) else { break }

                    let nib = UINib(nibName: nibName, bundle: nibBundle)
                    collectionView.register(nib, forSupplementaryViewOfKind: $0.kind.rawValue, withReuseIdentifier: $0.reuseIdentifier)
                    nibRegistrations.insert(nibRegistration)
                case let .fromClass(type):
                    let classRegistration = ClassRegistration(
                        class: type,
                        reuseIdentifier: $0.reuseIdentifier,
                        supplementaryViewKind: $0.kind.rawValue
                    )
                    guard !classRegistrations.contains(classRegistration) else { break }

                    collectionView.register(type, forSupplementaryViewOfKind: $0.kind.rawValue, withReuseIdentifier: $0.reuseIdentifier)
                    classRegistrations.append(classRegistration)
                case .fromStoryboard:
                    break
                }
            }

            cachedElementsProviders.append(elementsProvider)
        }

        collectionView.allowsMultipleSelection = true
        if let delegate = delegate {
            collectionView.backgroundView = delegate.coordinator(self, backgroundViewInCollectionView: collectionView)
        }
        collectionView.dragInteractionEnabled = sectionProvider.sections.contains { $0 is MoveHandler || $0 is CollectionDragHandler || $0 is CollectionDropHandler }
        delegate?.coordinatorDidUpdate(self)
    }

    fileprivate func debugLog(_ message: String) {
        if #available(iOS 12, *), enableLogs {
            os_log("%@", log: OSLog(subsystem: "ComposedUI", category: "CollectionCoordinator"), type: .debug, message)
        }

        if let logger = logger {
            logger(message)
        }
    }
}

// MARK: - SectionProviderMappingDelegate

extension CollectionCoordinator: SectionProviderMappingDelegate {
    public func mappingDidInvalidate(_ mapping: SectionProviderMapping) {
        assert(Thread.isMainThread)

        guard !reloadDataBatchUpdates else {
            /// Not necessary; below code will be executed in `mapping(_:willPerformBatchUpdates:forceReloadData:)`
            return
        }
        assert(!changesReducer.hasActiveUpdates, "Cannot invalidate within a batch of updates; `UICollectionView` does not support `reloadData` inside `performBatchUpdates`")
        debugLog(#function)
        changesReducer.clearUpdates()
        prepareSections()
        collectionView.reloadData()
    }

    public func mapping(_ mapping: SectionProviderMapping, willPerformBatchUpdates updates: () -> Void) {
        self.mapping(mapping, willPerformBatchUpdates: updates, forceReloadData: false)
    }

    public func mapping(_ mapping: SectionProviderMapping, willPerformBatchUpdates updates: () -> Void, forceReloadData: Bool) {
        assert(Thread.isMainThread)

        guard !changesReducer.hasActiveUpdates else {
            assert(!forceReloadData, "Cannot reload data while inside `performBatchUpdates`")

            // The changes reducer will only have active updates after `beginUpdating` has
            // been called, which is done inside `performBatchUpdates`. This ensures that any
            // `updates` closure that trigger other updates and call in to this again have
            // their updates applied in the same batch.
            updates()
            return
        }

        guard !forceReloadData else {
            debugLog("Performing updates before reloading data")
            updates()

            prepareSections()

            debugLog("Reloading data")
            collectionView.reloadData()
            return
        }

        guard !isPerformingUpdates else {
            print("Batch updates are being applied to \(self) after a previous batch has been applied but before the collection view has finished laying out. This can occur when the configuration for one of your views triggers an update. Since the update has not yet finished this can cause data to be out of sync. See \(#filePath):L\(#line) for more details. Calling `reloadData`.")
            mappingDidInvalidate(mapping)
            return
        }

        isPerformingUpdates = true

        /**
         Ensure collection view has been laid out, essentially ensuring that it will not be called
         by the collection view itself, which may trigger fetching of stale data and cause a crash.

         At this point the `updates` closure has not been called, so any updates about to be applied
         have not yet been reflected in the data layer.

         This is mainly for making crashes here easier to debug.
         */
        debugLog("Layout out collection view, if needed")
        collectionView.layoutIfNeeded()
        debugLog("Collection view has been laid out")
        collectionView.performBatchUpdates({
            debugLog("Starting batch updates")
            changesReducer.beginUpdating()

            updates()

            prepareSections()

            guard let changeset = changesReducer.endUpdating() else {
                assertionFailure("Calls to `beginUpdating` must be balanced with calls to `endUpdating`")
                return
            }

            debugLog("Deleting sections \(changeset.groupsRemoved.sorted(by: >))")
            collectionView.deleteSections(IndexSet(changeset.groupsRemoved))

            debugLog("Deleting items \(changeset.elementsRemoved.sorted(by: >))")
            collectionView.deleteItems(at: Array(changeset.elementsRemoved))

            debugLog("Reloaded sections \(changeset.groupsUpdated.sorted(by: >))")
            collectionView.reloadSections(IndexSet(changeset.groupsUpdated))

            debugLog("Inserting items \(changeset.elementsInserted.sorted(by: <))")
            collectionView.insertItems(at: Array(changeset.elementsInserted))

            debugLog("Reloading items \(changeset.elementsUpdated.sorted(by: <))")
            collectionView.reloadItems(at: Array(changeset.elementsUpdated))

            changeset.elementsMoved.forEach { move in
                debugLog("Moving \(move.from) to \(move.to)")
                collectionView.moveItem(at: move.from, to: move.to)
            }

            debugLog("Inserting sections \(changeset.groupsInserted.sorted(by: >))")
            collectionView.insertSections(IndexSet(changeset.groupsInserted))

            debugLog("Batch updates have been applied")
        }, completion: { [weak self] isFinished in
            self?.debugLog("Batch updates completed. isFinished: \(isFinished)")
        })
        isPerformingUpdates = false
        debugLog("`performBatchUpdates` call has completed")
    }

    public func mapping(_ mapping: SectionProviderMapping, didInsertSections sections: IndexSet) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(Array(sections))")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()
            collectionView.insertSections(sections)
            return
        }

        changesReducer.insertGroups(sections)
    }

    public func mapping(_ mapping: SectionProviderMapping, didRemoveSections sections: IndexSet) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(Array(sections))")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()
            collectionView.deleteSections(sections)
            return
        }

        changesReducer.removeGroups(sections)
    }

    public func mapping(_ mapping: SectionProviderMapping, didInsertElementsAt indexPaths: [IndexPath]) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(indexPaths)")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()
            collectionView.insertItems(at: indexPaths)
            return
        }

        changesReducer.insertElements(at: indexPaths)
    }

    public func mapping(_ mapping: SectionProviderMapping, didRemoveElementsAt indexPaths: [IndexPath]) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(indexPaths)")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()
            collectionView.deleteItems(at: indexPaths)
            return
        }

        changesReducer.removeElements(at: indexPaths)
    }

    public func mapping(_ mapping: SectionProviderMapping, didUpdateElementsAt indexPaths: [IndexPath]) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(indexPaths)")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()

            var indexPathsToReload: [IndexPath] = []
            for indexPath in indexPaths {
                guard let section = self.sectionProvider.sections[indexPath.section] as? CollectionUpdateHandler,
                      !section.prefersReload(forElementAt: indexPath.item),
                      let cell = self.collectionView.cellForItem(at: indexPath) else {
                    indexPathsToReload.append(indexPath)
                    continue
                }

                self.cachedElementsProviders[indexPath.section].cell(for: indexPath.item).configure(cell, indexPath.item, self.mapper.provider.sections[indexPath.section])
            }

            guard !indexPathsToReload.isEmpty else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.collectionView.reloadItems(at: indexPathsToReload)
            CATransaction.setDisableActions(false)
            CATransaction.commit()
            return
        }

        changesReducer.updateElements(at: indexPaths)
    }

    public func mapping(_ mapping: SectionProviderMapping, didMoveElementsAt moves: [(IndexPath, IndexPath)]) {
        assert(Thread.isMainThread)

        debugLog(#function + "\(moves)")

        guard !reloadDataBatchUpdates else { return }

        guard isPerformingUpdates else {
            prepareSections()
            moves.forEach { collectionView.moveItem(at: $0.0, to: $0.1) }
            return
        }

        changesReducer.moveElements(moves)
    }

    public func mapping(_ mapping: SectionProviderMapping, selectedIndexesIn section: Int) -> [Int] {
        assert(Thread.isMainThread)
        let indexPaths = collectionView.indexPathsForSelectedItems ?? []
        return indexPaths.filter { $0.section == section }.map { $0.item }
    }

    public func mapping(_ mapping: SectionProviderMapping, select indexPath: IndexPath) {
        assert(Thread.isMainThread)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
    }

    public func mapping(_ mapping: SectionProviderMapping, deselect indexPath: IndexPath) {
        assert(Thread.isMainThread)
        collectionView.deselectItem(at: indexPath, animated: true)
    }

    public func mapping(_ mapping: SectionProviderMapping, move sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard !reloadDataBatchUpdates else { return }
        // TODO: Check `isPerformingBatchedUpdates`
        self.mapping(mapping, didMoveElementsAt: [(sourceIndexPath, destinationIndexPath)])
    }

    public func mappingDidInvalidateHeader(at sectionIndex: Int) {
        // Ensure elements provider is available, views have been registered, etc.
        prepareSections()

        let elementsProvider = self.elementsProvider(for: sectionIndex)
        let section = self.mapper.provider.sections[sectionIndex]

        // Without performing these changes inside a batch updates the header
        // may briefly be hidden, causing a "flash" to occur.
        collectionView.performBatchUpdates {
            let context = UICollectionViewFlowLayoutInvalidationContext()
            context.invalidateSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader, at: [IndexPath(item: 0, section: sectionIndex)])
            invalidateLayout(with: context)

            if
                let headerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: sectionIndex)),
                let header = elementsProvider.header,
                header.kind.rawValue == UICollectionView.elementKindSectionHeader
            {
                header.configure(headerView, sectionIndex, section)
            }
        }
    }

    public func mappingDidInvalidateFooter(at sectionIndex: Int) {
        // Ensure elements provider is available, views have been registered, etc.
        prepareSections()

        let elementsProvider = self.elementsProvider(for: sectionIndex)
        let section = self.mapper.provider.sections[sectionIndex]

        debugLog("Section \(sectionIndex) invalidated footer")

        // Without performing these changes inside a batch updates the footer
        // may briefly be hidden, causing a "flash" to occur.
        collectionView.performBatchUpdates {
            let context = UICollectionViewFlowLayoutInvalidationContext()
            context.invalidateSupplementaryElements(ofKind: UICollectionView.elementKindSectionFooter, at: [IndexPath(item: 0, section: sectionIndex)])
            invalidateLayout(with: context)

            // Even when invalidating the layout the collection view may not
            // request the view again, so it won't be reconfigured. Maybe it
            // will only request the view again if the size changes?
            if
                let footerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: sectionIndex)),
                let footer = elementsProvider.footer,
                footer.kind.rawValue == UICollectionView.elementKindSectionFooter
            {
                footer.configure(footerView, sectionIndex, section)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension CollectionCoordinator: UICollectionViewDataSource {

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return mapper.numberOfSections
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return elementsProvider(for: section).numberOfElements
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        assert(Thread.isMainThread)
        defer {
            originalDelegate?.collectionView?(collectionView, willDisplay: cell, forItemAt: indexPath)
        }

        let elements = elementsProvider(for: indexPath.section)
        let section = mapper.provider.sections[indexPath.section]
        elements.cell(for: indexPath.item).willAppear?(cell, indexPath.item, section)
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        assert(Thread.isMainThread)
        defer {
            originalDelegate?.collectionView?(collectionView, didEndDisplaying: cell, forItemAt: indexPath)
        }
        if let (cellElement, section) = cellSectionMap[cell] {
            cellElement.didDisappear?(cell, indexPath.item, section)
	        cellSectionMap.removeValue(forKey: cell)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        assert(Thread.isMainThread)
        let elements = elementsProvider(for: indexPath.section)
        let cellElement = elements.cell(for: indexPath.item)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellElement.reuseIdentifier, for: indexPath)

        if let handler = sectionProvider.sections[indexPath.section] as? EditingHandler {
            if let handler = sectionProvider.sections[indexPath.section] as? CollectionEditingHandler {
                handler.didSetEditing(collectionView.isEditing, at: indexPath.item, cell: cell, animated: false)
            } else {
                handler.didSetEditing(collectionView.isEditing, at: indexPath.item)
            }
        }

        let section = mapper.provider.sections[indexPath.section]
        cellSectionMap[cell] = (cellElement, section)
        cellElement.configure(cell, indexPath.item, section)
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        assert(Thread.isMainThread)
        defer {
            originalDelegate?.collectionView?(collectionView, willDisplaySupplementaryView: view, forElementKind: elementKind, at: indexPath)
        }

        guard indexPath.section < sectionProvider.numberOfSections else { return }

        let elements = elementsProvider(for: indexPath.section)
        let section = mapper.provider.sections[indexPath.section]

        if let header = elements.header, header.kind.rawValue == elementKind {
            header.willAppear?(view, indexPath.section, section)
            header.configure(view, indexPath.section, section)
        } else if let footer = elements.footer, footer.kind.rawValue == elementKind {
            footer.willAppear?(view, indexPath.section, section)
            footer.configure(view, indexPath.section, section)
        } else {
            // the original delegate can handle this
        }
    }

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        assert(Thread.isMainThread)
        let elements = elementsProvider(for: indexPath.section)
        let section = mapper.provider.sections[indexPath.section]

        if let header = elements.header, header.kind.rawValue == kind {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: header.reuseIdentifier, for: indexPath)
            header.configure(view, indexPath.section, section)
            return view
        } else if let footer = elements.footer, footer.kind.rawValue == kind {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footer.reuseIdentifier, for: indexPath)
            footer.configure(view, indexPath.section, section)
            return view
        } else {
            guard let view = originalDataSource?.collectionView?(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath) else {
                // when in production its better to return 'something' to prevent crashing
                assertionFailure("Unsupported supplementary kind: \(kind) at indexPath: \(indexPath). Check if your layout it returning attributes for the supplementary element at \(indexPath)")
                return collectionView.dequeue(supplementary: PlaceholderSupplementaryView.self, ofKind: PlaceholderSupplementaryView.kind, for: indexPath)
            }

            return view
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didEndDisplayingSupplementaryView view: UICollectionReusableView, forElementOfKind elementKind: String, at indexPath: IndexPath) {
        assert(Thread.isMainThread)
        defer {
            originalDelegate?.collectionView?(collectionView, didEndDisplayingSupplementaryView: view, forElementOfKind: elementKind, at: indexPath)
        }

        guard !indexPath.isEmpty else { return }
        guard indexPath.section < sectionProvider.numberOfSections else { return }
        let elements = elementsProvider(for: indexPath.section)
        let section = mapper.provider.sections[indexPath.section]

        if let header = elements.header, header.kind.rawValue == elementKind {
            elements.header?.didDisappear?(view, indexPath.section, section)
        } else if let footer = elements.footer, footer.kind.rawValue == elementKind {
            elements.footer?.didDisappear?(view, indexPath.section, section)
        } else {
            // the original delegate can handle this
        }
    }

    private func elementsProvider(for section: Int) -> UICollectionViewSectionElementsProvider {
        guard cachedElementsProviders.indices.contains(section) else {
            fatalError("No UI configuration available for section \(section)")
        }
        return cachedElementsProviders[section]
    }

}

@available(iOS 13.0, *)
extension CollectionCoordinator {

    // MARK: - Context Menus

    public func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let provider = mapper.provider.sections[indexPath.section] as? CollectionContextMenuHandler,
              provider.allowsContextMenu(forElementAt: indexPath.item),
              let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        let preview = provider.contextMenu(previewForElementAt: indexPath.item, cell: cell)
        return UIContextMenuConfiguration(identifier: indexPath.string, previewProvider: preview) { suggestedElements in
            return provider.contextMenu(forElementAt: indexPath.item, cell: cell, suggestedActions: suggestedElements)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? String, let indexPath = IndexPath(string: identifier) else { return nil }
        guard let cell = collectionView.cellForItem(at: indexPath),
              let provider = mapper.provider.sections[indexPath.section] as? CollectionContextMenuHandler else { return nil }
        return provider.contextMenu(previewForHighlightingElementAt: indexPath.item, cell: cell)
    }

    public func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let identifier = configuration.identifier as? String, let indexPath = IndexPath(string: identifier) else { return nil }
        guard let cell = collectionView.cellForItem(at: indexPath),
              let provider = mapper.provider.sections[indexPath.section] as? CollectionContextMenuHandler else { return nil }
        return provider.contextMenu(previewForDismissingElementAt: indexPath.item, cell: cell)
    }

    public func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let identifier = configuration.identifier as? String, let indexPath = IndexPath(string: identifier) else { return }
        guard let cell = collectionView.cellForItem(at: indexPath),
              let provider = mapper.provider.sections[indexPath.section] as? CollectionContextMenuHandler else { return }
        provider.contextMenu(willPerformPreviewActionForElementAt: indexPath.item, cell: cell, animator: animator)
    }

}

extension CollectionCoordinator: UICollectionViewDelegate {

    // MARK: - Selection

    open func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let handler = mapper.provider.sections[indexPath.section] as? SelectionHandler else {
            return originalDelegate?.collectionView?(collectionView, shouldHighlightItemAt: indexPath) ?? true
        }

        return handler.shouldHighlight(at: indexPath.item)
    }

    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let handler = mapper.provider.sections[indexPath.section] as? SelectionHandler else {
            return originalDelegate?.collectionView?(collectionView, shouldSelectItemAt: indexPath) ?? false
        }

        return handler.shouldSelect(at: indexPath.item)
    }

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            originalDelegate?.collectionView?(collectionView, didSelectItemAt: indexPath)
        }

        guard let handler = mapper.provider.sections[indexPath.section] as? SelectionHandler else { return }
        if let handler = handler as? CollectionSelectionHandler, let cell = collectionView.cellForItem(at: indexPath) {
            handler.didSelect(at: indexPath.item, cell: cell)
        } else {
            handler.didSelect(at: indexPath.item)
        }

        guard collectionView.allowsMultipleSelection, !handler.allowsMultipleSelection else { return }

        let indexPaths = mapping(mapper, selectedIndexesIn: indexPath.section)
            .map { IndexPath(item: $0, section: indexPath.section ) }
            .filter { $0 != indexPath }
        indexPaths.forEach { collectionView.deselectItem(at: $0, animated: true) }
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        originalDelegate?.scrollViewDidScroll?(scrollView)
    }

    open func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        guard let handler = mapper.provider.sections[indexPath.section] as? SelectionHandler else {
            return originalDelegate?.collectionView?(collectionView, shouldDeselectItemAt: indexPath) ?? true
        }

        return handler.shouldDeselect(at: indexPath.item)
    }

    open func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        defer {
            originalDelegate?.collectionView?(collectionView, didDeselectItemAt: indexPath)
        }

        guard let handler = mapper.provider.sections[indexPath.section] as? SelectionHandler else { return }
        if let collectionHandler = handler as? CollectionSelectionHandler, let cell = collectionView.cellForItem(at: indexPath) {
            collectionHandler.didDeselect(at: indexPath.item, cell: cell)
        } else {
            handler.didDeselect(at: indexPath.item)
        }
    }

    // MARK: - Forwarding

    open override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        if originalDelegate?.responds(to: aSelector) ?? false { return true }
        return false
    }

    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) { return self }
        return originalDelegate
    }

}

// MARK: - UICollectionViewDragDelegate

extension CollectionCoordinator: UICollectionViewDragDelegate {

    public func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: UIDragSession) {
        sectionProvider.sections
            .compactMap { $0 as? CollectionDragHandler }
            .forEach { $0.dragSessionWillBegin(session) }

        originalDragDelegate?.collectionView?(collectionView, dragSessionWillBegin: session)
    }

    public func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        sectionProvider.sections
            .compactMap { $0 as? CollectionDragHandler }
            .forEach { $0.dragSessionDidEnd(session) }

        originalDragDelegate?.collectionView?(collectionView, dragSessionDidEnd: session)
    }

    public func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool {
        return originalDragDelegate?.collectionView?(collectionView, dragSessionIsRestrictedToDraggingApplication: session) ?? false
    }

    public func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let provider = sectionProvider.sections[indexPath.section] as? CollectionDragHandler else {
            return originalDragDelegate?.collectionView(collectionView, itemsForBeginning: session, at: indexPath) ?? []
        }

        session.localContext = indexPath.section
        return provider.dragSession(session, dragItemsForBeginning: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        guard let provider = sectionProvider.sections[indexPath.section] as? CollectionDragHandler else {
            return originalDragDelegate?.collectionView(collectionView, itemsForBeginning: session, at: indexPath) ?? []
        }

        return provider.dragSession(session, dragItemsForAdding: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, dragSessionAllowsMoveOperation session: UIDragSession) -> Bool {
        let sections = sectionProvider.sections.compactMap { $0 as? MoveHandler }
        return originalDragDelegate?.collectionView?(collectionView, dragSessionAllowsMoveOperation: session) ?? !sections.isEmpty
    }

}

// MARK: - UICollectionViewDropDelegate

extension CollectionCoordinator: UICollectionViewDropDelegate {

    public func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        if collectionView.hasActiveDrag { return true }
        return originalDropDelegate?.collectionView?(collectionView, canHandle: session) ?? false
    }

    public func collectionView(_ collectionView: UICollectionView, dropSessionDidEnter session: UIDropSession) {
        if !collectionView.hasActiveDrag {
            sectionProvider.sections
                .compactMap { $0 as? CollectionDropHandler }
                .forEach { $0.dropSessionWillBegin(session) }
        }

        originalDropDelegate?.collectionView?(collectionView, dropSessionDidEnter: session)
    }

    public func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        originalDropDelegate?.collectionView?(collectionView, dropSessionDidExit: session)
    }

    public func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        sectionProvider.sections
            .compactMap { $0 as? CollectionDropHandler }
            .forEach { $0.dropSessionDidEnd(session) }

        originalDropDelegate?.collectionView?(collectionView, dropSessionDidEnd: session)
    }

    public func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        // this seems to happen sometimes when iOS gets interrupted
        guard !indexPath.isEmpty else { return nil }

        guard let section = sectionProvider.sections[indexPath.section] as? CollectionDragHandler,
              let cell = collectionView.cellForItem(at: indexPath) else {
            return originalDragDelegate?.collectionView?(collectionView, dragPreviewParametersForItemAt: indexPath)
        }

        return section.dragSession(previewParametersForElementAt: indexPath.item, cell: cell)
    }

    public func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let section = sectionProvider.sections[indexPath.section] as? CollectionDropHandler,
              let cell = collectionView.cellForItem(at: indexPath) else {
            return originalDropDelegate?
                .collectionView?(collectionView, dropPreviewParametersForItemAt: indexPath)
        }

        return section.dropSesion(previewParametersForElementAt: indexPath.item, cell: cell)
    }

    public func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let section = session.localDragSession?.localContext as? Int, section != destinationIndexPath?.section {
            return UICollectionViewDropProposal(operation: .forbidden)
        }

        if collectionView.hasActiveDrag || session.localDragSession != nil {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }

        if destinationIndexPath == nil {
            return originalDropDelegate?.collectionView?(collectionView, dropSessionDidUpdate: session, withDestinationIndexPath: destinationIndexPath) ?? UICollectionViewDropProposal(operation: .forbidden)
        }

        guard let indexPath = destinationIndexPath, let section = sectionProvider.sections[indexPath.section] as? CollectionDropHandler else {
            return originalDropDelegate?
                .collectionView?(collectionView, dropSessionDidUpdate: session, withDestinationIndexPath: destinationIndexPath)
                ?? UICollectionViewDropProposal(operation: .forbidden)
        }

        return section.dropSessionDidUpdate(session, destinationIndex: indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        defer {
            originalDropDelegate?.collectionView(collectionView, performDropWith: coordinator)
        }

        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)

        guard coordinator.proposal.operation == .move,
              let section = sectionProvider.sections[destinationIndexPath.section] as? MoveHandler else {
            return
        }

        let item = coordinator.items.lazy
            .filter { $0.sourceIndexPath != nil }
            .filter { $0.sourceIndexPath?.section == destinationIndexPath.section }
            .compactMap { ($0, $0.sourceIndexPath!) }
            .first!

        collectionView.performBatchUpdates({
            let indexes = IndexSet(integer: item.1.item)
            section.didMove(sourceIndexes: indexes, to: destinationIndexPath.item)

            collectionView.deleteItems(at: [item.1])
            collectionView.insertItems(at: [destinationIndexPath])
        }, completion: nil)

        coordinator.drop(item.0.dragItem, toItemAt: destinationIndexPath)
    }

}

private final class PlaceholderSupplementaryView: UICollectionReusableView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: 1).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public extension CollectionCoordinator {

    /// A convenience initializer that allows creation without a provider
    /// - Parameters:
    ///   - collectionView: The collectionView associated with this coordinator
    ///   - sections: The sections associated with this coordinator
    convenience init(collectionView: UICollectionView, sections: Section...) {
        let provider = ComposedSectionProvider()
        sections.forEach(provider.append(_:))
        self.init(collectionView: collectionView, sectionProvider: provider)
    }

}
