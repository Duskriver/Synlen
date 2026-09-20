import Foundation

@main
struct PublicationFrameMatcherTest {
  static func main() {
    let nested = URL(string: "readium://publication/book/sub/a.xhtml")!
    precondition(PublicationFrameMatcher.resourceHref(frameURL: nested, readingOrder: ["a.xhtml", "sub/a.xhtml"]) == "sub/a.xhtml")
    precondition(PublicationFrameMatcher.resourceHref(frameURL: URL(string: "readium://publication/book/a.xhtml")!, readingOrder: ["a.xhtml", "sub/a.xhtml"]) == "a.xhtml")
    precondition(PublicationFrameMatcher.resourceHref(frameURL: URL(string: "readium://publication/book/not-a.xhtml")!, readingOrder: ["a.xhtml"]) == nil)
    precondition(PublicationFrameMatcher.resourceHref(frameURL: URL(string: "readium://publication/book/a%20b.xhtml")!, readingOrder: ["a%20b.xhtml"]) == "a%20b.xhtml")
    precondition(PublicationFrameMatcher.resourceHref(frameURL: nested, readingOrder: ["sub/a.xhtml", "sub/./a.xhtml"]) == nil)
    precondition(PublicationFrameMatcher.resourceHref(frameURL: nested, readingOrder: ["sub/a.xhtml", "sub/a.xhtml"]) == "sub/a.xhtml")
  }
}
