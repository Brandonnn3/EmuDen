import XCTest
@testable import EmulatorDomain

@MainActor final class AgeEligibilityTests: XCTestCase {
    func testRealResultWinsAndCancelsDeadline() async throws {
        let value = try await AgeEligibilityRequest().value(timeout: .seconds(1)) { false }
        XCTAssertFalse(value)
    }
    func testUnresponsiveServiceTimesOutAndLateReplyCannotResumeTwice() async {
        var lateReply: CheckedContinuation<Bool, Never>?
        do {
            _ = try await AgeEligibilityRequest().value(timeout: .milliseconds(20)) {
                await withCheckedContinuation { lateReply = $0 }
            }
            XCTFail("A service that never replies must not leave launch blocked")
        } catch { XCTAssertTrue(error is AgeEligibilityError) }
        XCTAssertNotNil(lateReply)
        lateReply?.resume(returning: true)
        await Task.yield()
    }
    func testCancellationFinishesWithoutGrantingAccess() async {
        let task = Task { try await AgeEligibilityRequest().value { try await Task.sleep(for: .seconds(30)); return true } }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled access check must not succeed") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
