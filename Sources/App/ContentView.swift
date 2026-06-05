import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.phase {
            case .idle:
                VideoDropView()
            case .loadingModel, .extractingAudio, .transcribing, .translating, .generatingSubtitles:
                ProcessingView()
            case .completed:
                ResultView()
            case .error(let message):
                ErrorView(message: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: KamiTheme.spacingXl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(KamiTheme.error.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(KamiTheme.error)
            }

            Text("处理出错")
                .font(KamiTheme.headingFont)
                .foregroundColor(KamiTheme.textPrimary)

            Text(message)
                .font(KamiTheme.bodyFont)
                .foregroundColor(KamiTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KamiTheme.paddingLg)
                .kamiCard()

            Button {
                withAnimation { appState.reset() }
            } label: {
                Label("重新开始", systemImage: "arrow.counterclockwise")
                    .font(KamiTheme.bodyFont)
            }
            .buttonStyle(.borderedProminent)
            .tint(KamiTheme.accent)
            .controlSize(.large)

            Spacer()
        }
        .padding(KamiTheme.paddingLg)
        .kamiCanvas()
    }
}
