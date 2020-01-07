import Foundation

open class ComposedSectionProvider: AggregateSectionProvider, SectionProviderUpdateDelegate {

    private enum Child {
        case provider(SectionProvider)
        case section(Section)
    }

    open var updateDelegate: SectionProviderUpdateDelegate?

    private var children: [Child] = []

    public var sections: [Section] {
        return children.flatMap { kind -> [Section] in
            switch kind {
            case let .section(section):
                return [section]
            case let .provider(provider):
                return provider.sections
            }
        }
    }

    public var providers: [SectionProvider] {
        return children.compactMap { kind  in
            switch kind {
            case .section: return nil
            case let .provider(provider):
                return provider
            }
        }
    }

    public var numberOfSections: Int {
        return children.reduce(into: 0, { result, kind in
            switch kind {
            case .section: result += 1
            case let .provider(provider): result += provider.numberOfSections
            }
        })
    }

    public init() { }

    public func numberOfElements(in section: Int) -> Int {
        return sections[section].numberOfElements
    }

    public func sectionOffset(for provider: SectionProvider) -> Int {
        guard provider !== self else { return 0 }

        var offset: Int = 0

        for child in children {
            switch child {
            case .section:
                offset += 1
            case .provider(let childProvider):
                if childProvider === provider {
                    return offset
                } else if let childProvider = childProvider as? AggregateSectionProvider {
                    let sectionOffset = childProvider.sectionOffset(for: provider)
                    if sectionOffset != -1 {
                        return offset + sectionOffset
                    }
                }

                offset += childProvider.numberOfSections
            }
        }

        // Provider is not in the hierachy
        return -1
    }

    public func append(_ child: SectionProvider) {
        insert(child, at: children.count)
    }

    public func append(_ child: Section) {
        insert(child, at: children.count)
    }

    public func insert(_ child: Section, at index: Int) {
        guard (0...children.count).contains(index) else { fatalError("Index out of bounds: \(index)") }

        let index = index
        children.insert(.section(child), at: index)
        updateDelegate?.provider(self, didInsertSections: [child], at: IndexSet(integer: index))
    }

    public func insert(_ child: SectionProvider, at index: Int) {
        guard (0...children.count).contains(index) else { fatalError("Index out of bounds: \(index)") }

        child.updateDelegate = self

        let firstIndex = index
        let endIndex = firstIndex + child.sections.count

        children.insert(.provider(child), at: index)
        updateDelegate?.provider(self, didInsertSections: child.sections, at: IndexSet(integersIn: firstIndex..<endIndex))
    }

}
