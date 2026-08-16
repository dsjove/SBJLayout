import Foundation
import Testing
import UIKit
@testable import SBJLayout

@Suite("JCSText")
struct JCSTextTests {
    @Test("Stored attributed content is immutable so copied values do not share mutable render state")
    func storedContentIsImmutable() {
        let text = JCSText(verbatim: "value semantics", font: UIFont.systemFont(ofSize: 12))
        let content = Mirror(reflecting: text).children.first { $0.label == "content" }?.value
        let unwrapped = Mirror(reflecting: content as Any).displayStyle == .optional
            ? Mirror(reflecting: content as Any).children.first?.value
            : content

        #expect(unwrapped is NSAttributedString)
        #expect(!(unwrapped is NSMutableAttributedString))
    }
}
