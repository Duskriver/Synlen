package org.readium.r2.navigator.epub

import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import java.time.Duration
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.readium.r2.navigator.pager.R2EpubPageFragment
import org.readium.r2.shared.ExperimentalReadiumApi
import org.readium.r2.shared.InternalReadiumApi
import org.readium.r2.shared.publication.Link
import org.readium.r2.shared.publication.Locator
import org.readium.r2.shared.publication.Manifest
import org.readium.r2.shared.publication.Metadata
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.util.Url
import org.readium.r2.shared.util.mediatype.MediaType
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers

/** 排版由 WebView 回执替代，位置调度经过真实 Navigator 与视图生命周期。 */
@OptIn(ExperimentalReadiumApi::class, InternalReadiumApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class EpubNavigatorLocationTest {
    private val activityController = Robolectric.buildActivity(FragmentActivity::class.java)
    private val locations = mutableListOf<Locator>()
    private val links = (0..1).map { Link(Url("chapter$it.xhtml")!!, MediaType.XHTML) }

    @After
    fun close() {
        activityController.pause().stop().destroy()
    }

    @Test
    fun `loaded current page reports its position without a scroll debounce`() {
        val navigator = reader()
        finishCurrentPage(navigator)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(links[0].url()), locations.map { it.href })
    }

    @Test
    fun `preloaded page does not postpone an already loaded current page`() {
        val navigator = reader()
        finishCurrentPage(navigator)
        shadowOf(Looper.getMainLooper()).idle()
        finishNextPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        assertEquals(1, locations.size)
    }

    @Test
    fun `scroll changes remain debounced and collapse to one position`() {
        val navigator = reader()
        finishCurrentPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        locations.clear()
        repeat(3) { navigator.webViewListener.onProgressionChanged() }
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(99))
        assertTrue(locations.isEmpty())
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(1))
        assertEquals(1, locations.size)
    }

    @Test
    fun `preloaded page cannot report an unfinished current page`() {
        val navigator = reader()
        finishNextPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        assertTrue(locations.isEmpty())
    }

    @Test
    fun `preload completion does not restart an active scroll debounce`() {
        val navigator = reader()
        finishCurrentPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        locations.clear()
        navigator.webViewListener.onProgressionChanged()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(50))
        finishNextPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(50))
        assertEquals(1, locations.size)
    }

    @Test
    fun `destroyed viewport cancels its pending location`() {
        val navigator = reader()
        finishCurrentPage(navigator)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        locations.clear()
        navigator.webViewListener.onProgressionChanged()
        activityController.get().supportFragmentManager.beginTransaction().remove(navigator).commitNow()
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(150))
        assertTrue(locations.isEmpty())
    }

    private fun currentPage(navigator: EpubNavigatorFragment) =
        navigator.adapter.getCurrentFragment() as R2EpubPageFragment

    private fun finishCurrentPage(navigator: EpubNavigatorFragment) {
        // Chromium 不在 Robolectric 中排版；从实际页面完成入口重放回执。
        ReflectionHelpers.callInstanceMethod<Unit>(currentPage(navigator), "onLoadPage")
    }

    private fun finishNextPage(navigator: EpubNavigatorFragment) {
        val next = navigator.adapter.getNextFragment() as R2EpubPageFragment
        ReflectionHelpers.callInstanceMethod<Unit>(next, "onLoadPage")
    }

    private fun reader(): EpubNavigatorFragment {
        val activity = activityController.get()
        activity.setTheme(androidx.appcompat.R.style.Theme_AppCompat)
        activityController.setup()
        val container = FrameLayout(activity).apply { id = View.generateViewId() }
        activity.setContentView(container)
        val publication = Publication(Manifest(
            metadata = Metadata(languages = listOf("en")),
            readingOrder = links,
        ))
        val factory = EpubNavigatorFactory(publication).createFragmentFactory(
            initialLocator = null,
            paginationListener = object : EpubNavigatorFragment.PaginationListener {
                override fun onPageChanged(pageIndex: Int, totalPages: Int, locator: Locator) {
                    locations.add(locator)
                }
            },
        )
        val navigator = factory.instantiate(activity.classLoader, EpubNavigatorFragment::class.java.name) as EpubNavigatorFragment
        activity.supportFragmentManager.beginTransaction().add(container.id, navigator).commitNow()
        val size = View.MeasureSpec.makeMeasureSpec(1080, View.MeasureSpec.EXACTLY)
        container.measure(size, size)
        container.layout(0, 0, 1080, 1080)
        shadowOf(Looper.getMainLooper()).idle()
        return navigator
    }
}
