import Foundation

struct SubtitleGenerator {
    // ── SRT ──
    static func generateSRT(segments: [(sourceText: String, translatedText: String, start: Double, end: Double)]) -> String {
        var output = ""
        for (i, seg) in segments.enumerated() {
            let t = formatTime(seg.start) + " --> " + formatTime(seg.end)
            output += "\(i+1)\n\(t)\n\(seg.translatedText)\n\(seg.sourceText)\n\n"
        }
        return output
    }

    // ── ASS (styled) ──
    static func generateASS(
        segments: [(sourceText: String, translatedText: String, start: Double, end: Double)],
        chineseFont: String = "SFProDisplay-Regular",
        chineseSize: Int = 26,
        englishFont: String = "SFProDisplay-Regular",
        englishSize: Int = 19,
        bgAlpha: String = "88"  // 88 = ~53% opacity in ASS alpha (00=opaque, FF=transparent)
    ) -> String {
        let resolution = 1920
        let styleLine = "Style: Bilingual,\(chineseFont),\(englishSize),&H00FFFFFF,&H000000FF,&H00444444,&H\(bgAlpha)000000,0,0,0,0,100,100,0,0,1,1.5,4,2,40,40,60,1"

        var output = """
[Script Info]
ScriptType: v4.00+
PlayResX: \(resolution)
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
\(styleLine)

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

"""
        for seg in segments {
            let start = formatASS(seg.start)
            let end = formatASS(seg.end)
            // Chinese: larger font on top, English: smaller below
            let text: String
            if chineseFont == englishFont && chineseSize == englishSize {
                text = "\(seg.translatedText)\\N\(seg.sourceText)"
            } else {
                text = "{\\fs\(chineseSize)}\(seg.translatedText)\\N{\\fs\(englishSize)}\(seg.sourceText)"
            }
            output += "Dialogue: 0,\(start),\(end),Bilingual,,0,0,0,,\(text)\n"
        }
        return output
    }

    // ── Save ──
    static func saveToDownloads(content: String, baseName: String, ext: String) -> URL {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        var path = downloads.appendingPathComponent("\(baseName)_bilingual.\(ext)")
        var counter = 1
        while FileManager.default.fileExists(atPath: path.path) {
            path = downloads.appendingPathComponent("\(baseName)_bilingual_\(counter).\(ext)")
            counter += 1
        }
        try? content.write(to: path, atomically: true, encoding: .utf8)
        return path
    }

    // ── Time helpers ──
    private static func formatTime(_ s: Double) -> String {
        let ms = Int(s * 1000)
        return String(format: "%02d:%02d:%02d,%03d", ms/3600000, (ms%3600000)/60000, (ms%60000)/1000, ms%1000)
    }
    private static func formatASS(_ s: Double) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = s.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%02d:%05.2f", h, m, sec)
    }
}
