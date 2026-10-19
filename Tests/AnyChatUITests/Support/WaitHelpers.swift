import XCTest
@testable import AnyChatUI

extension XCTestCase {
    /// Waits for async work to settle without sleeping for a fixed duration.
    ///
    /// Doubles complete immediately, so yielding is enough to let the pending task run. The
    /// deadline only exists so a broken expectation fails instead of hanging the suite.
    @MainActor
    func waitUntil(
        timeout: Duration = .seconds(2),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: () -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)

        while !predicate() {
            guard ContinuousClock.now < deadline else {
                XCTFail("timed out waiting for the expected state", file: file, line: line)
                return
            }
            await Task.yield()
        }
    }
}
