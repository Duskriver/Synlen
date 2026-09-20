package dk.nota.flutterreadium

import android.webkit.JavascriptInterface

/** 每个资源绑定自己的接收者，旧 WebView 无法把事件发给新阅读会话。 */
internal class EpubTextInteractionBridge(private val onMessage: (String) -> Unit) {
    @JavascriptInterface
    fun postMessage(json: String) {
        if (json.length <= 65536) onMessage(json)
    }
}
