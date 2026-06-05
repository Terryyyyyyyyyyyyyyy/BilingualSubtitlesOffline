import SwiftUI
import UniformTypeIdentifiers

struct VideoDropView: View {
    @Environment(AppState.self) private var appState
    @State private var isHovering = false
    @State private var showFilePicker = false
    @State private var showStyleSettings = false
    @State private var styleSettings = SubtitleStyleSettings()

    var body: some View {
        @Bindable var state = appState

        return VStack(spacing: KamiTheme.spacingXxl) {
            Spacer()

            // ── 标题区 ──
            VStack(spacing: KamiTheme.spacingSm) {
                HStack(spacing: 10) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(KamiTheme.accent)
                    Text("离线双语字幕生成器")
                        .font(KamiTheme.titleFont)
                        .foregroundColor(KamiTheme.textPrimary)
                }
                Text("拖入视频文件，本地自动生成双语字幕")
                    .font(KamiTheme.subtitleFont)
                    .foregroundColor(KamiTheme.textSecondary)
                KamiTagRow()
            }

            // ── 拖拽区 ──
            DropZone(isHovering: $isHovering)
                .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                    handleDrop(providers: providers)
                    return true
                }

            // ── 语言 + 样式 ──
            HStack(spacing: KamiTheme.spacingLg) {
                LanguagePicker(label: "源语言", selection: $state.sourceLanguage)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(KamiTheme.textMuted)
                LanguagePicker(label: "目标语言", selection: $state.targetLanguage)

                Divider().frame(height: 28)
                    .overlay(KamiTheme.border)

                Button {
                    showStyleSettings.toggle()
                } label: {
                    Label("字幕样式", systemImage: "textformat.size")
                        .font(KamiTheme.bodyFont)
                }
                .buttonStyle(.bordered)
                .tint(KamiTheme.accent)
                .popover(isPresented: $showStyleSettings) {
                    SubtitleSettingsView(settings: styleSettings)
                }
            }
            .kamiCard()
            .padding(.horizontal, 80)

            Spacer()

            // ── 底部信息 ──
            HStack(spacing: 4) {
                Text("提示：需安装语音识别字典包")
                    .font(KamiTheme.captionFont)
                    .foregroundColor(KamiTheme.textMuted)
                Circle().fill(KamiTheme.textMuted).frame(width: 3, height: 3)
                Text("请确保已下载对应语言字典")
                    .font(KamiTheme.captionFont)
                    .foregroundColor(KamiTheme.textMuted)
            }
            .padding(.bottom, KamiTheme.paddingMd)
        }
        .padding(KamiTheme.paddingLg)
        .kamiCanvas()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                startProcessing(videoURL: url)
            }
        }
    }

    private var allowedTypes: [UTType] {
        [.movie, .video,
         UTType(filenameExtension: "mp4") ?? .movie,
         UTType(filenameExtension: "mkv") ?? .movie,
         UTType(filenameExtension: "webm") ?? .movie,
         UTType(filenameExtension: "avi") ?? .movie,
         UTType(filenameExtension: "mov") ?? .movie]
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async { startProcessing(videoURL: url) }
        }
    }

    private func startProcessing(videoURL: URL) {
        let accessing = videoURL.startAccessingSecurityScopedResource()
        appState.videoURL = videoURL
        appState.videoFileName = videoURL.lastPathComponent
        let settings = styleSettings
        Task {
            defer {
                if accessing { videoURL.stopAccessingSecurityScopedResource() }
            }
            await VideoProcessor().process(videoURL: videoURL, appState: appState, style: SubtitleStyleConfig(from: settings))
        }
    }
}

// MARK: - Kami Tag Row

struct KamiTagRow: View {
    var body: some View {
        HStack(spacing: KamiTheme.spacingMd) {
            KamiTag(icon: "wifi.slash", text: "完全离线")
            KamiTag(icon: "cpu", text: "本地模型")
            KamiTag(icon: "textformat.size", text: "可调样式")
        }
    }
}

struct KamiTag: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(KamiTheme.tinyFont)
        }
        .foregroundColor(KamiTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(KamiTheme.tagBg)
        )
    }
}

// MARK: - Drop Zone

struct DropZone: View {
    @Binding var isHovering: Bool
    @State private var showFilePicker = false

    var body: some View {
        Button {
            showFilePicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: KamiTheme.cornerLg)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .fill(isHovering ? KamiTheme.accent : KamiTheme.borderLight)
                    .frame(width: 400, height: 200)

                VStack(spacing: KamiTheme.spacingMd) {
                    Image(systemName: isHovering ? "arrow.down.to.line.circle.fill" : "video.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(isHovering ? KamiTheme.accent : KamiTheme.textMuted)
                    Text(isHovering ? "释放以导入" : "拖放视频文件到这里")
                        .font(KamiTheme.headingFont)
                        .foregroundColor(isHovering ? KamiTheme.accent : KamiTheme.textSecondary)
                    HStack(spacing: 6) {
                        Text("或").font(KamiTheme.captionFont).foregroundColor(KamiTheme.textMuted)
                        Text("点击选择文件").font(KamiTheme.captionFont)
                            .foregroundColor(KamiTheme.accent).underline()
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Picker

struct LanguagePicker: View {
    let label: String
    @Binding var selection: String
    let languages: [(code: String, name: String)] = [
        ("en", "English"), ("zh", "中文"), ("ja", "日本語"),
        ("ko", "한국어"), ("fr", "Français"), ("de", "Deutsch"),
        ("es", "Español"), ("pt", "Português"), ("it", "Italiano"),
        ("ru", "Русский"), ("ar", "العربية"), ("vi", "Tiếng Việt"),
        ("th", "ไทย"), ("hi", "हिन्दी"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KamiTheme.captionFont)
                .foregroundColor(KamiTheme.textMuted)
            Picker("", selection: $selection) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
    }
}
