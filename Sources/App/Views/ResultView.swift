import SwiftUI

struct ResultView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: KamiTheme.spacingLg) {
            Spacer()

            // ── 完成图标 ──
            ZStack {
                Circle()
                    .fill(KamiTheme.success.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(KamiTheme.success)
            }

            Text("字幕生成完成！")
                .font(KamiTheme.headingFont)
                .foregroundColor(KamiTheme.textPrimary)

            // ── 文件信息卡片 ──
            if let url = appState.subtitleURL {
                HStack(spacing: KamiTheme.spacingSm) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(KamiTheme.accent)
                        .font(.caption)
                    Text(url.lastPathComponent)
                        .font(KamiTheme.bodyFont)
                        .foregroundColor(KamiTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(KamiTheme.textMuted)
                }
                .kamiCard()
                .padding(.horizontal, 80)
            }

            // ── 操作按钮 ──
            HStack(spacing: KamiTheme.spacingMd) {
                if let url = appState.subtitleURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("在 Finder 中显示", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KamiTheme.accent)
                    .controlSize(.large)

                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("打开字幕文件", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                    .tint(KamiTheme.accent)
                    .controlSize(.large)
                }
            }

            // ── 字幕内容预览 ──
            if let content = appState.subtitleContent {
                VStack(alignment: .leading, spacing: KamiTheme.spacingSm) {
                    Text("输出文件")
                        .font(KamiTheme.headingFont)
                        .foregroundColor(KamiTheme.textPrimary)

                    ScrollView {
                        Text(content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(KamiTheme.textSecondary)
                            .padding(KamiTheme.paddingMd)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .kamiCard()
                }
                .padding(.horizontal, 60)
            }

            // ── 底部信息 ──
            Text("提示：首次使用需安装语音识别字典包")
                .font(KamiTheme.captionFont)
                .foregroundColor(KamiTheme.textMuted)

            Divider()
                .frame(width: 260)
                .overlay(KamiTheme.border)
                .padding(.bottom, KamiTheme.spacingSm)

            // ── 返回按钮 ──
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { appState.reset() }
            } label: {
                HStack(spacing: KamiTheme.spacingSm) {
                    Image(systemName: "arrow.left.circle.fill")
                    Text("返回主界面")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: 260)
                .padding(.vertical, 10)
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
