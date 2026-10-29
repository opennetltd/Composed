import UIKit

/// Represents any type that can be loaded via a XIB/NIB
public protocol NibLoadable {
    @MainActor
    static var nib: UINib { get }

    static var nibName: String { get }

    /// Returns an instance of `Self` from a nib. Uses ``nibName-8ag89``.
    @MainActor
    static var fromNib: Self { get }

    /// Returns an instance of `Self` from a nib.
    ///
    /// - Parameter name: The name of the nib
    /// - Returns: A new instance of this type
    @MainActor
    static func fromNib(named name: String, withOwner ownerOrNil: Any?, options optionsOrNil: [UINib.OptionsKey: Any]?) -> Self

}

extension NibLoadable where Self: UIView {

    public static var nibName: String {
        return String(describing: self)
    }

    @MainActor
    public static var nib: UINib {
        return UINib(nibName: nibName, bundle: nil)
    }

    /// Returns an instance of `Self` from a nib. Uses String(describing: self) to determine the name of the nib.
    @MainActor
    public static var fromNib: Self {
        return fromNib(named: nibName)
    }

    /// Returns an instance of `Self` from a nib.
    ///
    /// - Parameter name: The name of the nib
    /// - Returns: A new instance of this type
    @MainActor
    public static func fromNib(named name: String, withOwner ownerOrNil: Any? = nil, options optionsOrNil: [UINib.OptionsKey: Any]? = nil) -> Self {
        let bundle = Bundle(for: self)

        guard let view = UINib(nibName: name, bundle: bundle)
            .instantiate(withOwner: ownerOrNil, options: optionsOrNil).first as? Self else {
                fatalError("Instantiation of \(nibName) from a nib failed")
        }

        return view
    }

}

public protocol ReusableCell: ReuseableView {
    static var reuseIdentifier: String { get }
}

extension ReusableCell {
    public static var reuseIdentifier: String {
        return String(describing: self)
    }
}

public protocol ReuseableView: UIView {
    static var reuseIdentifier: String { get }
    static var kind: String { get }

    @MainActor
    var reuseIdentifier: String? { get }
}

public extension ReuseableView {
    static var kind: String {
        return String(describing: self)
    }
}

extension UICollectionReusableView: ReusableCell { }
extension UICollectionReusableView: ReuseableView { }

public extension UICollectionView {

    // Editing

    var isEditing: Bool {
        return owningViewController?.isEditing ?? false
    }

    // Cells

    func register<C>(cell: C.Type) where C: UICollectionViewCell {
        self.register(cell, forCellWithReuseIdentifier: cell.reuseIdentifier)
    }

    func register<C>(nib: C.Type, bundle: Bundle? = nil) where C: UICollectionViewCell {
        self.register(UINib(nibName: String(describing: C.self), bundle: bundle ?? Bundle(for: C.self)),
                      forCellWithReuseIdentifier: nib.reuseIdentifier)
    }

    func dequeue<C>(cell: C.Type, reuseIdentifier: String? = nil, for indexPath: IndexPath) -> C where C: UICollectionViewCell {
        return dequeueReusableCell(withReuseIdentifier: reuseIdentifier ?? cell.reuseIdentifier, for: indexPath) as! C
    }

    // Supplementary views

    func register<C>(class: C.Type, ofKind kind: String) where C: UICollectionReusableView {
        self.register(`class`, forSupplementaryViewOfKind: kind, withReuseIdentifier: `class`.reuseIdentifier)
    }

    func register<C>(nib: C.Type, ofKind kind: String, bundle: Bundle? = nil) where C: UICollectionReusableView {
        self.register(UINib(nibName: String(describing: C.self), bundle: bundle ?? Bundle(for: C.self)),
                      forSupplementaryViewOfKind: kind, withReuseIdentifier: C.reuseIdentifier)
    }

    func dequeue<C>(supplementary: C.Type, ofKind kind: String, reuseIdentifier: String? = nil, for indexPath: IndexPath) -> C where C: UICollectionReusableView {
        return dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: reuseIdentifier ?? supplementary.reuseIdentifier, for: indexPath) as! C
    }
}

public extension UICollectionViewLayout {

    func register<C>(nib cellClass: C.Type, bundle: Bundle? = nil, ofKind kind: String) where C: UICollectionReusableView {
        let nib = UINib(nibName: String(describing: cellClass), bundle: bundle ?? Bundle(for: C.self))
        register(nib, forDecorationViewOfKind: kind)
    }

    func register<C>(class cellClass: C.Type, bundle: Bundle? = nil, ofKind kind: String) where C: UICollectionReusableView {
        register(cellClass, forDecorationViewOfKind: kind)
    }

}

private extension UIView {

    @objc var owningViewController: UIViewController? {
        var responder: UIResponder? = self

        while !(responder is UIViewController) && superview != nil {
            if let next = responder?.next {
                responder = next
            }
        }

        return responder as? UIViewController
    }

}
