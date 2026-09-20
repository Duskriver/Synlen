package dk.nota.flutterreadium

import org.readium.r2.shared.publication.Locator
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.html.cssSelector
import org.readium.r2.shared.util.Url

/** 根据当前位置补充目录归属；正文选择器由当前出版物的缓存提供。 */
internal suspend fun Publication.enrichLocatorWithTocHref(
    locator: Locator,
    loadDocumentCssSelectors: suspend (Url) -> List<String>,
): Locator {
    if (!conformsTo(Publication.Profile.EPUB)) return locator

    locator.locations.tocHref?.let { tocHref ->
        return locator.copy(title = getTitleFromTocHref(tocHref))
    }
    val cssSelector = locator.locations.cssSelector ?: return locator
    val cleanHref = locator.href.cleanHref()
    val tocLinks =
        tableOfContents.flattenChildren().filter {
            it.href
                .resolve()
                .cleanHref()
                .path == cleanHref.path
        }

    // 无歧义的目录归属不需要解析正文；内容迭代会额外读入下一章才能发现资源边界。
    if (tocLinks.isEmpty()) return locator
    tocLinks.singleOrNull()?.let { return locator.copy(title = it.title).copyWithTocHref(it) }

    val documentCssSelectors = loadDocumentCssSelectors(locator.href)
    val index = documentCssSelectors.indexOf(cssSelector).takeIf { it >= 0 } ?: 0
    val toc =
        tocLinks.associateBy {
            documentCssSelectors.indexOf("#${it.href.resolve().fragment}")
        }
    val tocItem =
        toc.entries.lastOrNull { it.key <= index }?.value
            ?: toc.entries.firstOrNull()?.value
            ?: return locator
    return locator.copy(title = tocItem.title).copyWithTocHref(tocItem)
}
