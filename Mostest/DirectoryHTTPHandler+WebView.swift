import FlyingFox
import Foundation

public struct PlotPreviewHTTPHandler: HTTPHandler {

    @UncheckedSendable
    private(set) var root: URL?
    let serverPath: String

    public init(root: URL, serverPath: String = "/") {
        self.root = root
        self.serverPath = serverPath
    }

    public init(bundle: Bundle, subPath: String = "", serverPath: String) {
        self.root = bundle.resourceURL?.appendingPathComponent(subPath)
        self.serverPath = serverPath
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard
            let filePath = makeFileURL(for: request.path),
            let data = try? Data(contentsOf: filePath) else {
            return HTTPResponse(statusCode: .notFound)
        }

        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "text/html"],
            body: data
        )
    }

    func makeFileURL(for requestPath: String) -> URL? {
        let compsA = serverPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        let compsB = requestPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        guard compsB.hasPrefix(compsA) else { return nil }
        let subPath = String(compsB.dropFirst(compsA.count))
        return root?.appendingPathComponent(subPath)
    }
}
