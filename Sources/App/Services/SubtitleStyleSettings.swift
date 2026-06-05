import SwiftUI

@Observable
final class SubtitleStyleSettings {
    var enabled: Bool = true
    var chineseFontName: String = "SF Pro Display"
    var chineseFontSize: CGFloat = 26
    var englishFontName: String = "SF Pro Display"
    var englishFontSize: CGFloat = 19
    var backgroundOpacity: Double = 0.5  // 0–1

    // Available system fonts for subtitle use
    static let availableFonts: [(display: String, postscript: String)] = [
        ("SF Pro Display", "SFProDisplay-Regular"),
        ("SF Pro Text", "SFProText-Regular"),
        ("PingFang SC", "PingFangSC-Regular"),
        ("Noto Sans SC", "NotoSansSC-Regular"),
        ("ST Heiti", "STHeitiSC-Light"),
        ("Helvetica Neue", "HelveticaNeue"),
        ("Arial", "ArialMT"),
    ]

    func assChineseSize() -> Int { Int(clamp(chineseFontSize, min: 10, max: 72)) }
    func assEnglishSize() -> Int { Int(clamp(englishFontSize, min: 8, max: 64)) }
    func assBackAlpha() -> String {
        let a = UInt8(clamp((1.0 - backgroundOpacity) * 255, min: 0, max: 255))
        return String(format: "%02X", a)
    }

    private func clamp<T: Comparable>(_ v: T, min lo: T, max hi: T) -> T {
        Swift.min(Swift.max(v, lo), hi)
    }
}
