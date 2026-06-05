import Foundation

struct SubtitleStyleConfig: Sendable {
    let enabled: Bool
    let chineseFont: String
    let chineseSize: Int
    let englishFont: String
    let englishSize: Int
    let bgAlpha: String

    init(from settings: SubtitleStyleSettings) {
        self.enabled = settings.enabled
        self.chineseFont = settings.chineseFontName
        self.chineseSize = Int(Double(settings.assChineseSize()) * 1.6)
        self.englishFont = settings.englishFontName
        self.englishSize = Int(Double(settings.assEnglishSize()) * 1.6)
        self.bgAlpha = settings.assBackAlpha()
    }
}

@Observable
final class VideoProcessor {
    var isProcessing = false

    func process(videoURL: URL, appState: AppState, style: SubtitleStyleConfig? = nil) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // ── 提取音频到临时 WAV 文件 ──
            await MainActor.run { appState.phase = .extractingAudio }
            let audioURL = try await AudioExtractor.extractWAV(from: videoURL)
            defer { try? FileManager.default.removeItem(at: audioURL) }

            // ── 语音识别 ──
            await MainActor.run { appState.phase = .transcribing(0) }
            let segments = try await WhisperService.transcribe(
                audioPath: audioURL.path,
                language: appState.sourceLanguage
            )

            guard !segments.isEmpty else {
                await MainActor.run { appState.phase = .error("未识别到语音内容。") }
                return
            }

            // ── 翻译 ──
            await MainActor.run { appState.phase = .translating(0) }
            let segsForTranslation = segments.enumerated().map { (i, s) in (index: i, text: s.text) }
            let translated = try await TranslationService.translate(
                segments: segsForTranslation,
                sourceLanguage: appState.sourceLanguage,
                targetLanguage: appState.targetLanguage
            )

            // ── 生成字幕 ──
            await MainActor.run { appState.phase = .generatingSubtitles }

            let merged = segments.enumerated().compactMap { (i, seg) -> (sourceText: String, translatedText: String, start: Double, end: Double)? in
                guard i < translated.count else { return nil }
                return (seg.text, translated[i].translatedText, seg.start, seg.end)
            }

            let baseName = videoURL.deletingPathExtension().lastPathComponent
            let srtContent = SubtitleGenerator.generateSRT(segments: merged)
            let srtURL = SubtitleGenerator.saveToDownloads(content: srtContent, baseName: baseName, ext: "srt")

            let assURL: URL?
            if let s = style, s.enabled {
                let assContent = SubtitleGenerator.generateASS(
                    segments: merged,
                    chineseFont: s.chineseFont,
                    chineseSize: s.chineseSize,
                    englishFont: s.englishFont,
                    englishSize: s.englishSize,
                    bgAlpha: s.bgAlpha
                )
                assURL = SubtitleGenerator.saveToDownloads(content: assContent, baseName: baseName, ext: "ass")
            } else {
                assURL = nil
            }

            let resultText: String
            if let u = assURL, let s = style {
                resultText = "【SRT】\(srtURL.lastPathComponent)\n【ASS 样式】\(u.lastPathComponent)\n  中文: \(s.chineseFont) \(s.chineseSize)pt\n  英文: \(s.englishFont) \(s.englishSize)pt\n  背景: \(Int(s.bgAlpha == "00" ? 100 : 50))% 不透明度"
            } else {
                resultText = "【SRT】\(srtURL.lastPathComponent)"
            }

            await MainActor.run {
                appState.subtitleContent = resultText
                appState.subtitleURL = assURL ?? srtURL
                appState.phase = .completed
            }
        } catch {
            await MainActor.run { appState.phase = .error(error.localizedDescription) }
        }
    }
}
