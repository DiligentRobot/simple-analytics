    import XCTest
    @testable import SimpleAnalytics

    final class SimpleAnalyticsTests: XCTestCase {
        private let endpoint = "testEndpoint"
        private let appName = "AppAnalytics Tester"
        private let moveSquare = "move square"
        private let jumpFive = "jump 5"

        var manager = AppAnalytics(endpoint: "", appName: "")
        
        override func setUp() {
            manager = AppAnalytics(endpoint: endpoint, appName: appName)
        }
        
        func testNameAndEndpoint() {
            XCTAssertEqual(manager.endpoint, endpoint)
            XCTAssertEqual(manager.appName, appName)
        }
        
        func testAddItem() {
            let openFile = "open file"
            let loadView = "load  view"
            let exitGame = "exit game"
            
            manager.addAnalyticsItem(openFile)
            manager.addAnalyticsItem(loadView)
            manager.addAnalyticsItem(moveSquare)
            manager.addAnalyticsItem(jumpFive)
            manager.addAnalyticsItem(exitGame)
            
            let actions = manager.items
            XCTAssertEqual(actions.count, 5)
            XCTAssertEqual(actions[0].eventName, openFile)
            XCTAssertEqual(actions[1].eventName, loadView)
            XCTAssertEqual(actions[2].eventName, moveSquare)
            XCTAssertEqual(actions[3].eventName, jumpFive)
            XCTAssertEqual(actions[4].eventName, exitGame)
        }


        
    }
