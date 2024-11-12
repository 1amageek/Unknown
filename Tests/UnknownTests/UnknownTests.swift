import Foundation
import Testing
@testable import Unknown



@Test("testBasicComprehension")
func testComprehead() async throws {
    
    let understanding = try await Unknown("紅鮎").comprehend()
    print(understanding)
    #expect(!understanding.definition.isEmpty, "Definition should not be empty")
    #expect(!understanding.category.isEmpty, "Category should not be empty")
    #expect(understanding.confidence > 0.0 && understanding.confidence <= 1.0,
            "Confidence should be between 0 and 1")
    
}
