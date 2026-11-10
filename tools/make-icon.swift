// Draws the iOS app icon: the same mark as the Mac and Android apps —
// Material blue #2196F3 behind a light "Fr" — but full-bleed and opaque,
// since iOS cuts the corners itself and rejects an icon with transparency.
//
//   swiftc tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Freer/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import AppKit

let px = 1024
// An RGB bitmap with the alpha byte skipped: opaque by construction.
let context = CGContext(
    data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

let canvas = NSRect(x: 0, y: 0, width: px, height: px)
NSColor(srgbRed: 0x21 / 255.0, green: 0x96 / 255.0, blue: 0xF3 / 255.0, alpha: 1).setFill()
canvas.fill()

let font = NSFont.systemFont(ofSize: CGFloat(px) * 0.5, weight: .medium)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(srgbRed: 0xEC / 255.0, green: 0xEC / 255.0, blue: 0xEC / 255.0, alpha: 1)
]
let text = "Fr" as NSString
let size = text.size(withAttributes: attrs)
text.draw(
    at: NSPoint(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2 + font.descender / 2),
    withAttributes: attrs
)

NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil
)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(out)") }
