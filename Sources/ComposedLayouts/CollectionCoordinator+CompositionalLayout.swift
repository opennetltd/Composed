import UIKit
import ComposedUI

public extension UICollectionViewCompositionalLayout {
    /// Instantiates a new `UICollectionViewCompositionalLayout` for the specified `CollectionCoordinator`
    /// - Parameter coordinator: The coordinator that will use this layout to provide layout data for its sections
    convenience init(coordinator: CollectionCoordinator) {
        self.init { [weak coordinator] index, environment in
            guard let coordinator, coordinator.sectionProvider.sections.indices.contains(index) else { return nil }
            let section = coordinator.sectionProvider.sections[index]
            guard let layoutHandler = section as? CompositionalLayoutHandler else {
                assert(section.isEmpty, "Section \(section) MUST conform to `CompositionalLayoutHandler` when used with a compositional layout and not empty")
                return nil
            }
            return layoutHandler.compositionalLayoutSection(environment: environment)
        }
    }

}
