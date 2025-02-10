<img src="composed.png" width=20%/>

`Composed` is a protocol oriented framework for composing data from multiple sources and building flexible UIs that display the data.

The primary benefit of Composed is that a `Section` is isolated from its siblings, removing the need to think about global index paths and instead focus on section-level indices and business logic. This allows for a `Section` to behave similarly to a view model. Out of the box Composed supports this for `UICollectionView`s but it can work with `UITableView`s, `UIStackViews`, or any other view a coordinator is built for.

The package contains 3 libraries, each built on top of each other:

- Composed
- ComposedUI
- ComposedLayouts

## Example

Composed allows for each section, or collection of sections, to be implemented independent of each other, so they could be in separate modules altogether but displayed in the same collection view. This also allows for the same sections to be displayed in different collection views without needing to rewrite the top-level collection view delegate. For example you may have a hierarchy of:

```
├─ `SettingsSectionProvider`
│  ├─ `AccountSectionProvider`
│  │  ├─ `AccountHeaderSection`
│  │  ├─ `AccountInformationSectionProvider`
│  │  └─ `EditProfileSection`
│  ├─ `NotificationsSectionProvider`
```

Each leaf in this node only needs to implement the business logic and provide the UI for its own set of responsibilities. These can then be easily reused in other screens, such as a screen dedicated to managing the notification settings:

```
└─ `ComposedSectionProvider` // No need for a subclass; this can be created directly. 
│  └─ `NotificationsSectionProvider`
```

The ease of adding, removing, and updating sections and section providers also allows for things like loading and error states to be implemented with relative ease. Building a custom subclass of `ComposedSectionProvider` to handle this in a generic way can also provide extra consistency to the UI and codebase while removing a lot of the boilerplate.

```swift
final class LoadableSectionProvider<Data, RootSectionProvider: UpdatableSectionProvider>: ComposedSectionProvider {
    typealias RootSectionProviderFactory = @MainActor (_ data: Data) -> RootSectionProvider
    typealias DataProvider = () async throws -> Data

    private let rootSectionProviderFactory: RootSectionProviderFactory
    private let dataProvider: DataProvider
    private var errorSection: ErrorSection?
    private var loadingSection: LoadingSection?
    private var rootSectionProvider: RootSectionProvider?

    func loadData() async throws {
        showLoading()

        do {
            let profile = try await dataProvider()
            showRootSectionProvider(data: data)
        } catch {
            showError(error)
        }
    }

    private func showLoading() {
        performBatchUpdates { _ in
            if let loadingSection {
                guard !contains(loadingSection) else { return }

                removeAll()
                append(loadingSection)
            } else {
                removeAll()
                let loadingSection = LoadingSection()
                self.loadingSection = loadingSection
                append(loadingSection)
            }
        }
    }

    private func showError(_ error: Error) {
        performBatchUpdates { _ in
            if let errorSection {
                errorSection.displayError(error)
                guard !contains(errorSection) else { return }

                removeAll()
                append(errorSection)
            } else {
                removeAll()
                let errorSection = ErrorSection(error: error, retryHandler: { [weak self] in
                    Task {
                        try? await self?.loadData()
                    }
                })
                self.errorSection = errorSection
                append(errorSection)
            }
        }
    }

    private func showRootSectionProvider(data: Data) {
        performBatchUpdates { _ in
            if let rootSectionProvider {
                rootSectionProvider.update(data: data)

                guard !contains(rootSectionProvider) else { return }

                removeAll()
                append(rootSectionProvider)
            } else {
                removeAll()
                let rootSectionProvider = rootSectionProviderFactory(data)
                self.rootSectionProvider = rootSectionProvider
                append(rootSectionProvider)
            }
        }
    }
}
```

The provided `RootSectionProvider` can then focus on displaying the display of the data and any required interactions. Each of these types has enough API exposed that they can be unit tested in a similar way to a view model.

## Composed

The `Composed` library provides the data layer. `Composed` is centered around 2 primitives, `Section` and `SectionProvider`.

### Sections

A `Section` is a collection of data with a simple set of requirements:

```swift
/// Represents a single section of data.
@MainActor
public protocol Section: AnyObject {
    /// The number of elements in this section
    var numberOfElements: Int { get }

    /// The delegate that will respond to updates
    var updateDelegate: SectionUpdateDelegate? { get set }
}
```

`Composed` provides some sections that should cover a majority of use cases.

#### `ArraySection`

Represents a section that manages a collection of same-type elements by using an `Array` backing store. This type of section is useful for representing in-memory data, e.g. data loaded from a network or read from the file system.

#### `SingleElementSection`

Represents a section that manages a single element. This section is useful when only have a single element to manage.

If the stored value is `nil` it will return `0` for `numberOfElements`, allowing for any UI elements the section provides to be hidden (more on this later).

#### `FlatSection`

A `FlatSection` behaved similarly to a `ComposedSectionProvider` but rather than providing a collections of sections it returns a single section that contains every element in the flattened collection of `Section`s and `SectionProvider`s. This has limited use for data alone but proves useful when representing the data in the UI; `FlatSection` allows for multiple sections to be displayed in a single UI section, enabling features such as headers that pin to visible bounds ("sticky headers").

### Section Providers

Section providers are a collection of multiple sections and are the interface the coordinators use to display the data. Composed provides a single section provider: `ComposedSectionProvider`.

#### `ComposedSectionProvider`

`ComposedSectionProvider` can contain a mixture of `Section`s and `SectionProvider`. It composes these together to produce a single array of `Section`s that a top-level coordinator can listen for changes from.ach tab.

## ComposedUI

The ComposedUI library builds on top of Composed by providing protocols that enable `Section`s to provide UI elements that can then be displayed by a view coordinator.

### `CollectionCoordinator`

`CollectionCoordinator` is the core type within ComposedUI. It uses a single `ComposedSectionProvider` to map a collection of sections to a collection view, using each `Section` as a section in the collection view.

To support this each `Section` must provide a `UICollectionViewSectionElementsProvider` via the `UICollectionViewSectionElementsProvider` protocol. There are many convenience types built on top of these to enable common use cases, such as using the same cell type for all elements:

```swift
final class AccountHeaderSection: SingleUICollectionViewSection {
    let numberOfElements = 1
    
    weak var updateDelegate: SectionUpdateDelegate?
    
    func section(with traitCollection: UITraitCollection) -> CollectionSection {
        CollectionCellElement(section: self, dequeueMethod: .fromClass(HeaderCollectionViewCell.self)) { cell, index, section in
            cell.titleLabel.text = "Account"
        }
    }
}
```

## ComposedLayouts

ComposedLayouts is the final layer of the Composed package and allows for layouts to be built on top of sections. Composed supports `UICollectionViewCompositionalLayout` and `UICollectionViewFlowLayout` out of the box.

For simple use cases we can use fixed sizes:

```swift
extension AccountHeaderSection: CollectionFlowLayoutHandler {
    func sizeForItem(at index: Int, suggested: CGSize, metrics: CollectionFlowLayoutMetrics, environment: CollectionFlowLayoutEnvironment) -> CGSize {
        CGSize(width: environment.contentSize.width, height: 120)
    }
}
```

We can also utilise automatic sizing:

```swift
final class AccountHeaderSection: SingleUICollectionViewSection, CollectionFlowLayoutHandler {
    // ... 
    
    private var flowLayoutSizingStrategy: CollectionFlowLayoutSizingStrategy?
    
    // ...
    
    func sizingStrategy(at index: Int, metrics: CollectionFlowLayoutMetrics, environment: CollectionFlowLayoutEnvironment) -> CollectionFlowLayoutSizingStrategy? {
        if let flowLayoutSizingStrategy {
            return flowLayoutSizingStrategy
        }

        let prototype = HeaderCollectionViewCell()
        prototype.titleLabel.text = "Account"
        return CollectionFlowLayoutSizingStrategy(
            columnCount: 1,
            sizingMode: .automatic(isUniform: true, prototype: prototype),
            metrics: flowLayoutMetrics
        )
    }
}
```

This also allows for mixed-size cells to be used by providing `isUniform: false` and using a different sizing strategy per index.
