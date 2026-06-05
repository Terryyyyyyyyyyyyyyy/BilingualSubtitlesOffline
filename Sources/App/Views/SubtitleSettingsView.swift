import SwiftUI

struct SubtitleSettingsView: View {
    @Bindable var settings: SubtitleStyleSettings

    let sampleCN = "你好，欢迎观看这个视频。"
    let sampleEN = "Hello, welcome to this video."
    let baseWidth: CGFloat = 1920
    let baseHeight: CGFloat = 1080
    let previewWidth: CGFloat = 360
    var previewHeight: CGFloat { previewWidth * 9 / 16 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KamiTheme.spacingMd) {
                // ── 标题 ──
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size")
                        .foregroundColor(KamiTheme.accent)
                    Text("字幕样式设置")
                        .font(KamiTheme.headingFont)
                        .foregroundColor(KamiTheme.textPrimary)
                }

                // ── 视频预览 ──
                VStack(spacing: KamiTheme.spacingSm) {
                    Text("画面预览")
                        .font(KamiTheme.captionFont)
                        .foregroundColor(KamiTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                            .fill(Color.black)

                        if settings.enabled {
                            VStack(spacing: scaledSpacing) {
                                Text(sampleCN)
                                    .font(.custom(settings.chineseFontName, size: scaledChinese))
                                    .foregroundColor(.white).fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                                Text(sampleEN)
                                    .font(.custom(settings.englishFontName, size: scaledEnglish))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                            }
                            .padding(.horizontal, previewWidth * 0.08)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                                    .fill(Color.black.opacity(settings.backgroundOpacity))
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, previewHeight * 0.06)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "doc.text").font(.title2)
                                    .foregroundColor(.white.opacity(0.4))
                                Text("SRT 格式（无样式）\n字体由播放器决定")
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .font(KamiTheme.captionFont)
                            }
                        }
                    }
                    .frame(width: previewWidth, height: previewHeight)
                    .cornerRadius(KamiTheme.cornerSm)
                    .overlay(
                        RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                            .stroke(KamiTheme.border, lineWidth: 1)
                    )

                    // ── 尺寸标签 ──
                    HStack(spacing: 16) {
                        KamiChip(text: "中文 \(Int(settings.chineseFontSize))pt", icon: "character")
                        KamiChip(text: "英文 \(Int(settings.englishFontSize))pt", icon: "character")
                        KamiChip(text: "背景 \(Int(settings.backgroundOpacity * 100))%", icon: "square.on.square")
                    }
                }

                Divider().overlay(KamiTheme.border)

                // ── 启用开关 ──
                Toggle(isOn: $settings.enabled) {
                    Label("启用 ASS 样式字幕", systemImage: "doc.richtext")
                        .font(KamiTheme.bodyFont)
                }
                .toggleStyle(.switch)
                .tint(KamiTheme.accent)

                if settings.enabled {
                    // ── 中文设置 ──
                    KamiGroupBox(title: "中文（上方）", icon: "character") {
                        fontRow("字体", selection: $settings.chineseFontName)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("字号: \(Int(settings.chineseFontSize))pt")
                                .font(KamiTheme.captionFont)
                                .foregroundColor(KamiTheme.textSecondary)
                            Slider(value: $settings.chineseFontSize, in: 10...72, step: 1)
                                .tint(KamiTheme.accent)
                        }
                    }

                    // ── 英文设置 ──
                    KamiGroupBox(title: "英文（下方）", icon: "character") {
                        fontRow("字体", selection: $settings.englishFontName)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("字号: \(Int(settings.englishFontSize))pt")
                                .font(KamiTheme.captionFont)
                                .foregroundColor(KamiTheme.textSecondary)
                            Slider(value: $settings.englishFontSize, in: 8...64, step: 1)
                                .tint(KamiTheme.accent)
                        }
                    }

                    // ── 背景设置 ──
                    KamiGroupBox(title: "背景", icon: "square.on.square") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("不透明度: \(Int(settings.backgroundOpacity * 100))%")
                                .font(KamiTheme.captionFont)
                                .foregroundColor(KamiTheme.textSecondary)
                            Slider(value: $settings.backgroundOpacity, in: 0...1, step: 0.05)
                                .tint(KamiTheme.accent)
                        }
                    }
                }

                Spacer()
            }
            .padding(KamiTheme.paddingMd)
            .frame(width: 400)
        }
    }

    private var scale: CGFloat { previewWidth / baseWidth }
    private var scaledChinese: CGFloat { settings.chineseFontSize * scale }
    private var scaledEnglish: CGFloat { settings.englishFontSize * scale }
    private var scaledSpacing: CGFloat { 2 * scale }

    private func fontRow(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(KamiTheme.captionFont)
                .foregroundColor(KamiTheme.textSecondary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(SubtitleStyleSettings.availableFonts, id: \.postscript) { font in
                    Text(font.display).tag(font.postscript)
                }
            }
            .labelsHidden()
            .frame(width: 160)
        }
    }
}

// MARK: - Kami Group Box

struct KamiGroupBox<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KamiTheme.spacingMd) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(KamiTheme.accent)
                Text(title)
                    .font(KamiTheme.bodyFont).fontWeight(.semibold)
                    .foregroundColor(KamiTheme.textPrimary)
            }
            content
        }
        .padding(KamiTheme.paddingMd)
        .background(
            RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                .fill(KamiTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                        .stroke(KamiTheme.borderLight, lineWidth: 1)
                )
        )
    }
}

// MARK: - Kami Chip

struct KamiChip: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(KamiTheme.smallFont)
        }
        .foregroundColor(KamiTheme.accent)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(KamiTheme.tagBg)
        .cornerRadius(KamiTheme.cornerSm)
    }
}
