package dk.nota.flutterreadium

import android.graphics.Matrix
import android.graphics.RectF
import android.view.View
import android.view.ViewGroup
import org.json.JSONArray
import org.json.JSONObject

/** 把实际消息来源的 CSS 词矩形转换到 Flutter 平台视口内的逻辑坐标。 */
internal object ReadiumWordAnchor {
    fun inReader(
        payload: JSONObject,
        source: View,
        reader: ViewGroup,
    ): JSONObject? {
        val word = payload.optJSONObject("wordRect") ?: return null
        val viewport = payload.optJSONObject("viewport") ?: return null
        val rect = inSource(word, viewport, source) ?: return null
        return inReader(rect, source, reader)
    }

    fun wordRectsInReader(
        payload: JSONObject,
        source: View,
        reader: ViewGroup,
    ): JSONArray? {
        if (!payload.has("wordRects")) {
            return inReader(payload, source, reader)?.let { JSONArray().put(it) }
        }
        val words = payload.optJSONArray("wordRects") ?: return null
        val viewport = payload.optJSONObject("viewport") ?: return null
        if (words.length() !in 1..512) return null
        val result = JSONArray()
        for (index in 0 until words.length()) {
            val word = words.optJSONObject(index) ?: return null
            val rect = inSource(word, viewport, source) ?: return null
            inReader(rect, source, reader)?.let(result::put)
        }
        return result.takeIf { it.length() > 0 }
    }

    private fun inSource(
        word: JSONObject,
        viewport: JSONObject,
        source: View,
    ): RectF? {
        val x = word.number("x") ?: return null
        val y = word.number("y") ?: return null
        val width = word.number("width") ?: return null
        val height = word.number("height") ?: return null
        val viewportWidth = viewport.number("width") ?: return null
        val viewportHeight = viewport.number("height") ?: return null
        if (!listOf(x, y, width, height, viewportWidth, viewportHeight).all { it.isFinite() } ||
            x < 0 || y < 0 || width <= 0 || height <= 0 || viewportWidth <= 0 || viewportHeight <= 0 ||
            x + width > viewportWidth + 0.5 || y + height > viewportHeight + 0.5 ||
            source.width <= 0 || source.height <= 0 || !source.isShown
        ) {
            return null
        }
        val scaleX = source.width / viewportWidth
        val scaleY = source.height / viewportHeight
        return RectF(
            (x * scaleX).toFloat(),
            (y * scaleY).toFloat(),
            ((x + width) * scaleX).toFloat(),
            ((y + height) * scaleY).toFloat(),
        )
    }

    private fun inReader(
        rect: RectF,
        source: View,
        reader: ViewGroup,
    ): JSONObject? {
        val transform = Matrix()
        if (!sourceToAncestor(source, reader, transform)) return null
        transform.mapRect(rect)
        if (!rect.intersect(0f, 0f, reader.width.toFloat(), reader.height.toFloat())) return null
        val density = reader.resources.displayMetrics.density
        return JSONObject()
            .put("x", rect.left / density)
            .put("y", rect.top / density)
            .put("width", rect.width() / density)
            .put("height", rect.height() / density)
    }

    private fun JSONObject.number(key: String): Double? = (opt(key) as? Number)?.toDouble()

    private fun sourceToAncestor(
        view: View,
        ancestor: View,
        transform: Matrix,
    ): Boolean {
        if (view === ancestor) return true
        val parent = view.parent as? View ?: return false
        if (!sourceToAncestor(parent, ancestor, transform)) return false
        // CSS viewport 已扣除正文滚动；只计原生祖先滚动和变换，DPR 在输出时处理一次。
        transform.preTranslate(-parent.scrollX.toFloat(), -parent.scrollY.toFloat())
        transform.preTranslate(view.left.toFloat(), view.top.toFloat())
        if (!view.matrix.isIdentity) transform.preConcat(view.matrix)
        return true
    }
}
