import ReadiumNavigator
import ReadiumShared
import Flutter
import WebKit

private let jsonEncoder = JSONEncoder()

/// Breaks the `WKUserContentController → message-handler → EPUBReaderView` retain cycle.
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
  private weak var parent: EPUBReaderView?
  init(_ parent: EPUBReaderView) { self.parent = parent }
  func userContentController(_ ctrl: WKUserContentController, didReceive message: WKScriptMessage) {
    parent?.handleScriptMessage(message)
  }
}

/// The injected-user-script / JS-evaluation bridge to the WKWebView: building and
/// registering `WKUserScript`s (bootstrap shim, ToC ids, preference CSS, helper
/// bundle, the decoration-dedupe patch), evaluating arbitrary JS, and handling
/// messages posted back from the page.
extension EPUBReaderView {

  // implements EPUBNavigatorDelegate::navigator:setupUserScripts
  public func navigator(_ navigator: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController) {
    Log.reader.debug("setupUserScripts: adding \(self.userScripts.count) scripts")
    for script in userScripts {
      userContentController.addUserScript(script)
    }
    // Register handler so `window.updateNarrationSync(bool)` in the helper script can reach native.
    // WeakScriptHandler breaks the retain cycle WKUserContentController → handler → EPUBReaderView.
    userContentController.add(WeakScriptHandler(self), name: "narrationSync")
    userContentController.add(WeakScriptHandler(self), name: "flutterReadiumText")
    addCustomUserScripts(to: userContentController)

    /// Custom preferences added dynamically for each WebView, to make sure changes to preferences are respected.
    if let preferencesStylesheet = self.preferences.map(effectivePreferences)?.toInjectableStyleSheet() {
      let source = """
        (function() {
        var parent = document.getElementsByTagName('head').item(0);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = '\(preferencesStylesheet)';
        parent.appendChild(style)})();
      """
      userContentController.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
  }

  func evaluateJavascript(_ code: String) async -> Result<Any, Error> {
    return await self.readiumViewController.evaluateJavaScript(code)
  }

  private func evaluateJSReturnResult(_ code: String, result: @escaping FlutterResult) {
    Task.detached(priority: .high) {
      do {
        let data = try await self.evaluateJavascript(code).get()
        Log.reader.debug("evaluateJavascript result: \(data)")
        await MainActor.run() {
          return result(data)
        }
      } catch (let err) {
        Log.reader.error("evaluateJavascript error: \(err)")
        await MainActor.run() {
          return result(nil)
        }
      }
    }
  }

  /// Receives messages from the `window.updateNarrationSync(bool)` bridge injected
  /// by the iOS platform shim (bootstrap script in `initUserScripts`).
  func handleScriptMessage(_ message: WKScriptMessage) {
    guard !isDisposed else { return }
    if message.name == "flutterReadiumText" {
      guard let json = message.body as? String, json.utf16.count <= 65536,
            let data = json.data(using: .utf8),
            var payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let url = message.frameInfo.request.url,
            let topURL = message.webView?.url,
            url.scheme == topURL.scheme, url.host == topURL.host, url.port == topURL.port,
            let resourceHref = PublicationFrameMatcher.resourceHref(
              frameURL: url, readingOrder: publication.readingOrder.map(\.href)
            ) else { return }
      // 身份来自 WebKit 实际 frame；其他来源的 iframe 及不明确的路径均拒绝。
      payload["sessionId"] = sessionId
      payload["resourceHref"] = resourceHref
      guard let result = try? JSONSerialization.data(withJSONObject: payload),
            let resultJson = String(data: result, encoding: .utf8) else { return }
      channel.invokeMethod("onTextInteraction", arguments: resultJson)
      return
    }
    guard message.name == "narrationSync", let enabled = message.body as? Bool else { return }
    Log.reader.debug("handleScriptMessage: narrationSync=\(enabled)")
    Task { @MainActor in
      setNarrationSyncEnabled(enabled)
    }
  }

  internal func getPageInformation() async -> PageInformation? {
    switch await self.evaluateJavascript("window.flutterReadium.getPageInformation();") {
    case .success(let jresult):
      let pageInfo = PageInformation.fromJson(jresult as? Dictionary<String, Any> ?? Dictionary())
      return pageInfo
    case .failure(let err):
      Log.reader.error("getPageInformation failed! \(err)")
      return nil
    }
  }

  /// Loads a bundled Flutter asset's bytes, returning nil (and logging) instead of
  /// trapping when the asset is absent. The webview helper assets
  /// `assets/helpers/flutterReadiumTools.{js,css}` are gitignored build artifacts
  /// (compiled from assets/_helper_scripts/src via `npm run build` /
  /// `bin/install`); when an app is built without generating them, the reader now
  /// degrades — no helper injection — rather than crashing. See docs/troubleshooting.md.
  private func loadBundledAsset(_ assetKey: String) -> Data? {
    guard let path = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      Log.reader.error("Missing bundled asset '\(assetKey)' — were the webview helpers built? (npm run build / bin/install)")
      return nil
    }
    guard let data = FileManager().contents(atPath: path) else {
      Log.reader.error("Bundled asset '\(assetKey)' could not be read at \(path)")
      return nil
    }
    return data
  }

  /// 每个阅读视口维护自己的脚本及目录信息，预加载 WebView 复用当前视口的副本。
  func ensureUserScriptsInitialized(registrar: FlutterPluginRegistrar) {
    guard userScripts.isEmpty else { return }
    initUserScripts(registrar: registrar)
  }

  /// 应用资源在视口创建时冻结；新会话才读取新的注入登记。
  private func addCustomUserScripts(to controller: WKUserContentController) {
    guard let registrar = FlutterReadiumPlugin.registrar else { return }
    func load(_ asset: InjectionAsset) -> Data? {
      let key: String
      if let package = asset.packageName {
        key = registrar.lookupKey(forAsset: asset.assetPath, fromPackage: package)
      } else {
        key = registrar.lookupKey(forAsset: asset.assetPath)
      }
      guard let data = loadBundledAsset(key) else {
        channel.invokeMethod("onReaderError", arguments: "InjectionAssetUnavailable")
        return nil
      }
      return data
    }
    for asset in customCssInjections {
      guard let data = load(asset) else { continue }
      let source = """
        (() => {
          const style = document.createElement('style');
          style.textContent = new TextDecoder().decode(Uint8Array.from(atob('\(data.base64EncodedString())'), c => c.charCodeAt(0)));
          document.head.appendChild(style);
        })();
        """
      controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
    for asset in customJavaScriptInjections {
      guard let data = load(asset), let source = String(data: data, encoding: .utf8) else { continue }
      controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }
  }

  func initUserScripts(registrar: FlutterPluginRegistrar) {
    let flutterReadiumJsKey = registrar.lookupKey(forAsset: "assets/helpers/flutterReadiumTools.js", fromPackage: "flutter_readium")
    let flutterReadiumCssKey = registrar.lookupKey(forAsset: "assets/helpers/flutterReadiumTools.css", fromPackage: "flutter_readium")
    let jsScripts = [flutterReadiumJsKey].compactMap { assetKey -> String? in
      guard let data = loadBundledAsset(assetKey) else { return nil }
      return String(data: data, encoding: .utf8)
    }
    let addCssScripts = [flutterReadiumCssKey].compactMap { assetKey -> String? in
      guard let data = loadBundledAsset(assetKey) else { return nil }
      let base64Css = data.base64EncodedString()
      return """
        (function() {
        var parent = document.getElementsByTagName('head').item(0);
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = window.atob('\(base64Css)');
        parent.appendChild(style)})();
      """
    }

    /// INJECTED AT DOCUMENT START

    /// Add JS scripts right away, before loading the rest of the document.
    for jsScript in jsScripts {
      userScripts.append(WKUserScript(source: jsScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    /// Add all known ToC IDs for this publication to a global javascript array.
    do {
      let tocFragments = self.readiumViewController.publication.getFlattenedToC().compactMap(\.fragment)
      let data = try jsonEncoder.encode(tocFragments)
      if let tocFragmentsJSON = String(data: data, encoding: String.Encoding.utf8) {
        let tocScript = "window.readiumTocIDs = \(tocFragmentsJSON);"
        userScripts.append(WKUserScript(source: tocScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
      }
    } catch (let err) {
      Log.readium.error("Failed to inject ToC IDs in webview: \(err)")
    }

    /// INJECTED AT DOCUMENT END

    /// Add css injection scripts after primary document finished loading.
    for addCssScript in addCssScripts {
      userScripts.append(WKUserScript(source: addCssScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
    }

    // Set platform flags
    userScripts.append(WKUserScript(source: "const isAndroid=false,isIos=true;", injectionTime: .atDocumentStart, forMainFrameOnly: false))

    /// Platform shim: OS flags + window.updateNarrationSync bridge.
    /// Posting to the "narrationSync" WKScriptMessageHandler delivers the bool to native.
    userScripts.append(WKUserScript(source: """
      window.updateNarrationSync=function(v){webkit.messageHandlers.narrationSync.postMessage(v===true);};
      """, injectionTime: .atDocumentStart, forMainFrameOnly: false))

    /// Workaround for a swift-toolkit defect: when a spread's webview finishes loading,
    /// it re-injects every currently-stored decoration for that resource via unconditional
    /// `add()` calls, without clearing first. `DecorationGroup.add()` doesn't dedupe by
    /// logical decoration id, so if a decoration (e.g. our TTS "tts-utt"/"tts-range") was
    /// already applied to this resource before the re-injection ran — which can happen
    /// across a ToC jump while TTS is playing — the id ends up with two DOM elements, and
    /// the next incremental `update()` only ever removes the first match, leaving a stale
    /// duplicate underline/spotlight behind for the rest of the chapter. Patch `add()` to
    /// always clear any existing element for the same id first, making it idempotent.
    ///
    /// TODO: report upstream to readium/swift-toolkit — `spreadViewDidLoad`'s re-injection
    /// (EPUBNavigatorViewController.swift) should `clear()` a group before replaying it, and/or
    /// `DecorationChange` (DiffableDecoration.swift) should support removing *all* elements for
    /// an id rather than only the first match. Either upstream fix would let us drop this patch.
    /// There is also no public signal for "re-injection finished", which rules out a Swift-only
    /// ordering fix (e.g. deferring `apply()` until `locationDidChange`) — confirmed not to fully
    /// close the race in testing, since `locationDidChange` isn't causally ordered against it.
    userScripts.append(WKUserScript(source: """
      (function() {
        function patchGroup(group) {
          if (!group || group.__flutterReadiumDeduped || typeof group.add !== 'function' || typeof group.remove !== 'function') {
            return group;
          }
          group.__flutterReadiumDeduped = true;
          var originalAdd = group.add.bind(group);
          group.add = function(decoration) {
            group.remove(decoration.id);
            originalAdd(decoration);
          };
          return group;
        }
        if (window.readium && typeof window.readium.getDecorations === 'function' && !window.readium.__flutterReadiumDeduped) {
          window.readium.__flutterReadiumDeduped = true;
          var originalGetDecorations = window.readium.getDecorations.bind(window.readium);
          window.readium.getDecorations = function(groupName) {
            return patchGroup(originalGetDecorations(groupName));
          };
        }
      })();
      """, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
  }
}
