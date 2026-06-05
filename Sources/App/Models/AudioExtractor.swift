import Foundation
import AVFoundation

/// 音频提取器 - 简洁可靠版
///
/// 1. ffmpeg 提取（在后台 DispatchQueue 同步执行，不阻塞协程池）
/// 2. 回退：AVFoundation 导出 M4A + 进程内 WAV 转换
struct AudioExtractor {
    enum ExtractionError: LocalizedError {
        case noAudioTrack
        case exportFailed(String)
        case ffmpegNotFound
        case wavConversionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAudioTrack: return "视频中没有找到音频轨道。"
            case .exportFailed(let detail): return "音频提取失败：\(detail)"
            case .ffmpegNotFound: return "未找到 ffmpeg。"
            case .wavConversionFailed(let detail): return "WAV 转换失败：\(detail)"
            }
        }
    }

    /// 查找 ffmpeg 可执行文件
    static func findFFmpeg() -> URL? {
        if let p = Bundle.main.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "bin") { return p }
        if let r = Bundle.main.resourceURL?.appendingPathComponent("bin/ffmpeg"),
           FileManager.default.fileExists(atPath: r.path) { return r }
        for path in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"] {
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    // MARK: - ffmpeg 提取（在后台线程同步执行，不阻塞协程池）

    /// 提取音频到 WAV 文件
    static func extractWAV(from videoURL: URL) async throws -> URL {
        guard let ffmpegURL = findFFmpeg() else {
            return try await extractWithAVFoundation(from: videoURL)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        // 在后台线程同步运行 ffmpeg
        let result: (stderr: String, success: Bool) = await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                proc.executableURL = ffmpegURL
                proc.arguments = [
                    "-i", videoURL.path,
                    "-map", "0:a:0",
                    "-vn",
                    "-c:a", "pcm_s16le",
                    "-ar", "16000",
                    "-ac", "1",
                    "-threads", "0",
                    "-loglevel", "error",
                    "-y",
                    outputURL.path
                ]
                let errPipe = Pipe()
                proc.standardError = errPipe

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    cont.resume(returning: (errStr, proc.terminationStatus == 0))
                } catch {
                    cont.resume(returning: (error.localizedDescription, false))
                }
            }
        }

        guard result.success,
              FileManager.default.fileExists(atPath: outputURL.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
              let size = attrs[.size] as? UInt64, size > 4096 else {
            // ffmpeg 失败，回退到 AVFoundation
            try? FileManager.default.removeItem(at: outputURL)
            return try await extractWithAVFoundation(from: videoURL)
        }

        return outputURL
    }

    // MARK: - AVFoundation 导出 + 进程内 WAV 转换

    /// 使用 AVFoundation 导出音频 → 进程内 WAV 转换（完全无外部进程）
    private static func extractWithAVFoundation(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = audioTracks.first else {
            throw ExtractionError.noAudioTrack
        }

        // 1. AVFoundation 导出为 M4A（使用新 API，macOS 15+）
        let m4aURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExtractionError.exportFailed("无法创建音频合成轨道。")
        }

        let timeRange = try await firstTrack.load(.timeRange)
        try compositionTrack.insertTimeRange(timeRange, of: firstTrack, at: .zero)

        guard let exportSession = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ExtractionError.exportFailed("无法创建导出会话。")
        }

        exportSession.outputURL = m4aURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = false
        await exportSession.export()

        guard FileManager.default.fileExists(atPath: m4aURL.path) else {
            throw ExtractionError.exportFailed("导出后文件不存在。")
        }

        // 2. 进程内 WAV 转换
        let wavURL = try await convertM4AToWAVInProcess(m4aURL: m4aURL)
        try? FileManager.default.removeItem(at: m4aURL)
        return wavURL
    }

    /// 进程内 M4A → WAV 转换
    private static func convertM4AToWAVInProcess(m4aURL: URL) async throws -> URL {
        let wavURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let asset = AVURLAsset(url: m4aURL)
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw ExtractionError.wavConversionFailed("无法创建 AssetReader。")
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 16000
        ]

        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw ExtractionError.wavConversionFailed("找不到音频轨道。")
        }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            // AVAssetReader 不支持此格式，回退到 afconvert
            return try fallbackAfconvert(m4aURL: m4aURL, wavURL: wavURL)
        }

        var allData = Data()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var dataPointer: UnsafeMutablePointer<Int8>?
                var dataLength: Int = 0
                CMBlockBufferGetDataPointer(blockBuffer,
                    atOffset: 0, lengthAtOffsetOut: nil,
                    totalLengthOut: &dataLength,
                    dataPointerOut: &dataPointer)
                if let ptr = dataPointer, dataLength > 0 {
                    allData.append(Data(bytes: ptr, count: dataLength))
                }
            }
        }

        guard allData.count > 0 else {
            reader.cancelReading()
            return try fallbackAfconvert(m4aURL: m4aURL, wavURL: wavURL)
        }

        // 写入 WAV 头
        try writeWAVHeaderAndData(data: allData, to: wavURL,
            sampleRate: 16000, channels: 1, bitsPerSample: 16)
        return wavURL
    }

    /// 回退：使用 afconvert（系统自带，不会被 sandbox 拦截）
    private static func fallbackAfconvert(m4aURL: URL, wavURL: URL) throws -> URL {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        proc.arguments = ["-f", "WAVE", "-d", "F32", m4aURL.path, wavURL.path]
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0,
              FileManager.default.fileExists(atPath: wavURL.path) else {
            throw ExtractionError.wavConversionFailed("afconvert 退出码: \(proc.terminationStatus)")
        }
        return wavURL
    }

    /// 写入 WAV 文件头 + PCM 数据
    private static func writeWAVHeaderAndData(data: Data, to url: URL,
        sampleRate: Int32, channels: Int16, bitsPerSample: Int16) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let fh = try FileHandle(forWritingTo: url)
        defer { fh.closeFile() }

        let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = Int32(data.count)
        let fileSize = dataSize + 36

        fh.write(Data("RIFF".utf8))
        withUnsafeBytes(of: fileSize.littleEndian) { fh.write(Data($0)) }
        fh.write(Data("WAVE".utf8))
        fh.write(Data("fmt ".utf8))
        let fmtSize: Int32 = 16
        withUnsafeBytes(of: fmtSize.littleEndian) { fh.write(Data($0)) }
        let audioFormat: Int16 = 1
        withUnsafeBytes(of: audioFormat.littleEndian) { fh.write(Data($0)) }
        withUnsafeBytes(of: channels.littleEndian) { fh.write(Data($0)) }
        withUnsafeBytes(of: sampleRate.littleEndian) { fh.write(Data($0)) }
        withUnsafeBytes(of: byteRate.littleEndian) { fh.write(Data($0)) }
        withUnsafeBytes(of: blockAlign.littleEndian) { fh.write(Data($0)) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { fh.write(Data($0)) }
        fh.write(Data("data".utf8))
        withUnsafeBytes(of: dataSize.littleEndian) { fh.write(Data($0)) }
        fh.write(data)
    }
}
