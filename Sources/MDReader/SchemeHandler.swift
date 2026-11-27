import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves two kinds of URL to the web view:
///   mdr://app/<path>    the bundled viewer (Contents/Resources/web)
///   mdr://file/<path>   any local file, so images next to the .md show up
/// A custom scheme sidesteps WKWebView's file:// read-access rules, which only
/// allow one directory tree per page.
final class SchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mdr"
    static let viewerURL = URL(string: "mdr://app/viewer.html")!

    private let webRoot: URL = Bundle.main.resourceURL!.appendingPathComponent("web").standardizedFileURL

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let file = resolve(url) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        do {
            let data = try Data(contentsOf: file)
            let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                "Content-Type": mime,
                "Content-Length": String(data.count),
                "Cache-Control": "no-store",
            ])!
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func resolve(_ url: URL) -> URL? {
        switch url.host {
        case "app":
            let file = webRoot.appendingPathComponent(url.path).standardizedFileURL
            return file.path.hasPrefix(webRoot.path + "/") ? file : nil
        case "file":
            return URL(fileURLWithPath: url.path)
        default:
            return nil
        }
    }
}
