import ComposedUI
import UIKit

/// Conform your section to this protocol to provide a layout section for a `UICollectionViewCompositionalLayout`
public protocol CompositionalLayoutHandler: UICollectionViewSection {
    /// Return a layout section for this section
    /// - Parameter environment: The current environment for this layout
    func compositionalLayoutSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection?
}
