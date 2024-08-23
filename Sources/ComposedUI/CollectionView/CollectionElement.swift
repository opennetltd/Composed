import Composed
import UIKit

/// A `UICollectionView` supports different elementKind's for supplementary view, this provides a solution
/// A collection view can provide headers and footers via custom elementKind's or it using built-in definitions, this provides a solution for specifying which option to use
public enum CollectionElementKind {
    /// Either `elementKindSectionHeader` or `elementKindSectionFooter` will be used
    case automatic
    /// The custom `kind` value will be used
    case custom(kind: String)

    internal var rawValue: String {
        switch self {
        case .automatic: return "automatic"
        case let .custom(kind): return kind
        }
    }
}

/// Defines an element used by a `CollectionSection` to provide configurations for a cell, header and/or footer.
public protocol CollectionElement {
    /// The method to use for registering and dequeueing a view for this element
    var dequeueMethod: AnyDequeueMethod { get }

    /// A closure that will be called whenever the elements view needs to be configured
    var configure: (UICollectionReusableView, Int, Section) -> Void { get }

    /// The reuseIdentifier to use for this element
    var reuseIdentifier: String { get }

    /// A closure that will be called before the elements view is appeared
    var willAppear: ((UICollectionReusableView, Int, Section) -> Void)? { get }

    /// A closure that will be called after the elements view has disappeared
    var didDisappear: ((UICollectionReusableView, Int, Section) -> Void)? { get }
}

extension CollectionElement {
    public var willAppear: ((UICollectionReusableView, Int, Section) -> Void)? { nil }
    public var didDisappear: ((UICollectionReusableView, Int, Section) -> Void)? { nil }
}
