import AppKit

/// Stores a colour in `UserDefaults` as `#RRGGBB` in sRGB, which survives export and import (M3).
enum HexColor {
    static func string(from color: NSColor) -> String? {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        let components = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
            .map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return "#" + components.map { String(format: "%02X", $0) }.joined()
    }

    static func color(from string: String) -> NSColor? {
        let hex = string.hasPrefix("#") ? string.dropFirst() : Substring(string)
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
