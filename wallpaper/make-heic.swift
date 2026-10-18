// Packs PNG frames named by hour (6.4.png = 06:24) into a macOS dynamic wallpaper that follows the clock.
// Usage: swift make-heic.swift out.heic <light hour> <dark hour> frames/*.png
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
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

let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.heic.identifier as CFString, frames.count, nil)!
for (n, (path, _)) in frames.enumerated() {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
  let opts = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
  CGImageDestinationAddImageAndMetadata(dest, CGImageSourceCreateImageAtIndex(src, 0, nil)!, n == 0 ? meta : nil, opts)
}
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out.path)") }

// Read it back so a silently dropped tag fails the build instead of the wallpaper.
let check = CGImageSourceCreateWithURL(out as CFURL, nil)!
precondition(CGImageSourceGetCount(check) == frames.count, "frame count mismatch")
precondition(CGImageSourceCopyMetadataAtIndex(check, 0, nil).flatMap {
  CGImageMetadataCopyStringValueWithPath($0, nil, "apple_desktop:h24" as CFString)
} != nil, "h24 tag missing")
print("\(out.lastPathComponent): \(frames.count) frames at", frames.map { $0.1 })
