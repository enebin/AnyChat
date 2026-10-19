import SwiftUI
import XCTest
@testable import AnyChatUI

@MainActor
final class MessageBubbleShapeTests: XCTestCase {
    func testTailUnionNeverCutsAHoleInsideTheRoundedBody() {
        // Given
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let overlapPoints = [CGPoint(x: 12, y: 38), CGPoint(x: 88, y: 38)]

        for isMine in [false, true] {
            let body = MessageBubbleShape(isMine: isMine, showsTail: false).path(in: rect)

            // When
            let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width,
                                    height: rect.height + MessageBubbleShape.tailHeight)
            let bubble = MessageBubbleShape(isMine: isMine, showsTail: true).path(in: bubbleRect)

            // Then
            for point in overlapPoints {
                XCTAssertTrue(body.contains(point))
                XCTAssertTrue(bubble.contains(point))
            }
            XCTAssertGreaterThan(bubble.boundingRect.maxY, body.boundingRect.maxY)
        }
    }
    func testTailFitsInsideTheProposedFrameOnBothSides() {
        // Given
        let frames = [CGRect(x: 0, y: 0, width: 100, height: 47),
                      CGRect(x: 13, y: 17, width: 280, height: 180)]
        let tolerance: CGFloat = 0.01

        for frame in frames {
            for isMine in [false, true] {
                // When
                let bounds = MessageBubbleShape(isMine: isMine, showsTail: true)
                    .path(in: frame).boundingRect

                // Then
                XCTAssertGreaterThanOrEqual(bounds.minX, frame.minX - tolerance)
                XCTAssertGreaterThanOrEqual(bounds.minY, frame.minY - tolerance)
                XCTAssertLessThanOrEqual(bounds.maxX, frame.maxX + tolerance)
                XCTAssertLessThanOrEqual(bounds.maxY, frame.maxY + tolerance)
            }
        }
    }
}
