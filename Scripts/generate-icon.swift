#!/usr/bin/env swift
import AppKit

// 앱 아이콘용 오리발 픽셀아트 (다리를 길게 확장)
// 7 wide × 8 tall per foot, 두 발: 18 wide × 8 tall
let footShape: [(Int, Int)] = [
    // 다리 (rows 0-3)
    (3, 0), (3, 1), (3, 2), (3, 3),
    // 발목 (row 4)
    (2, 4), (3, 4), (4, 4),
    // 발등 (row 5)
    (1, 5), (2, 5), (3, 5), (4, 5), (5, 5),
    // 물갈퀴 (row 6)
    (0, 6), (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6),
    // 발가락 3개 (row 7)
    (0, 7), (3, 7), (6, 7),
]

let designW = 18
let designH = 8

func generateIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .none

    let s = CGFloat(size)

    // 배경: 둥근 사각형 (macOS 아이콘 스타일)
    let cornerRadius = s * 0.22
    let bgPath = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
        xRadius: cornerRadius, yRadius: cornerRadius
    )
    NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0).setFill()
    bgPath.fill()

    // 픽셀 크기 계산 (큰 아이콘은 정수로 스냅하여 선명하게)
    let pixelSize: CGFloat
    if s >= 64 {
        pixelSize = floor(s * 0.75 / CGFloat(designW))
    } else {
        pixelSize = s * 0.75 / CGFloat(designW)
    }

    let totalW = pixelSize * CGFloat(designW)
    let totalH = pixelSize * CGFloat(designH)
    let offsetX = (s - totalW) / 2
    let offsetY = (s - totalH) / 2

    // 오리발 색상: 따뜻한 오렌지
    NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0).setFill()

    for (dx, dy) in footShape {
        // 왼발 (x 기준점 = 0)
        let lx = offsetX + CGFloat(dx) * pixelSize
        let ly = s - offsetY - CGFloat(dy + 1) * pixelSize
        NSRect(x: lx, y: ly, width: pixelSize, height: pixelSize).fill()

        // 오른발 (x 기준점 = 11)
        let rx = offsetX + CGFloat(11 + dx) * pixelSize
        NSRect(x: rx, y: ly, width: pixelSize, height: pixelSize).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconset 디렉토리 생성
let basePath = "/Volumes/M.2 SSD 1/Projects/claudestatus/Resources"
let iconsetPath = "\(basePath)/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, size) in sizes {
    let data = generateIcon(size: size)
    try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    print("  \(name).png (\(size)x\(size))")
}

print("iconset 생성 완료")
