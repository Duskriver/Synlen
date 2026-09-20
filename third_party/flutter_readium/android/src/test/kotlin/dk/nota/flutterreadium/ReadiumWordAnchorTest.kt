package dk.nota.flutterreadium

import android.app.Activity
import android.view.View
import android.widget.FrameLayout
import org.json.JSONArray
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

    private fun payload(): JSONObject =
        JSONObject()
            .put(
                "wordRect",
                JSONObject()
                    .put("x", 20)
                    .put("y", 40)
                    .put("width", 60)
                    .put("height", 24),
            ).put("viewport", JSONObject().put("width", 400).put("height", 600))

    @Test
    fun `跨行片段逐个转换并裁掉原生视口外片段`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val reader = FrameLayout(activity)
        val source = View(activity)
        reader.addView(source)
        activity.setContentView(reader)
        reader.layout(0, 0, 1000, 1600)
        source.layout(60, 90, 860, 1290)
        val words =
            JSONArray()
                .put(
                    JSONObject()
                        .put("x", 80)
                        .put("y", 40)
                        .put("width", 20)
                        .put("height", 24),
                ).put(
                    JSONObject()
                        .put("x", 20)
                        .put("y", 80)
                        .put("width", 60)
                        .put("height", 24),
                )
        val message = payload().put("wordRects", words)
        val rects = ReadiumWordAnchor.wordRectsInReader(message, source, reader)!!
        assertEquals(2, rects.length())
        assertEquals(220.0 / 3, rects.getJSONObject(0).getDouble("x"), 0.001)
        assertEquals(170.0 / 3, rects.getJSONObject(0).getDouble("y"), 0.001)
        assertEquals(100.0 / 3, rects.getJSONObject(1).getDouble("x"), 0.001)
        assertEquals(250.0 / 3, rects.getJSONObject(1).getDouble("y"), 0.001)
        assertEquals(1, ReadiumWordAnchor.wordRectsInReader(payload(), source, reader)!!.length())
        source.translationY = -230f
        val clipped = ReadiumWordAnchor.wordRectsInReader(message, source, reader)!!
        assertEquals(1, clipped.length())
        assertEquals(20.0 / 3, clipped.getJSONObject(0).getDouble("y"), 0.001)
        assertNull(ReadiumWordAnchor.wordRectsInReader(payload(), source, reader))
    }

    @Test
    fun `旧消息回退包围矩形且无效片段数组不穿透桥接`() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val reader = FrameLayout(activity)
        val source = View(activity)
        reader.addView(source)
        activity.setContentView(reader)
        reader.layout(0, 0, 1000, 1600)
        source.layout(0, 0, 800, 1200)
        assertEquals(1, ReadiumWordAnchor.wordRectsInReader(payload(), source, reader)!!.length())
        for (invalid in listOf(
            JSONArray(),
            JSONObject(),
            JSONArray().put(payload().getJSONObject("wordRect")).put("invalid"),
            JSONArray().put(
                JSONObject()
                    .put("x", true)
                    .put("y", 20)
                    .put("width", 30)
                    .put("height", 20),
            ),
            JSONArray().put(
                JSONObject()
                    .put("x", 390)
                    .put("y", 20)
                    .put("width", 30)
                    .put("height", 20),
            ),
            JSONArray(List(513) { payload().getJSONObject("wordRect") }),
        )) {
            assertNull(ReadiumWordAnchor.wordRectsInReader(payload().put("wordRects", invalid), source, reader))
        }
    }
}
