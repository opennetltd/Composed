import Composed
import ComposedUI
import UIKit

/// Conform your section to this protocol to provide a layout section for a `UICollectionViewCompositionalLayout`
public protocol CompositionalLayoutHandler: UICollectionViewSection {
    /// Return a layout section for this section
    /// - Parameter environment: The current environment for this layout
    func compositionalLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection?
}

extension CollectionFlowLayoutHandler where Self: CompositionalLayoutHandler {
    public func compositionalLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        guard !isEmpty else { return nil }
        return NSCollectionLayoutSection(
            group: NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(0)),
                subitems: Array(
                    repeating: NSCollectionLayoutItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(0)
                        )
                    ),
                    count: numberOfElements
                )
            )
        )
    }
}

extension FlatUICollectionViewSection: CompositionalLayoutHandler {
    public func compositionalLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        let childSections = sections.compactMap { section -> NSCollectionLayoutSection? in
            guard let layoutHandler = section as? CompositionalLayoutHandler else { return nil }
            return layoutHandler.compositionalLayoutSection(environment: environment)
        }
        // Plain supports sticky headers.
        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.headerMode = .supplementary
        configuration.showsSeparators = false
        return NSCollectionLayoutSection.list(
            using: configuration,
            layoutEnvironment: environment
        )
    }
}
