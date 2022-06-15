import XCTest
import UIKit

/// Tests that are validating the logic of `UICollectionView`, without utilising anything from `Composed`/`ComposedUI`.
final class UICollectionViewTests: XCTestCase {
    func testReloadDataInBatchUpdate() throws {
        XCTExpectFailure("It is expected that calling `reloadData` is not supported within `performBatchUpdates`")

        let viewController = SpyCollectionViewController()
        viewController.applyInitialData([
            [
                "0, 0",
                "0, 1",
            ]
        ])

        viewController.collectionView.performBatchUpdates {
            viewController.data.append(["1, 0"])
            viewController.collectionView.reloadData()
        }
    }

    func testUpdatingBeforeBatchUpdatesWhenViewNeedsLayout() throws {
        XCTExpectFailure("It is expected that `performBatchUpdates` will crash when the data-side of the changes are applied before the call.")

        let viewController = SpyCollectionViewController()
        viewController.applyInitialData([
            [
                "0, 0",
                "0, 1",
            ]
        ])

        viewController.data.append(["1, 0"])

        viewController.collectionView.performBatchUpdates {
            viewController.collectionView.insertSections([1])
        }
    }

    /// A test to validate that element reloads are handled before section deletes.
    func testElementReloadsAreHandledBeforeRemoves() {
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 10_000, height: 10_000)))
        let viewController = SpyCollectionViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.applyInitialData([
            ["0, 0", "0, 1", "0, 2"],
        ])

        let callsCompletionExpectations = expectation(description: "Calls completion")

        /**
         This validates that the reloads are handled using the "before" indexes because
         `IndexPath(item: 2, section: 0)` is reloaded even though the "after" index path
         that is requested is `IndexPath(item: 1, section: 0)`.
         */
        viewController.collectionView.performBatchUpdates({
            viewController.data[0].remove(at: 1)
            viewController.data[0][0] = "0, 0 (updated)"
            viewController.data[0][1] = "0, 2 (updated)"
            viewController.collectionView.reloadItems(at: [
                IndexPath(item: 0, section: 0),
                IndexPath(item: 2, section: 0),
            ])
            viewController.collectionView.deleteItems(at: [
                IndexPath(item: 1, section: 0),
            ])
        }, completion: { _ in
            print(viewController.collectionView.visibleCells.map(\.contentView.subviews))
            XCTAssertEqual(viewController.requestedIndexPaths, [
                IndexPath(item: 0, section: 0),
                // This _should_ include item 1, but it isn't included and this
                // appears to be a bug in `UICollectionView`.
//                IndexPath(item: 1, section: 0),
            ])
            callsCompletionExpectations.fulfill()
        })

        waitForExpectations(timeout: 1)

        _ = window
    }

    /// A test to validate that element reloads are handled before section deletes.
    func testSimulatingReloadWithRemoveAndInsert() {
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 10_000, height: 10_000)))
        let viewController = SpyCollectionViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.applyInitialData([
            ["0, 0", "0, 1", "0, 2"],
        ])

        let callsCompletionExpectations = expectation(description: "Calls completion")

        viewController.collectionView.performBatchUpdates({
            viewController.data[0].remove(at: 1)
            viewController.data[0][0] = "0, 0 (updated)"
            viewController.data[0][1] = "0, 2 (updated)"
            viewController.collectionView.deleteItems(at: [
                IndexPath(item: 0, section: 0),
                IndexPath(item: 1, section: 0),
                IndexPath(item: 2, section: 0),
            ])
            viewController.collectionView.insertItems(at: [
                IndexPath(item: 0, section: 0),
                IndexPath(item: 1, section: 0),
            ])
        }, completion: { _ in
            XCTAssertEqual(viewController.requestedIndexPaths, [
                IndexPath(item: 0, section: 0),
                IndexPath(item: 1, section: 0),
            ])
            callsCompletionExpectations.fulfill()
        })

        waitForExpectations(timeout: 1)

        _ = window
    }

    /// A test to validate that section reloads are handled before section deletes.
    func testSectionReloadsAreHandledBeforeRemoves() {
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 10_000, height: 10_000)))
        let viewController = SpyCollectionViewController()
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.applyInitialData([
            ["0, 0"],
            ["1, 0", "1, 1", "1, 3"],
            ["2, 0"],
        ])

        let callsCompletionExpectations = expectation(description: "Calls completion")

        viewController.collectionView.performBatchUpdates({
            viewController.data.remove(at: 0)
            viewController.data[1] = ["2, 0 (new)"]
            viewController.collectionView.deleteSections([0])
            viewController.collectionView.reloadSections([2])
        }, completion: { _ in
            XCTAssertEqual(viewController.requestedIndexPaths, [IndexPath(item: 0, section: 1)])
            callsCompletionExpectations.fulfill()
        })

        waitForExpectations(timeout: 1)

        _ = window
    }
}
