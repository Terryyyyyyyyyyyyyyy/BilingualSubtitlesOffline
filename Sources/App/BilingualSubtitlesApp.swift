import SwiftUI

@main
struct BilingualSubtitlesApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 640, minHeight: 520)
                .kamiCanvas()
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .defaultSize(width: 720, height: 600)
    }
}

@Observable
final class AppState {
    enum Phase: Equatable {
        case idle
        case loadingModel(String)
        case extractingAudio
        case transcribing(Double)
        case translating(Double)
        case generatingSubtitles
        case completed
        case error(String)
    }

    var phase: Phase = .idle
    var videoURL: URL?
    var videoFileName: String = ""
    var subtitleContent: String?
    var subtitleURL: URL?
    var sourceLanguage: String = "en"
    var targetLanguage: String = "zh"
    var modelPath: String = ""

    func reset() {
        phase = .idle
        videoURL = nil
        videoFileName = ""
        subtitleContent = nil
        subtitleURL = nil
    }
}
