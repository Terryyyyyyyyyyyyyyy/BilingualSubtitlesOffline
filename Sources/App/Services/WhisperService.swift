import Foundation

struct WhisperSegment {
    let start: Double
    let end: Double
    let text: String

    init(startMs: Int, endMs: Int, text: String) {
        self.start = Double(startMs) / 1000.0
        self.end = Double(endMs) / 1000.0
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 合并短段落后按句子边界拆分
    static func mergeAndSplit(_ segments: [WhisperSegment], maxGap: Double = 1.5) -> [WhisperSegment] {
        guard !segments.isEmpty else { return [] }

        var merged: [WhisperSegment] = []
        var currentText = ""
        var currentStart = segments[0].start
        var currentEnd = segments[0].end

        for seg in segments {
            let gap = seg.start - currentEnd
            let wouldBeLen = currentText.count + seg.text.count
            let hasPunct = currentText.hasSuffix(".") || currentText.hasSuffix("!") || currentText.hasSuffix("?") ||
                           currentText.hasSuffix("。") || currentText.hasSuffix("！") || currentText.hasSuffix("？") ||
                           currentText.hasSuffix("\"") || currentText.hasSuffix("'")

            if !currentText.isEmpty, gap > maxGap || wouldBeLen > 50 || hasPunct {
                merged.append(WhisperSegment(
                    startMs: Int(currentStart * 1000), endMs: Int(currentEnd * 1000), text: currentText
                ))
                currentText = ""
                currentStart = seg.start
                currentEnd = seg.end
            }

            if currentText.isEmpty {
                currentText = seg.text
                currentStart = seg.start
                currentEnd = seg.end
            } else {
                let sep = currentText.hasSuffix(" ") || seg.text.hasPrefix(" ") ? "" : " "
                currentText += sep + seg.text
                currentEnd = seg.end
            }
        }
        if !currentText.isEmpty {
            merged.append(WhisperSegment(
                startMs: Int(currentStart * 1000), endMs: Int(currentEnd * 1000), text: currentText
            ))
        }
        return splitBySentence(merged)
    }

    /// 按句子标点拆分成单个句子
    private static func splitBySentence(_ segments: [WhisperSegment]) -> [WhisperSegment] {
        let enders = Set<Character>([".", "!", "?", "。", "！", "？", "\"", "'"])
        var result: [WhisperSegment] = []
        for seg in segments {
            let text = seg.text
            guard !text.isEmpty else { continue }
            var sentences: [String] = []
            var current = ""
            for ch in text {
                current.append(ch)
                if enders.contains(ch) {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { sentences.append(trimmed) }
                    current = ""
                }
            }
            let remaining = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                if sentences.isEmpty {
                    sentences.append(remaining)
                } else {
                    sentences[sentences.count - 1] += " " + remaining
                }
            }

            if sentences.count <= 1 {
                result.append(seg)
            } else {
                let duration = seg.end - seg.start
                let avgDuration = duration / Double(sentences.count)
                for (idx, sentence) in sentences.enumerated() {
                    let s = seg.start + avgDuration * Double(idx)
                    let e = seg.start + avgDuration * Double(idx + 1)
                    result.append(WhisperSegment(
                        startMs: Int(s * 1000), endMs: Int(e * 1000), text: sentence
                    ))
                }
            }
        }
        return result
    }
}

// MARK: - whisper.cpp JSON 输出模型

private struct WhisperToken: Codable {
    let text: String
    let id: Int
    let tid: Int?
    let p: Double
    let ts: [Int]?
}

private struct WhisperSegmentJSON: Codable {
    let id: Int
    let seek: Int
    let start: Int
    let end: Int
    let text: String
    let tokens: [WhisperToken]
    let temperature: Double?
}

private struct WhisperOutput: Codable {
    let system: String?
    let model: String?
    let language: String?
    let segments: [WhisperSegmentJSON]?
}

struct WhisperService {
    enum WhisperError: LocalizedError {
        case modelNotFound
        case binaryNotFound
        case transcriptionFailed(String)
        case outputParseFailed(String)
        var errorDescription: String? {
            switch self {
            case .modelNotFound: return "模型文件未找到。请运行 setup.sh 下载。"
            case .binaryNotFound: return "whisper.cpp 引擎未找到。请重新编译。"
            case .transcriptionFailed(let m): return "语音识别失败: \(m)"
            case .outputParseFailed(let m): return "识别结果解析失败: \(m)"
            }
        }
    }

    static func findCLI() -> String? {
        if let p = Bundle.main.path(forResource: "whisper-cli", ofType: nil) { return p }
        if let exe = Bundle.main.executablePath {
            let s = (exe as NSString).deletingLastPathComponent + "/whisper-cli"
            if FileManager.default.fileExists(atPath: s) { return s }
        }
        return nil
    }

    /// 查找最佳可用模型（优先 small → base）
    static func findModel() -> String? {
        for name in ["small", "base"] {
            if let p = Bundle.main.path(forResource: "ggml-\(name)", ofType: "bin") {
                return p
            }
            if let exe = Bundle.main.executablePath {
                let s = (exe as NSString).deletingLastPathComponent + "/ggml-\(name).bin"
                if FileManager.default.fileExists(atPath: s) { return s }
            }
            let home = NSHomeDirectory()
            for cache in ["/.cache/whisper.cpp/ggml-\(name).bin",
                          "/.cache/bilingual-subtitles/ggml-\(name).bin"] {
                if FileManager.default.fileExists(atPath: home + cache) { return home + cache }
            }
            let bundleRes = Bundle.main.resourcePath ?? ""
            let depsPath = (bundleRes as NSString).deletingLastPathComponent + "/deps/models/ggml-\(name).bin"
            if FileManager.default.fileExists(atPath: depsPath) { return depsPath }
        }
        return nil
    }

    // MARK: - 语音识别（GPU 加速，后台线程执行）

    static func transcribe(audioPath: String, language: String) async throws -> [WhisperSegment] {
        guard let cliPath = findCLI() else { throw WhisperError.binaryNotFound }
        guard let modelPath = findModel() else { throw WhisperError.modelNotFound }

        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_\(UUID().uuidString.prefix(8))").path

        // 在后台线程同步运行 whisper-cli（默认启用 Metal GPU 加速）
        let result: (success: Bool, errorMsg: String) = await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: cliPath)
                proc.arguments = [
                    "--file", audioPath,
                    "--model", modelPath,
                    "--output-json",
                    "--output-file", outputPath,
                    "--language", language,
                    "--threads", String(ProcessInfo.processInfo.processorCount),
                ]
                let errPipe = Pipe()
                proc.standardError = errPipe

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    cont.resume(returning: (proc.terminationStatus == 0, errStr))
                } catch {
                    cont.resume(returning: (false, error.localizedDescription))
                }
            }
        }

        guard result.success else {
            throw WhisperError.transcriptionFailed(result.errorMsg)
        }

        let jsonPath = "\(outputPath).json"
        guard let data = FileManager.default.contents(atPath: jsonPath) else {
            let altPath = "\(outputPath).wav.json"
            if FileManager.default.fileExists(atPath: altPath) {
                guard let altData = FileManager.default.contents(atPath: altPath) else {
                    throw WhisperError.outputParseFailed("未找到输出文件。")
                }
                defer { try? FileManager.default.removeItem(atPath: altPath) }
                return try parseWhisperJSON(data: altData)
            }
            throw WhisperError.outputParseFailed("未找到输出文件。")
        }
        defer { try? FileManager.default.removeItem(atPath: jsonPath) }

        return try parseWhisperJSON(data: data)
    }

    /// 解析 whisper.cpp JSON 输出
    private static func parseWhisperJSON(data: Data) throws -> [WhisperSegment] {
        // 尝试新版 whisper.cpp 格式 (segments array)
        if let output = try? JSONDecoder().decode(WhisperOutput.self, from: data),
           let segments = output.segments, !segments.isEmpty {
            let parsed = segments.map { WhisperSegment(startMs: $0.start, endMs: $0.end, text: $0.text) }
            return WhisperSegment.mergeAndSplit(parsed, maxGap: 1.5)
        }

        // 尝试旧版格式 (transcription array with offsets)
        struct OldSeg: Codable {
            struct Offsets: Codable { let from: Int; let to: Int }
            let offsets: Offsets
            let text: String
        }
        struct OldOutput: Codable {
            let transcription: [OldSeg]
        }
        if let output = try? JSONDecoder().decode(OldOutput.self, from: data) {
            let parsed = output.transcription.map { WhisperSegment(startMs: $0.offsets.from, endMs: $0.offsets.to, text: $0.text) }
            return WhisperSegment.mergeAndSplit(parsed, maxGap: 1.5)
        }

        // 尝试纯数组格式
        if let arr = try? JSONDecoder().decode([WhisperSegmentJSON].self, from: data) {
            let parsed = arr.map { WhisperSegment(startMs: $0.start, endMs: $0.end, text: $0.text) }
            return WhisperSegment.mergeAndSplit(parsed, maxGap: 1.5)
        }

        throw WhisperError.outputParseFailed("JSON 格式不匹配。")
    }
}
