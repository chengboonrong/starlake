// Packs art-size PNG frames named by hour (6.4.png = 06:24) into a 6016x3384 macOS dynamic wallpaper that
// follows the clock.
// Usage: swift make-heic.swift out.heic <light hour> <dark hour> frames/*.png
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count > 4 else { fatalError("usage: swift make-heic.swift out.heic <light hour> <dark hour> frames/*.png") }
let out = URL(fileURLWithPath: args[1])
let light = Double(args[2])!, dark = Double(args[3])!
let frames = args.dropFirst(4)
  .map { ($0, Double(URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent)!) }
  .sorted { $0.1 < $1.1 }

// apple_desktop:h24 is a base64 binary plist: "ti" maps a time of day (fraction of 24 h, local clock) to an
// image index, "ap" picks the images macOS uses for the plain Light and Dark wallpaper choices.
let info: [String: Any] = [
  "ti": frames.enumerated().map { ["i": $0.offset, "t": $0.element.1 / 24] as [String: Any] },
  "ap": ["l": frames.firstIndex { $0.1 == light }!, "d": frames.firstIndex { $0.1 == dark }!],
]
let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
let ns = "http://ns.apple.com/namespace/1.0/" as CFString
let meta = CGImageMetadataCreateMutable()
CGImageMetadataRegisterNamespaceForPrefix(meta, ns, "apple_desktop" as CFString, nil)
let tag = CGImageMetadataTagCreate(ns, "apple_desktop" as CFString, "h24" as CFString, .string, plist.base64EncodedString() as CFString)!
CGImageMetadataSetTagWithPath(meta, nil, "apple_desktop:h24" as CFString, tag)

// Enlarge by a whole number with no smoothing so every art pixel stays a crisp square, keep the top-left
// corner and crop to 6016x3384, the largest Mac display.
func enlarge(_ img: CGImage) -> CGImage {
  let w = 6016, h = 3384, k = max((w + img.width - 1) / img.width, (h + img.height - 1) / img.height)
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.interpolationQuality = .none
  ctx.draw(img, in: CGRect(x: 0, y: h - img.height * k, width: img.width * k, height: img.height * k))
  return ctx.makeImage()!
}

let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.heic.identifier as CFString, frames.count, nil)!
for (n, (path, _)) in frames.enumerated() {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
  let opts = [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary // 1.0 keeps pixel-art edges exact
  CGImageDestinationAddImageAndMetadata(dest, enlarge(CGImageSourceCreateImageAtIndex(src, 0, nil)!), n == 0 ? meta : nil, opts)
}
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out.path)") }

// Read it back so a silently dropped tag fails the build instead of the wallpaper.
let check = CGImageSourceCreateWithURL(out as CFURL, nil)!
precondition(CGImageSourceGetCount(check) == frames.count, "frame count mismatch")
precondition(CGImageSourceCopyMetadataAtIndex(check, 0, nil).flatMap {
  CGImageMetadataCopyStringValueWithPath($0, nil, "apple_desktop:h24" as CFString)
} != nil, "h24 tag missing")
print("\(out.lastPathComponent): \(frames.count) frames at", frames.map { $0.1 })
