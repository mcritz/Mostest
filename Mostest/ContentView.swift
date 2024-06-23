import FlyingFox
import SwiftUI

struct ContentView: View {
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
    
    /// Runs a web server inside the app
    /// - Parameter url: the folder on the users’ file system to host files form
    private func serve(url: URL) async throws {
        await server.stop()
        server = HTTPServer(port: 80)
        await server.appendRoute("GET /", to: FolderIndexHandler(fileURLs: filesURLs))
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
        self.currentEventText = "Watching \(url.lastPathComponent)"
        let urls = try getFolderContents(url: url)
        filesURLs = urls
        try await serve(url: url)
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
                    guard let watchedFolderURL else { return }
                    Task.detached {
                        try await watch(url: watchedFolderURL)
                    }
                } label: {
                    Label {
                        Text("Refresh Folder")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(watchedFolderURL == nil)
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
