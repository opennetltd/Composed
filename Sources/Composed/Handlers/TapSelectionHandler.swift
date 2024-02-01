/// A type that handles taps on individual elements.
///
/// When conforming to this protocol do not implement any of the methods from ``SelectionHandler``;
/// only implement ``didTapElement(at:)`` and handle the tap there.
public protocol TapSelectionHandler: SelectionHandler {
    /// A function called when the view representing the element at `index`.
    ///
    /// - parameter index: The index of the view that was tapped.
    func didTapElement(at index: Int)
}

extension TapSelectionHandler {
    public func shouldSelect(at index: Int) -> Bool {
        didTapElement(at: index)
        return false
    }
}
