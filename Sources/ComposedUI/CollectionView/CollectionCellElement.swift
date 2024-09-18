import Composed
import UIKit

/// Defines a cell element to be used by a `CollectionSection` to provide a configuration for a cell
open class CollectionCellElement: CollectionElement {
    public typealias InvalidViewHandler = @MainActor (
        _ view: UICollectionReusableView,
        _ expectedType: UICollectionReusableView.Type,
        _ index: Int,
        _ section: Any
    ) -> Void

    public typealias InvalidSectionHandler<View: UICollectionReusableView> = @MainActor (
        _ section: Any,
        _ expectedType: Any.Type,
        _ view: UICollectionReusableView,
        _ index: Int
    ) -> Void

    public let dequeueMethod: AnyDequeueMethod
    public let configure: @MainActor (UICollectionReusableView, Int, Section) -> Void
    public let reuseIdentifier: String

    /// The closure that will be called before the elements view appears
    public let willAppear: (@MainActor (UICollectionReusableView, Int, Section) -> Void)?
    /// The closure that will be called after the elements view disappears
    public let didDisappear: (@MainActor (UICollectionReusableView, Int, Section) -> Void)?

    /// Makes a new element for representing a cell
    /// - Parameters:
    ///   - section: The section where this element's cell will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a cell for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    public init<Section, View: UICollectionViewCell>(
        section: Section,
        dequeueMethod: DequeueMethod<View>,
        reuseIdentifier: String? = nil,
        configure: @escaping (View, Int, Section) -> Void,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
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

    /// Makes a new element for representing a cell
    /// - Parameters:
    ///   - section: The section where this element's cell will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a cell for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    public init<Section, View: UICollectionViewCell>(
        section: Section,
        dequeueMethod: AnyDequeueMethod,
        reuseIdentifier: String? = nil,
        configure: @escaping (View, Int, Section) -> Void,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
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

    /// Makes a new element for representing a cell
    /// - Parameters:
    ///   - section: The section where this element's cell will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a cell for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    ///   - willAppear: A closure that will be called before the elements view appears
    ///   - didDisappear: A closure that will be called after the elements view disappears
    public init<Section, View: UICollectionViewCell>(
        section: Section,
        dequeueMethod: DequeueMethod<View>,
        reuseIdentifier: String? = nil,
        configure: @MainActor @escaping (View, Int, Section) -> Void,
        willAppear: (@MainActor (View, Int, Section) -> Void)? = nil,
        didDisappear: (@MainActor (View, Int, Section) -> Void)? = nil,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
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

    /// Makes a new element for representing a cell
    /// - Parameters:
    ///   - section: The section where this element's cell will be shown in
    ///   - dequeueMethod: The method to use for registering and dequeueing a cell for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    ///   - willAppear: A closure that will be called before the elements view appears
    ///   - didDisappear: A closure that will be called after the elements view disappears
    public init<Section, View: UICollectionViewCell>(
        section: Section,
        dequeueMethod: AnyDequeueMethod,
        reuseIdentifier: String? = nil,
        configure: @MainActor @escaping (View, Int, Section) -> Void,
        willAppear: (@MainActor (View, Int, Section) -> Void)? = nil,
        didDisappear: (@MainActor (View, Int, Section) -> Void)? = nil,
        invalidViewHandler: InvalidViewHandler? = nil,
        invalidSectionHandler: InvalidSectionHandler<View>? = nil
    ) where Section: Composed.Section {
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

    /// Makes a new element for representing a cell
    /// - Parameters:
    ///   - dequeueMethod: The method to use for registering and dequeueing a cell for this element
    ///   - reuseIdentifier: The reuseIdentifier to use for this element
    ///   - configure: A closure that will be called whenever the elements view needs to be configured
    ///   - willAppear: A closure that will be called before the elements view appears
    ///   - didDisappear: A closure that will be called after the elements view disappears
    public init<View: UICollectionViewCell>(
        dequeueMethod: AnyDequeueMethod,
        reuseIdentifier: String? = nil,
        configure: @MainActor @escaping (View, Int) -> Void,
        willAppear: (@MainActor (View, Int) -> Void)? = nil,
        didDisappear: (@MainActor (View, Int) -> Void)? = nil,
        invalidViewHandler: (@MainActor (
            _ view: UICollectionReusableView,
            _ expectedType: UICollectionReusableView.Type,
            _ index: Int
        ) -> Void)? = nil
    ) {
        self.reuseIdentifier = reuseIdentifier ?? View.reuseIdentifier
        self.dequeueMethod = dequeueMethod

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
