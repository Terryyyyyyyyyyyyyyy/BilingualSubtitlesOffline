import Foundation
import Translation

struct TranslatedSegment: Codable, Sendable {
    let index: Int
    let sourceText: String
    let translatedText: String
}

/// 完全离线的翻译服务，使用 Apple 系统翻译框架 (macOS 15+)
/// 利用 Mac 神经网络引擎，无需网络连接，无需下载额外模型
struct TranslationService {
    enum TranslationError: LocalizedError {
        case notSupported
        case translationFailed(String)
        case notInstalled

        var errorDescription: String? {
            switch self {
            case .notSupported: return "当前语言对不支持系统翻译"
            case .translationFailed(let m): return "翻译失败: \(m)"
            case .notInstalled: return "翻译语言包未安装。请在 系统设置 > 通用 > 翻译语言 中下载所需语言包"
            }
        }
    }

    /// 使用 Apple 系统翻译框架翻译字幕段
    static func translate(
        segments: [(index: Int, text: String)],
        sourceLanguage: String,
        targetLanguage: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [TranslatedSegment] {
        let source = Locale.Language(identifier: normalizeLang(sourceLanguage))
        let target = Locale.Language(identifier: normalizeLang(targetLanguage))

        // 检查系统是否支持该语言对
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)

        guard status == .installed || status == .supported else {
            throw TranslationError.notSupported
        }

        // 创建翻译会话（使用 installedSource API，确保离线可用）
        let session = TranslationSession(installedSource: source, target: target)

        // 预热（确保模型就绪）
        if status != .installed {
            do {
                try await session.prepareTranslation()
            } catch {
                throw TranslationError.notInstalled
            }
        }

        // 逐段翻译
        var results: [TranslatedSegment] = []
        let total = segments.count

        for (i, seg) in segments.enumerated() {
            do {
                let response = try await session.translate(seg.text)
                results.append(TranslatedSegment(
                    index: seg.index,
                    sourceText: seg.text,
                    translatedText: response.targetText
                ))
            } catch {
                results.append(TranslatedSegment(
                    index: seg.index,
                    sourceText: seg.text,
                    translatedText: "[翻译失败]"
                ))
            }
            progressHandler?(Double(i + 1) / Double(total))
        }

        return results.sorted { $0.index < $1.index }
    }

    /// 标准化语言标识符
    private static func normalizeLang(_ lang: String) -> String {
        switch lang {
        case "zh": return "zh-Hans"
        default: return lang
        }
    }
}
