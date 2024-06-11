import FileMonitor
import FlyingFox
import FullDiskAccess
import SwiftUI

struct IndexHandler: HTTPHandler {
    let fileURLs: [URL]
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
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
    
    func makeIndex(_ fileURLs: [URL]) -> String {
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

struct ContentView: View {
    @State private var monitor: FileMonitor?
    @State private var watchedFolder = "Choose a folder"
    @State private var watchedFolderURL: URL? {
        didSet {
            self.watchedFolder = watchedFolderURL?.lastPathComponent ?? "Choose a folder"
        }
    }
    @State private var currentEventText = "Choose a folder"
    @State private var showFilePicker = false
    @State private var server = HTTPServer(port: 80)
    @State private var filesURLs = [URL]()
    
    private func serve(url: URL) async throws {
        await server.stop(timeout: 10)
        server = HTTPServer(port: 80)
        await server.appendRoute("GET /", to: IndexHandler(fileURLs: filesURLs))
        await server.appendRoute("GET /*", to: DirectoryHTTPHandler(root: url))
        try await server.start()
    }
    
    private func getFolderContents(url: URL) throws -> [URL] {
        let urls = try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            .sorted { alpha, bravo in
                alpha.absoluteString < bravo.absoluteString
            }
            .compactMap { url in
                URL(string: url.lastPathComponent)
            }
        return urls
    }
    
    private func watch(url: URL) async throws {
        self.monitor?.stop()
        self.monitor = try FileMonitor(directory: url)
        try self.monitor?.start()
        self.currentEventText = "Watching \(url.lastPathComponent)"
        guard let monitor else {
            return
        }
        if let urls = try? getFolderContents(url: url) {
            filesURLs = urls
        }
        try await serve(url: url)
        for await event in monitor.stream {
            switch event {
            case .added(file: let newURL):
                currentEventText = "New: \(newURL.lastPathComponent)"
                if let webURL = URL(string: newURL.lastPathComponent) {
                    filesURLs.append(webURL)
                }
            case .changed(file: let modifiedURL):
                currentEventText = "Mod: \(modifiedURL.lastPathComponent)"
                if let urls = try? getFolderContents(url: url) {
                    self.filesURLs = urls
                }
            case .deleted(file: let deletedURL):
                currentEventText = "Del: \(deletedURL.lastPathComponent)"
                filesURLs.removeAll { url in
                    url == deletedURL
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            Image(systemName: "folder")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text(currentEventText)
            List(filesURLs, id: \.self) { fileURL in
                Text(fileURL.lastPathComponent)
                    .onTapGesture {
                        NSWorkspace.shared.open(fileURL)
                    }
            }
        }
        .font(.title)
        .onTapGesture {
            showFilePicker.toggle()
        }
        .padding()
        .task {
            FullDiskAccess.promptIfNotGranted(
                title: "Enable Full Disk Access for Mostest",
                message: "Mostest requires Full Disk Access to monitor folders for changes",
                settingsButtonTitle: "Open Settings",
                skipButtonTitle: "Later",
                canBeSuppressed: false,
                icon: nil
            )
        }
        .toolbar {
            ToolbarItem {
                HStack {
                    Text(watchedFolder)
                    if watchedFolderURL != nil {
                        Image(systemName: "arrowshape.right.circle.fill")
                            .font(.callout)
                            .tint(Color.secondary)
                    }
                }
                .onTapGesture {
                    if let watchedFolderURL {
                        NSWorkspace.shared.open(watchedFolderURL)
                    }
                }
            }
            ToolbarItem {
                Button {
                    showFilePicker.toggle()
                } label: {
                    Label {
                        Text("Folder")
                    } icon: {
                        Image(systemName: "folder")
                    }
                }
                .fileImporter(isPresented: $showFilePicker, 
                              allowedContentTypes: [.folder]) { result in
                    filesURLs = []
                    switch result {
                    case .success(let url):
                        self.watchedFolderURL = url
                        Task {
                            do {
                                try await watch(url: url)
                            } catch {
                                currentEventText = error.localizedDescription
                            }
                        }
                    case .failure(let error):
                        self.monitor?.stop()
                        currentEventText = error.localizedDescription
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
