import Foundation
import CoreGraphics

@main
struct ReadiumWordAnchorTest {
  static func main() {
    let payload: [String: Any] = [
      "wordRect": ["x": 20.0, "y": 40.0, "width": 60.0, "height": 24.0],
      "viewport": ["width": 400.0, "height": 800.0],
    ]
    precondition(ReadiumWordAnchor.webViewRect(payload: payload, size: CGSize(width: 200, height: 400)) == CGRect(x: 10, y: 20, width: 30, height: 12))
    precondition(ReadiumWordAnchor.webViewRect(payload: payload, size: .zero) == nil)
    for badWord in [
      ["x": -1.0, "y": 40.0, "width": 60.0, "height": 24.0],
      ["x": 380.0, "y": 40.0, "width": 60.0, "height": 24.0],
      ["x": 20.0, "y": 40.0, "width": 0.0, "height": 24.0],
      ["x": Double.infinity, "y": 40.0, "width": 60.0, "height": 24.0],
    ] {
      var invalid = payload
      invalid["wordRect"] = badWord
      precondition(ReadiumWordAnchor.webViewRect(payload: invalid, size: CGSize(width: 400, height: 800)) == nil)
    }
    precondition(ReadiumWordAnchor.webViewRect(payload: [:], size: CGSize(width: 400, height: 800)) == nil)
    for invalidX: Any in [true, "20"] {
      var invalid = payload
      invalid["wordRect"] = ["x": invalidX, "y": 40, "width": 60, "height": 24]
      precondition(ReadiumWordAnchor.webViewRect(payload: invalid, size: CGSize(width: 400, height: 800)) == nil)
    }

    let size = CGSize(width: 200, height: 200)
    precondition(ReadiumWordAnchor.webViewRects(payload: payload, size: size) == [CGRect(x: 10, y: 10, width: 30, height: 6)])

    let first: [String: Any] = ["x": 160.0, "y": 40.0, "width": 40.0, "height": 24.0]
    let second: [String: Any] = ["x": 20.0, "y": 100.0, "width": 70.0, "height": 24.0]
    var wrapped = payload
    wrapped["wordRect"] = ["x": 20.0, "y": 40.0, "width": 180.0, "height": 84.0]
    wrapped["wordRects"] = [first, second]
    precondition(ReadiumWordAnchor.webViewRects(payload: wrapped, size: size) == [
      CGRect(x: 80, y: 10, width: 20, height: 6),
      CGRect(x: 10, y: 25, width: 35, height: 6),
    ])
    precondition(ReadiumWordAnchor.webViewRects(payload: wrapped, size: .zero) == nil)

    for invalidRects: Any in [[], NSNull(), first, [first, "invalid"], Array(repeating: first, count: 513)] {
      var invalid = wrapped
      invalid["wordRects"] = invalidRects
      precondition(ReadiumWordAnchor.webViewRects(payload: invalid, size: size) == nil)
    }
    for invalidRect: [String: Any] in [
      ["x": true, "y": 40, "width": 40, "height": 24],
      ["x": "160", "y": 40, "width": 40, "height": 24],
      ["x": Double.infinity, "y": 40, "width": 40, "height": 24],
      ["x": -1, "y": 40, "width": 40, "height": 24],
      ["x": 380, "y": 40, "width": 40, "height": 24],
      ["x": 160, "y": 40, "width": 0, "height": 24],
      [:],
    ] {
      var invalid = wrapped
      invalid["wordRects"] = [first, invalidRect, second]
      precondition(ReadiumWordAnchor.webViewRects(payload: invalid, size: size) == nil)
    }
    var maximum = wrapped
    maximum["wordRects"] = Array(repeating: first, count: 512)
    precondition(ReadiumWordAnchor.webViewRects(payload: maximum, size: size)?.count == 512)
    var missingViewport = wrapped
    missingViewport.removeValue(forKey: "viewport")
    precondition(ReadiumWordAnchor.webViewRects(payload: missingViewport, size: size) == nil)
  }
}
