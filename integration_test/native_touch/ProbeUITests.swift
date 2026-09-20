import XCTest

/// 仅消费测试回环坐标，所有触摸仍经过真实 UIKit 与阅读器桥接。
final class ProbeUITests: XCTestCase {
  private let base = "http://127.0.0.1:8766"

  private func state(_ path: String = "/state") async throws -> [String: Any] {
    let (data, _) = try await URLSession.shared.data(from: URL(string: base + path)!)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  @MainActor
  func testNativeInput() async throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.tanglei.synlen")
    app.activate()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
    let initial = try await state()
    if let viewport = initial["viewport"] as? [String: Double] {
      try await learningGestures(app, viewport: viewport)
      return
    }
    var performed = 0
    let deadline = Date().addingTimeInterval(300)
    while Date() < deadline {
      let current = try await state()
      if current["finished"] as? Bool == true {
        _ = try await state("/finish")
        return
      }
      if let touch = current["touch"] as? [String: Any],
         let id = touch["id"] as? Int, id > performed,
         let x = touch["x"] as? Double, let y = touch["y"] as? Double {
        let point = app.coordinate(withNormalizedOffset: .zero)
          .withOffset(CGVector(dx: x, dy: y))
        let duration = (touch["duration"] as? NSNumber)?.doubleValue ?? 0
        if duration > 0 { point.press(forDuration: duration) }
        else { point.tap() }
        performed = id
        _ = try await state("/performed?id=\(id)")
      } else {
        try await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    XCTFail("Flutter 原生触摸验收未结束")
  }

  @MainActor
  private func learningGestures(_ app: XCUIApplication, viewport: [String: Double]) async throws {
    let x = viewport["left"]! + viewport["width"]! / 2
    let y = viewport["top"]! + viewport["height"]! * 0.4
    for delta in [0.0, 5.0, -5.0, 10.0, -10.0, 15.0, -15.0] {
      _ = try await state("/reset")
      let point = app.coordinate(withNormalizedOffset: .zero)
        .withOffset(CGVector(dx: x, dy: y + delta))
      point.tap()
      try await Task.sleep(nanoseconds: 300_000_000)
      let current = try await state()
      let events = current["events"] as! [[String: Any]]
      if events.contains(where: { $0["kind"] as? String == "word" }) {
        _ = try await state("/arm")
        point.press(forDuration: 0.9)
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try await state("/finish")
        return
      }
    }
    XCTFail("Readium 的原生点词未到达学习入口")
  }
}
