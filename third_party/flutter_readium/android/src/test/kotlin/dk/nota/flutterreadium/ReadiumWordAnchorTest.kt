package dk.nota.flutterreadium

import android.app.Activity
import android.view.View
import android.widget.FrameLayout
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "xxhdpi")
class ReadiumWordAnchorTest {
    @Test
    fun `包含原生页面偏移缩放和祖先滚动且只换算一次密度`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val reader = FrameLayout(activity)
        val page = FrameLayout(activity)
        val source = View(activity)
        reader.addView(page)
        page.addView(source)
        activity.setContentView(reader)
        reader.layout(0, 0, 1000, 1600)
        page.layout(60, 90, 960, 1590)
        source.layout(40, 50, 840, 1250)
        source.pivotX = 0f
        source.pivotY = 0f
        source.scaleX = 0.5f
        source.scaleY = 0.5f
        page.scrollTo(10, 20)
        source.scrollTo(500, 0)

        val anchor = ReadiumWordAnchor.inReader(payload(), source, reader)!!
        assertEquals(110.0 / 3, anchor.getDouble("x"), 0.001)
        assertEquals(160.0 / 3, anchor.getDouble("y"), 0.001)
        assertEquals(20.0, anchor.getDouble("width"), 0.001)
        assertEquals(8.0, anchor.getDouble("height"), 0.001)
    }

    @Test
    fun `拒绝其他视口的来源与不可见或无效词矩形`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val reader = FrameLayout(activity)
        val source = View(activity)
        reader.addView(source)
        activity.setContentView(reader)
        reader.layout(0, 0, 1000, 1600)
        source.layout(0, 0, 800, 1200)
        assertNull(ReadiumWordAnchor.inReader(payload(), source, FrameLayout(activity)))
        val outside = payload().apply { getJSONObject("wordRect").put("x", 390) }
        assertNull(ReadiumWordAnchor.inReader(outside, source, reader))
        assertNull(ReadiumWordAnchor.inReader(JSONObject(), source, reader))
        for (invalidX in listOf("20", true)) {
            val invalid = payload().apply { getJSONObject("wordRect").put("x", invalidX) }
            assertNull(ReadiumWordAnchor.inReader(invalid, source, reader))
        }
        source.translationX = 2000f
        assertNull(ReadiumWordAnchor.inReader(payload(), source, reader))
        source.translationX = 0f
        source.visibility = View.INVISIBLE
        assertNull(ReadiumWordAnchor.inReader(payload(), source, reader))
    }

    private fun payload(): JSONObject = JSONObject()
        .put("wordRect", JSONObject().put("x", 20).put("y", 40).put("width", 60).put("height", 24))
        .put("viewport", JSONObject().put("width", 400).put("height", 600))
}
