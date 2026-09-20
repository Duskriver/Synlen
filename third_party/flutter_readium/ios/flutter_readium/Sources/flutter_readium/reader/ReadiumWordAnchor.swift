import Foundation
import CoreGraphics
import CoreFoundation

/// JS 提供顶层 WebView 的可见 CSS 矩形；这里仅转换到该原生视图的局部单位。
enum ReadiumWordAnchor {
  static func webViewRects(payload: [String: Any], size: CGSize) -> [CGRect]? {
    guard let raw = payload["wordRects"] else {
      return webViewRect(payload: payload, size: size).map { [$0] }
    }
    guard let words = raw as? [[String: Any]], !words.isEmpty, words.count <= 512 else { return nil }
    var result: [CGRect] = []
    for word in words {
      guard let rect = webViewRect(payload: ["wordRect": word, "viewport": payload["viewport"] as Any], size: size) else { return nil }
      result.append(rect)
    }
    return result
  }

  static func webViewRect(payload: [String: Any], size: CGSize) -> CGRect? {
    guard let word = payload["wordRect"] as? [String: Any],
          let viewport = payload["viewport"] as? [String: Any],
          let x = number(word["x"]), let y = number(word["y"]),
          let width = number(word["width"]), let height = number(word["height"]),
          let viewportWidth = number(viewport["width"]),
          let viewportHeight = number(viewport["height"]),
          [x, y, width, height, viewportWidth, viewportHeight].allSatisfy({ $0.isFinite }),
          size.width > 0, size.height > 0,
          x >= 0, y >= 0, width > 0, height > 0,
          viewportWidth > 0, viewportHeight > 0,
          x + width <= viewportWidth + 0.5,
          y + height <= viewportHeight + 0.5 else { return nil }
    let scaleX = size.width / CGFloat(viewportWidth)
    let scaleY = size.height / CGFloat(viewportHeight)
    let nativeX: CGFloat = CGFloat(x) * scaleX
    let nativeY: CGFloat = CGFloat(y) * scaleY
    let nativeWidth: CGFloat = CGFloat(width) * scaleX
    let nativeHeight: CGFloat = CGFloat(height) * scaleY
    return CGRect(x: nativeX, y: nativeY, width: nativeWidth, height: nativeHeight)
  }

  private static func number(_ value: Any?) -> Double? {
    guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
    return value.doubleValue
  }
}
