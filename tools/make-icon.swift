// Draws the iOS app icon from the mark every Freer app uses — AppIcon.svg in
// the Mac repo's tools/package — full-bleed and opaque, since iOS cuts the
// corners itself and rejects an icon with transparency.
//
//   swiftc tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Freer/Assets.xcassets/AppIcon.appiconset/AppIcon.png [AppIcon.svg]

import AppKit

let svg = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "../../MacApp/FreerForMac/tools/package/AppIcon.svg"
guard let mark = NSImage(contentsOf: URL(fileURLWithPath: svg)) else {
    fatalError("could not read \(svg)")
}

let px = 1024
// An RGB bitmap with the alpha byte skipped: opaque by construction.
let context = CGContext(
    data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
mark.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil
)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(out)") }
