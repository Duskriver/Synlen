import Foundation

/// 从 WebKit 实际 frame 路径找最长完整资源路径，避免目录后缀重叠串页。
enum PublicationFrameMatcher {
  static func resourceHref(frameURL: URL, readingOrder: [String]) -> String? {
    let base = URL(string: "https://publication.invalid/")!
    let matches = Set(readingOrder).compactMap { href -> (String, String)? in
      guard let resourceURL = URL(string: href, relativeTo: base)?.absoluteURL else { return nil }
      let path = resourceURL.standardized.path
      guard path != "/", frameURL.standardized.path.hasSuffix(path) else { return nil }
      return (href, path)
    }
    guard let longest = matches.map({ $0.1.count }).max() else { return nil }
    let best = matches.filter { $0.1.count == longest }
    return best.count == 1 ? best[0].0 : nil
  }
}
