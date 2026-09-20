package dk.nota.flutterreadium

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.readium.r2.shared.publication.Link
import org.readium.r2.shared.publication.Locator
import org.readium.r2.shared.publication.Manifest
import org.readium.r2.shared.publication.Metadata
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.util.Url
import org.readium.r2.shared.util.mediatype.MediaType
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EpubLocatorTocTest {
    @Test
    fun `当前资源没有目录项时不读取正文`() =
        runBlocking {
            val locator = locator()
            val result =
                publication(listOf(link("other.xhtml", "其他章")))
                    .enrichLocatorWithTocHref(locator) { error("不应读取正文") }
            assertEquals(locator, result)
        }

    @Test
    fun `唯一目录项直接补充归属且保留文字锚点`() =
        runBlocking {
            val locator = locator(":root > :nth-child(2) > :nth-child(1)")
            val chapter = link("chapter.xhtml#heading", "章节")
            val publication = publication(listOf(link("other.xhtml", "其他章", listOf(chapter))))
            val result = publication.enrichLocatorWithTocHref(locator) { error("不应读取正文") }
            assertEquals("章节", result.title)
            assertEquals("chapter.xhtml#heading", result.locations.tocHref)
            assertEquals(locator.text, result.text)
            assertEquals(locator.locations.otherLocations["cssSelector"], result.locations.otherLocations["cssSelector"])
        }

    @Test
    fun `多个目录项按原有正文顺序选择且只读取一次`() =
        runBlocking {
            val publication = publication(listOf(link("chapter.xhtml#first", "第一节"), link("chapter.xhtml#second", "第二节")))
            var reads = 0
            val result =
                publication.enrichLocatorWithTocHref(locator("#current")) { href ->
                    assertEquals("chapter.xhtml", href.toString())
                    reads++
                    listOf("#first", "#before", "#second", "#current")
                }
            assertEquals(1, reads)
            assertEquals("第二节", result.title)
            assertEquals("chapter.xhtml#second", result.locations.tocHref)
        }

    @Test
    fun `多个目录项保留未知选择器的首位置回退`() =
        runBlocking {
            val publication = publication(listOf(link("chapter.xhtml#first", "第一节"), link("chapter.xhtml#second", "第二节")))
            val result =
                publication.enrichLocatorWithTocHref(locator("#missing")) {
                    listOf("#first", "#second")
                }
            assertEquals("chapter.xhtml#first", result.locations.tocHref)
        }

    @Test
    fun `已有目录归属只更新标题而不读取正文`() =
        runBlocking {
            val publication = publication(listOf(link("chapter.xhtml#first", "新标题")))
            val locator = locator().copyWithTocHref(Url("chapter.xhtml#first")!!)
            val result = publication.enrichLocatorWithTocHref(locator) { error("不应读取正文") }
            assertEquals("新标题", result.title)
            assertEquals(locator.locations, result.locations)
        }

    @Test
    fun `无正文选择器时保留原位置`() =
        runBlocking {
            val locator = locator(null)
            val result =
                publication(listOf(link("chapter.xhtml", "章节")))
                    .enrichLocatorWithTocHref(locator) { error("不应读取正文") }
            assertEquals(locator, result)
            assertNull(result.locations.tocHref)
        }

    @Test
    fun `非EPUB出版物不读取正文或补充目录`() =
        runBlocking {
            val locator = locator()
            val publication = Publication(Manifest(metadata = Metadata(), readingOrder = listOf(link("chapter.xhtml", "章节"))))
            assertEquals(locator, publication.enrichLocatorWithTocHref(locator) { error("不应读取正文") })
        }

    private fun locator(selector: String? = "#current") =
        Locator(
            href = Url("chapter.xhtml")!!,
            mediaType = MediaType.XHTML,
            title = "原标题",
            locations = Locator.Locations(otherLocations = selector?.let { mapOf("cssSelector" to it) } ?: emptyMap()),
            text = Locator.Text(before = "before ", highlight = "word", after = " after"),
        )

    private fun link(
        href: String,
        title: String,
        children: List<Link> = emptyList(),
    ) = Link(
        href =
            org.readium.r2.shared.publication
                .Href(href)!!,
        mediaType = MediaType.XHTML,
        title = title,
        children = children,
    )

    private fun publication(toc: List<Link>) =
        Publication(
            Manifest(
                metadata = Metadata(conformsTo = setOf(Publication.Profile.EPUB)),
                readingOrder = listOf(link("chapter.xhtml", "章节")),
                tableOfContents = toc,
            ),
        )
}
