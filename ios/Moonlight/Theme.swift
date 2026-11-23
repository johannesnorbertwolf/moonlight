// Night theme (same colors as web/styles.css) and the moon icons per bucket (web/moon.js).

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
    static let bg = Color(hex: 0x1d1947)
    static let surface = Color(hex: 0x2b2566)
    static let surface2 = Color(hex: 0x3c3489)
    static let text1 = Color(hex: 0xeeedfe)
    static let text2 = Color(hex: 0xafa9ec)
    static let moon = Color(hex: 0xfac775)
    static let moonDark = Color(hex: 0x534ab7)
    static let accent = Color(hex: 0x5dcaa5)
}

struct MoonView: View {
    let bucket: Bucket
    var size: CGFloat = 24

    /// How far the shadow circle is shifted, as a share of the size (web/moon.js).
    private var shadowOffset: CGFloat? {
        switch bucket {
        case .light: 0.75
        case .medium: 0.45
        case .heavy: 0.22
        default: nil
        }
    }

    var body: some View {
        let r = size - 2
        ZStack {
            switch bucket {
            case .free:
                Circle().fill(Color.moon).frame(width: r, height: r)
            case .light, .medium, .heavy:
                let dx = (shadowOffset ?? 0) * size
                ZStack {
                    Circle().fill(Color.moon).frame(width: r, height: r)
                    Circle().fill(.black).frame(width: r, height: r)
                        .offset(x: dx, y: -dx * 0.25)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            case .very_heavy:
                Circle().fill(Color.moonDark).frame(width: r, height: r)
            case .missing:
                Circle().stroke(Color.text2, lineWidth: 1).frame(width: r, height: r)
                Text("?").font(.system(size: size * 0.5)).foregroundStyle(Color.text2)
            case .future:
                Circle().stroke(Color.moonDark, style: StrokeStyle(lineWidth: 1, dash: [2, 2])).frame(width: r, height: r)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(bucket == .future ? t("history.future") : t("bucket.\(bucket.rawValue)"))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.moon.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Color.bg)
    }
}

extension View {
    func screen() -> some View {
        self.foregroundStyle(Color.text1)
            .scrollContentBackground(.hidden)
            .background(Color.bg.ignoresSafeArea())
    }
}

enum Fmt {
    static func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = L10n.lang.locale
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: d)
    }
    static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = L10n.lang.locale
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: d)
    }
    static func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
    static func nights(_ n: Int) -> String { n == 1 ? t("today.night1") : t("today.nights", ["n": n]) }
    static func minutes(_ m: Double) -> String {
        m == m.rounded() ? String(Int(m)) : String(format: "%.1f", m)
    }
}
