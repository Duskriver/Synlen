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
  }
}
