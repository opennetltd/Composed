import Composed
import UIKit

/// Defines a supplementary element to be used by a `CollectionSection` to provide a configuration for a supplementary view
public final class CollectionSupplementaryElement: CollectionElement {
    public typealias InvalidViewHandler = (
        _ view: UICollectionReusableView,
        _ expectedType: UICollectionReusableView.Type,
        _ index: Int,
        _ section: Any
    ) -> Void

    public typealias InvalidSectionHandler<View: UICollectionReusableView> = (
        _ section: Any,
        _ expectedType: Any.Type,
        _ view: UICollectionReusableView,
        _ index: Int
    ) -> Void

    public let dequeueMethod: AnyDequeueMethod
    public let configure: (UICollectionReusableView, Int, Section) -> Void
    public let reuseIdentifier: String

    /// The `elementKind` this element represents
    public let kind: CollectionElementKind

    /// A closure that will be called before the elements view is appeared
    public let willAppear: ((UICollectionReusableView, Int, Section) -> Void)?
    /// A closure that will be called after the elements view has disappeared
    public let didDisappear: ((UICollectionReusableView, Int, Section) -> Void)?

    /// Makes a new element for representing a supplementary view
    /// - Parameters:
    ///   - section: The section where this element's view will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a view for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - kind: The `elementKind` this element represents
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    public init<Section, View: UICollectionReusableView>(
        section: Section,
        dequeueMethod: DequeueMethod<View>,
        reuseIdentifier: String? = nil,
        kind: CollectionElementKind = .automatic,
        configure: @escaping (_ view: View, _ sectionIndex: Int, _ section: Section) -> Void,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier ?? View.reuseIdentifier
        self.dequeueMethod = dequeueMethod.erasedAsAnyDequeueMethod

        self.configure = { view, index, section in
            guard let view = view as? View else {
                invalidViewHandler?(view, View.self, index, section)
                return
            }

            guard let section = section as? Section else {
                invalidSectionHandler?(section, Section.self, view, index)
                return
            }

            configure(view, index, section)
        }

        willAppear = nil
        didDisappear = nil
    }

    /// Makes a new element for representing a supplementary view
    /// - Parameters:
    ///   - section: The section where this element's view will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a view for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - kind: The `elementKind` this element represents
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    public init<Section, View: UICollectionReusableView>(
        section: Section,
        dequeueMethod: AnyDequeueMethod,
        reuseIdentifier: String? = nil,
        kind: CollectionElementKind = .automatic,
        configure: @escaping (_ view: View, _ sectionIndex: Int, _ section: Section) -> Void,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier ?? View.reuseIdentifier
        self.dequeueMethod = dequeueMethod

        self.configure = { view, index, section in
            guard let view = view as? View else {
                invalidViewHandler?(view, View.self, index, section)
                return
            }

            guard let section = section as? Section else {
                invalidSectionHandler?(section, Section.self, view, index)
                return
            }

            configure(view, index, section)
        }

        willAppear = nil
        didDisappear = nil
    }

    /// Makes a new element for representing a supplementary view
    /// - Parameters:
    ///   - section: The section where this element's view will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a view for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - kind: The `elementKind` this element represents
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    ///   - willAppear: A closure that will be called before the elements view appears
    ///   - didDisappear: A closure that will be called after the elements view disappears
    public init<Section, View: UICollectionReusableView>(
        section: Section,
        dequeueMethod: DequeueMethod<View>,
        reuseIdentifier: String? = nil,
        kind: CollectionElementKind = .automatic,
        configure: @escaping (View, Int, Section) -> Void,
        willAppear: ((View, Int, Section) -> Void)? = nil,
        didDisappear: ((View, Int, Section) -> Void)? = nil,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier ?? View.reuseIdentifier
        self.dequeueMethod = dequeueMethod.erasedAsAnyDequeueMethod

        self.configure = { view, index, section in
            guard let view = view as? View else {
                invalidViewHandler?(view, View.self, index, section)
                return
            }

            guard let section = section as? Section else {
                invalidSectionHandler?(section, Section.self, view, index)
                return
            }

            configure(view, index, section)
        }

        self.willAppear = willAppear.flatMap { willAppear in
            { view, index, section in
                guard let view = view as? View else {
                    invalidViewHandler?(view, View.self, index, section)
                    return
                }

                guard let section = section as? Section else {
                    invalidSectionHandler?(section, Section.self, view, index)
                    return
                }

                willAppear(view, index, section)
            }
        }

        self.didDisappear = didDisappear.flatMap { didDisappear in
            { view, index, section in
                guard let view = view as? View else {
                    invalidViewHandler?(view, View.self, index, section)
                    return
                }

                guard let section = section as? Section else {
                    invalidSectionHandler?(section, Section.self, view, index)
                    return
                }

                didDisappear(view, index, section)
            }
        }
    }

    /// Makes a new element for representing a supplementary view
    /// - Parameters:
    ///   - section: The section where this element's view will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a view for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - kind: The `elementKind` this element represents
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    ///   - willAppear: A closure that will be called before the elements view appears
    ///   - didDisappear: A closure that will be called after the elements view disappears
    public init<View: UICollectionReusableView>(
        dequeueMethod: DequeueMethod<View>,
        reuseIdentifier: String? = nil,
        kind: CollectionElementKind = .automatic,
        configure: @escaping (View, Int) -> Void,
        willAppear: ((View, Int) -> Void)? = nil,
        didDisappear: ((View, Int) -> Void)? = nil,
        invalidViewHandler: ((
            _ view: UICollectionReusableView,
            _ expectedType: UICollectionReusableView.Type,
            _ index: Int
        ) -> Void)? = nil
    ) {
        self.kind = kind
        self.reuseIdentifier = reuseIdentifier ?? View.reuseIdentifier
        self.dequeueMethod = dequeueMethod.erasedAsAnyDequeueMethod

        self.configure = { view, index, _ in
            guard let view = view as? View else {
                invalidViewHandler?(view, View.self, index)
                return
            }

            configure(view, index)
        }

        self.willAppear = willAppear.flatMap { willAppear in
            { view, index, _ in
                guard let view = view as? View else {
                    invalidViewHandler?(view, View.self, index)
                    return
                }

                willAppear(view, index)
            }
        }

        self.didDisappear = didDisappear.flatMap { didDisappear in
            { view, index, _ in
                guard let view = view as? View else {
                    invalidViewHandler?(view, View.self, index)
                    return
                }

                didDisappear(view, index)
            }
        }
    }
}
