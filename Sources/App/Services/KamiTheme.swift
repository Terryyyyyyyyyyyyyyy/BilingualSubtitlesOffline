import SwiftUI

/// Kami 设计语言 · 纸
/// 温暖画布 · 墨蓝点缀 · 衬线层级 · 排版节奏 · 编辑品质
///
/// 严格匹配 Kami tokens.json 色值：
/// parchment #F5F4ED · ivory #FAF9F5 · brand #1B365D · brand-tint #EEF2F7
enum KamiTheme {
    // MARK: - Colors
    static let canvas =       Color(hex: "#F5F4ED") // parchment
    static let surface =      Color(hex: "#FAF9F5") // ivory
    static let accent =       Color(hex: "#1B365D") // brand
    static let accentLight =  Color(hex: "#265899")
    static let brandTint =    Color(hex: "#EEF2F7") // brand-tint
    static let tagBg =        Color(hex: "#E4ECF5") // tag-bg
    static let textPrimary =  Color(hex: "#141413") // near-black
    static let textBody =     Color(hex: "#3D3D3A") // dark-warm
    static let textSecondary = Color(hex: "#6B6A64") // stone
    static let textMuted =    Color(hex: "#808080")
    static let border =       Color(hex: "#E8E6DC")
    static let borderLight =  Color(hex: "#E5E3D8")
    static let success =      Color(hex: "#4D8C4D")
    static let error =        Color(hex: "#AB3333")
    static let stepPending =  Color(hex: "#C8C5BE")
    static let stepActive = accent
    static let stepDone = success

    // MARK: - Typography
    static let titleFont: Font      = .custom("Charter", size: 28).weight(.bold)
    static let subtitleFont: Font   = .system(size: 13)
    static let headingFont: Font    = .system(size: 15).weight(.semibold)
    static let bodyFont: Font       = .system(size: 13)
    static let captionFont: Font    = .system(size: 12)
    static let smallFont: Font      = .system(size: 11)
    static let tinyFont: Font       = .system(size: 10)

    // MARK: - Layout
    static let cornerSm: CGFloat = 6
    static let cornerMd: CGFloat = 12
    static let cornerLg: CGFloat = 20
    static let paddingSm: CGFloat = 8
    static let paddingMd: CGFloat = 16
    static let paddingLg: CGFloat = 24
    static let spacingSm: CGFloat = 6
    static let spacingMd: CGFloat = 12
    static let spacingLg: CGFloat = 20
    static let spacingXl: CGFloat = 30
    static let spacingXxl: CGFloat = 40
}

// MARK: - View Extensions

extension View {
    /// 暖白画布背景
    func kamiCanvas() -> some View {
        self.background(KamiTheme.canvas)
    }

    /// Ivory 卡片容器（圆角 + 暖边框）
    func kamiCard() -> some View {
        self.padding(KamiTheme.paddingMd)
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

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let int = UInt64(hex, radix: 16) ?? 0
        self.init(
            .sRGB,
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue:  Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}
