import FlyingFox
import Foundation

public struct FolderIndexHandler: HTTPHandler {
    let fileURLs: [URL]
    
    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let html = makeIndex(fileURLs)
        guard let bodyData = html.data(using: .utf8) else {
            return HTTPResponse(statusCode: .internalServerError)
        }
        return HTTPResponse(statusCode: .ok, body: bodyData)
    }
    
    private func makeList(_ urls: [URL]) -> String {
        let urlsString = urls.compactMap { url in
            "<li><a href=\(url.absoluteString)>\(url.lastPathComponent)</a></li>"
        }
        .joined()
        return urlsString
    }
    
    private func makeIndex(_ fileURLs: [URL]) -> String {
        """
        <!doctype html>
        <html>
            <head>
                <title>Mostest</title>
                <style>:root { font-family: system-ui; }</style>
            </head>
            <body>
                <h1>Mostest</h1>
                <ul>
                    \(makeList(fileURLs))
                </ul>
            </body>
        </html>
        """
    }
}

