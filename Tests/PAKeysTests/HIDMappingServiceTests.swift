import XCTest
@testable import PAKeys

final class HIDMappingServiceTests: XCTestCase {
    func testNullOutputIsEmpty() throws {
        XCTAssertEqual(try HIDMappingService.parseMappings("(null)\n"), [])
    }

    func testParsesJSONOutput() throws {
        let output = """
        [{"HIDKeyboardModifierMappingSrc":30064771303,"HIDKeyboardModifierMappingDst":30064771299}]
        """
        XCTAssertEqual(
            try HIDMappingService.parseMappings(output),
            [.init(source: 30_064_771_303, destination: 30_064_771_299)]
        )
    }

    func testParsesHIDUtilPropertyListOutput() throws {
        let output = """
        (
            {
                HIDKeyboardModifierMappingDst = 30064771299;
                HIDKeyboardModifierMappingSrc = 30064771303;
            }
        )
        """
        XCTAssertEqual(
            try HIDMappingService.parseMappings(output),
            [.init(source: 30_064_771_303, destination: 30_064_771_299)]
        )
    }
}
