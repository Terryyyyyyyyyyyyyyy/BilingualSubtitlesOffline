import SwiftUI

struct ProcessingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: KamiTheme.spacingXl) {
            Spacer()

            // ── 当前步骤图标 ──
            ZStack {
                Circle()
                    .fill(KamiTheme.brandTint)
                    .frame(width: 80, height: 80)
                Image(systemName: currentIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(KamiTheme.accent)
            }

            Text(currentTitle)
                .font(KamiTheme.headingFont)
                .foregroundColor(KamiTheme.textPrimary)

            // ── 步骤卡片 ──
            VStack(spacing: KamiTheme.spacingSm) {
                KamiStepRow(icon: "square.and.arrow.down", label: "加载模型", phase: .loadingModel(""))
                KamiStepRow(icon: "waveform", label: "提取音频", phase: .extractingAudio)
                KamiStepRow(icon: "mic.fill", label: "语音识别", phase: .transcribing(0))
                KamiStepRow(icon: "translate", label: "翻译", phase: .translating(0))
                KamiStepRow(icon: "captions.bubble.fill", label: "生成字幕", phase: .generatingSubtitles)
            }
            .padding(.horizontal, 60)

            // ── 进度条 ──
            if case .transcribing(let p) = appState.phase {
                ProgressView(value: p, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(KamiTheme.accent)
                    .frame(width: 300)
                    .padding(.top, KamiTheme.spacingSm)
            } else if case .translating(let p) = appState.phase {
                VStack(spacing: KamiTheme.spacingSm) {
                    ProgressView(value: p, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(KamiTheme.accent)
                        .frame(width: 300)
                    Text("\(Int(p * 100))%")
                        .font(KamiTheme.captionFont)
                        .foregroundColor(KamiTheme.textSecondary)
                }
                .padding(.top, KamiTheme.spacingSm)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 300)
                    .tint(KamiTheme.accent)
                    .padding(.top, KamiTheme.spacingSm)
            }

            // ── 文件名 ──
            Label(appState.videoFileName, systemImage: "video.fill")
                .font(KamiTheme.captionFont)
                .foregroundColor(KamiTheme.textMuted)

            Spacer()
        }
        .padding(KamiTheme.paddingLg)
        .kamiCanvas()
    }

    private var currentIcon: String {
        switch appState.phase {
        case .loadingModel: return "square.and.arrow.down"
        case .extractingAudio: return "waveform"
        case .transcribing: return "mic.fill"
        case .translating: return "translate"
        case .generatingSubtitles: return "captions.bubble.fill"
        default: return "gear"
        }
    }

    private var currentTitle: String {
        switch appState.phase {
        case .loadingModel: return "准备模型..."
        case .extractingAudio: return "正在提取音频..."
        case .transcribing: return "正在识别语音..."
        case .translating: return "正在翻译..."
        case .generatingSubtitles: return "正在生成字幕..."
        default: return "处理中..."
        }
    }
}

struct KamiStepRow: View {
    enum StepState { case pending, inProgress, completed }
    let icon: String
    let label: String
    let phase: AppState.Phase

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: KamiTheme.spacingMd) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(state == .completed ? KamiTheme.stepDone :
                    state == .inProgress ? KamiTheme.stepActive : KamiTheme.stepPending)
                .frame(width: 20)

            Text(label)
                .font(KamiTheme.bodyFont)
                .foregroundColor(state == .completed ? KamiTheme.textPrimary :
                    state == .inProgress ? KamiTheme.stepActive : KamiTheme.textSecondary)

            Spacer()

            switch state {
            case .pending:
                Circle()
                    .fill(KamiTheme.stepPending.opacity(0.3))
                    .frame(width: 8, height: 8)
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .tint(KamiTheme.accent)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(KamiTheme.stepDone)
            }
        }
        .padding(.horizontal, KamiTheme.paddingMd)
        .padding(.vertical, KamiTheme.paddingSm)
        .background(
            RoundedRectangle(cornerRadius: KamiTheme.cornerSm)
                .fill(state == .inProgress ? KamiTheme.tagBg :
                      state == .completed ? KamiTheme.brandTint.opacity(0.4) : Color.clear)
        )
    }

    private var state: StepState {
        let order: [AppState.Phase] = [
            .loadingModel(""), .extractingAudio, .transcribing(0),
            .translating(0), .generatingSubtitles
        ]
        let current = appState.phase
        let phaseIdx = order.firstIndex { samePhase($0, phase) } ?? 0
        let currentIdx = order.firstIndex { samePhase($0, current) } ?? 0
        if phaseIdx < currentIdx { return .completed }
        if samePhase(phase, current) { return .inProgress }
        return .pending
    }

    private func samePhase(_ a: AppState.Phase, _ b: AppState.Phase) -> Bool {
        switch (a, b) {
        case (.loadingModel, .loadingModel),
             (.extractingAudio, .extractingAudio),
             (.transcribing, .transcribing),
             (.translating, .translating),
             (.generatingSubtitles, .generatingSubtitles):
            return true
        default: return false
        }
    }
}
