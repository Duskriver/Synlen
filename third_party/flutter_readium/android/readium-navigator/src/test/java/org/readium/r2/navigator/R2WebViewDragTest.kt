package org.readium.r2.navigator

import android.os.Looper
import android.os.SystemClock
import android.view.InputDevice
import kotlin.math.sign
import org.readium.r2.shared.ExperimentalReadiumApi
import org.readium.r2.shared.InternalReadiumApi
import org.readium.r2.navigator.preferences.ReadingProgression
import org.readium.r2.shared.util.AbsoluteUrl
import org.robolectric.Shadows.shadowOf
import android.view.MotionEvent
import android.webkit.WebView
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.shadows.ShadowWebView
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter.from

/** 重放 WebView 收到的触摸和外层滚动；落页执行真实 R2WebView 路径。 */
@OptIn(ExperimentalReadiumApi::class, InternalReadiumApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "xxhdpi", shadows = [PagingWebViewShadow::class])
class R2WebViewDragTest {
    @Test
    fun `horizontal drag followed by release pause advances exactly one page`() {
        val view = reader()
        drag(view, duration = 450, pause = 400)
        assertEquals(1, view.mCurItem)
    }

    @Test
    fun `slow horizontal drag advances exactly one page`() {
        val view = reader()
        drag(view, duration = 900, pause = 0)
        assertEquals(1, view.mCurItem)
    }

    @Test
    fun `rightward paused drag returns exactly one page`() {
        val view = reader(3)
        drag(view, dx = 530f)
        assertEquals(2, view.mCurItem)
    }

    @Test
    fun `fast fling keeps original one page behavior`() {
        val view = reader()
        drag(view, duration = 120, pause = 0)
        assertEquals(1, view.mCurItem)
    }

    @Test
    fun `short and retracted drags stay on current page`() {
        for (retract in listOf(false, true)) {
            val view = reader(3)
            drag(view, dx = if (retract) -530f else -180f, retract = retract)
            assertEquals(3, view.mCurItem)
        }
    }

    @Test
    fun `vertical dominant drag does not gain distance pagination`() {
        val view = reader(3)
        drag(view, dy = 700f)
        assertEquals(3, view.mCurItem)
    }

    @Test
    fun `internal horizontal scroll without outer page movement stays put`() {
        for (page in listOf(0, 3, 12)) {
            val view = reader(page)
            drag(view, outerScroll = false)
            assertEquals(page, view.mCurItem)
        }
    }

    @Test
    fun `cancelled drag never completes a page turn`() {
        val view = reader(3)
        drag(view, endAction = MotionEvent.ACTION_CANCEL)
        assertEquals(3, view.mCurItem)
    }

    @Test
    fun `second pointer disables distance pagination for entire gesture`() {
        val view = reader(3)
        drag(view, secondPointer = true)
        assertEquals(3, view.mCurItem)
    }

    @Test
    fun `active text selection does not start distance pagination`() {
        val view = reader(3)
        view.isSelecting = true
        drag(view)
        assertEquals(3, view.mCurItem)
    }

    @Test
    fun `vertical scroll mode does not use distance pagination`() {
        val view = reader(3)
        view.scrollModeFlow.value = true
        drag(view)
        assertEquals(3, view.mCurItem)
    }

    @Test
    fun `native outer boundary uses one SDK resource transition in either reading direction`() {
        for (rtl in listOf(false, true)) {
            for (rightEdge in listOf(false, true)) {
                val view = reader(if (rightEdge) 12 else 0)
                val listener = ResourceListener(if (rtl) ReadingProgression.RTL else ReadingProgression.LTR)
                view.listener = listener
                drag(view, dx = if (rightEdge) -530f else 530f, outerScroll = false, outerBoundary = true)
                shadowOf(Looper.getMainLooper()).idle()
                assertEquals("rtl=$rtl rightEdge=$rightEdge", if (rightEdge != rtl) 1 else 0, listener.next)
                assertEquals("rtl=$rtl rightEdge=$rightEdge", if (rightEdge == rtl) 1 else 0, listener.previous)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun reader(page: Int = 0): R2WebView = R2WebView(
        RuntimeEnvironment.getApplication(),
        Robolectric.buildAttributeSet().build()
    ).apply {
        measure(android.view.View.MeasureSpec.makeMeasureSpec(WIDTH, android.view.View.MeasureSpec.EXACTLY),
            android.view.View.MeasureSpec.makeMeasureSpec(2000, android.view.View.MeasureSpec.EXACTLY))
        layout(0, 0, WIDTH, 2000)
        right = WIDTH
        bottom = 2000
        mCurItem = page
        scrollTo(page * WIDTH, 0)
        assertEquals(13, numPages)
    }

    private fun drag(
        view: R2WebView,
        duration: Long = 450,
        pause: Long = 400,
        dx: Float = -530f,
        dy: Float = 0f,
        outerScroll: Boolean = true,
        outerBoundary: Boolean = false,
        retract: Boolean = false,
        secondPointer: Boolean = false,
        endAction: Int = MotionEvent.ACTION_UP,
    ) {
        val start = SystemClock.uptimeMillis()
        val initialScroll = view.scrollX
        val initialX = if (dx < 0) 795f else 265f
        fun event(action: Int, time: Long, offsetX: Float, offsetY: Float = 0f, multi: Boolean = false) {
            val count = if (multi) 2 else 1
            val properties = Array(count) { id -> MotionEvent.PointerProperties().apply {
                this.id = id
                toolType = MotionEvent.TOOL_TYPE_FINGER
            } }
            val coords = Array(count) { id -> MotionEvent.PointerCoords().apply {
                x = initialX + offsetX + id * 40f
                y = 900f + offsetY
                pressure = 1f
                size = 1f
            } }
            MotionEvent.obtain(start, start + time, action, count, properties, coords,
                0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0).also {
                view.onTouchEvent(it)
                it.recycle()
            }
        }
        event(MotionEvent.ACTION_DOWN, 0, 0f)
        for (step in 1..8) {
            val portion = step / 8f
            event(MotionEvent.ACTION_MOVE, duration * step / 8, dx * portion, dy * portion)
            // Chromium 的排版不在 Robolectric 内运行，重放原生收到的外层 scrollX。
            if (outerScroll) view.scrollTo(initialScroll - (dx * portion).toInt(), 0)
        }
        // Android 通过 protected 回调通知外层触边；仅测试反射进入同一回调。
        if (outerBoundary) ReflectionHelpers.callInstanceMethod<Unit>(view, "onOverScrolled",
            from(Int::class.javaPrimitiveType, initialScroll), from(Int::class.javaPrimitiveType, 0),
            from(Boolean::class.javaPrimitiveType, true), from(Boolean::class.javaPrimitiveType, false))
        if (secondPointer) {
            event(MotionEvent.ACTION_POINTER_DOWN or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
                duration + 10, dx, dy, multi = true)
            event(MotionEvent.ACTION_POINTER_UP or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
                duration + 20, dx, dy, multi = true)
        }
        val finalDx = if (retract) dx.sign * 100f else dx
        if (retract && outerScroll) view.scrollTo(initialScroll - finalDx.toInt(), 0)
        // 影子 VelocityTracker 不随静止时间衰减；停住的 MOVE 明确记录终速为零。
        if (pause > 0) event(MotionEvent.ACTION_MOVE, duration + pause, finalDx, dy)
        event(endAction, duration + pause + 1, finalDx, dy)
    }

    private class ResourceListener(override val readingProgression: ReadingProgression) : R2BasicWebView.Listener {
        override val verticalText = false
        var next = 0
        var previous = 0
        override fun onFootnoteLinkActivated(url: AbsoluteUrl, context: HyperlinkNavigator.FootnoteContext) {}
        override fun goToNextResource(jump: Boolean, animated: Boolean): Boolean { next++; return true }
        override fun goToPreviousResource(jump: Boolean, animated: Boolean): Boolean { previous++; return true }
    }

    companion object { const val WIDTH = 1060 }
}

@Implements(WebView::class)
class PagingWebViewShadow : ShadowWebView() {
    @RealObject private lateinit var view: WebView

    @Implementation
    protected fun computeHorizontalScrollOffset(): Int = view.scrollX

    @Implementation
    protected fun computeHorizontalScrollRange(): Int = R2WebViewDragTest.WIDTH * 13

}
