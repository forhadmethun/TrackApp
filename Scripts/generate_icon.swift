#!/usr/bin/env swift
/// Generates TrackApp's application icon as a 1024×1024 PNG.
/// Run: swift Scripts/generate_icon.swift
/// Then: make_icns.sh packages it into Resources/AppIcon.icns

import AppKit

let size: CGFloat = 1024
let half = size / 2

// ── Off-screen bitmap context ─────────────────────────────────────────────────
let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(bitmapImageRep: bmp)!
NSGraphicsContext.current = nsCtx
let ctx = nsCtx.cgContext
let cs  = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// ── Background: deep violet → navy gradient ───────────────────────────────────
let bgGrad = CGGradient(colorSpace: cs,
    colorComponents: [0.44, 0.16, 0.94, 1,
                      0.09, 0.03, 0.44, 1],
    locations: [0, 1], count: 2)!
ctx.drawLinearGradient(bgGrad,
    start: CGPoint(x: half, y: size), end: CGPoint(x: half, y: 0), options: [])

// ── Soft radial glow (purple halo behind the hourglass) ───────────────────────
let glowGrad = CGGradient(colorSpace: cs,
    colorComponents: [0.68, 0.38, 1.0, 0.38,
                      0.44, 0.16, 0.94, 0.0],
    locations: [0, 1], count: 2)!
ctx.drawRadialGradient(glowGrad,
    startCenter: CGPoint(x: half, y: half), startRadius: 0,
    endCenter:   CGPoint(x: half, y: half), endRadius: size * 0.54, options: [])

// ── Hourglass geometry ────────────────────────────────────────────────────────
let glassW: CGFloat = 264   // half-width of glass at the wide opening
let neckW:  CGFloat =  20   // half-width at the pinch
let topY:   CGFloat = 732   // y of the top opening (where top cap sits)
let botY:   CGFloat = 292   // y of the bottom (where bottom cap sits)
let neckTopY: CGFloat = half + 18   // bottom edge of top bulb
let neckBotY: CGFloat = half - 18   // top edge of bottom bulb
let capH:   CGFloat =  40   // cap half-height (total height = 80pt)
let capOvr: CGFloat =  28   // how much cap extends past the glass width
let capR:   CGFloat =  26   // cap corner radius

func topBulb() -> CGPath {
    let p = CGMutablePath()
    p.move(to:    CGPoint(x: half - glassW, y: topY))
    p.addLine(to: CGPoint(x: half + glassW, y: topY))
    p.addQuadCurve(to:      CGPoint(x: half + neckW, y: neckTopY),
                   control: CGPoint(x: half + glassW * 0.88, y: neckTopY + 90))
    p.addLine(to: CGPoint(x: half - neckW, y: neckTopY))
    p.addQuadCurve(to:      CGPoint(x: half - glassW, y: topY),
                   control: CGPoint(x: half - glassW * 0.88, y: neckTopY + 90))
    p.closeSubpath()
    return p
}

func botBulb() -> CGPath {
    let p = CGMutablePath()
    p.move(to:    CGPoint(x: half - glassW, y: botY))
    p.addLine(to: CGPoint(x: half + glassW, y: botY))
    p.addQuadCurve(to:      CGPoint(x: half + neckW, y: neckBotY),
                   control: CGPoint(x: half + glassW * 0.88, y: neckBotY - 90))
    p.addLine(to: CGPoint(x: half - neckW, y: neckBotY))
    p.addQuadCurve(to:      CGPoint(x: half - glassW, y: botY),
                   control: CGPoint(x: half - glassW * 0.88, y: neckBotY - 90))
    p.closeSubpath()
    return p
}

// ── Glass bodies (white, with purple glow shadow) ─────────────────────────────
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 52, color: rgb(0.68, 0.38, 1.0, 0.85))
ctx.setFillColor(rgb(1, 1, 1, 0.92))
ctx.addPath(topBulb()); ctx.fillPath()
ctx.addPath(botBulb()); ctx.fillPath()
ctx.restoreGState()

// ── Subtle inner-glass sheen (light gradient overlay on top bulb) ─────────────
ctx.saveGState()
ctx.addPath(topBulb()); ctx.clip()
let sheenGrad = CGGradient(colorSpace: cs,
    colorComponents: [1, 1, 1, 0.18,
                      1, 1, 1, 0.00],
    locations: [0, 1], count: 2)!
ctx.drawLinearGradient(sheenGrad,
    start: CGPoint(x: half - glassW * 0.3, y: topY),
    end:   CGPoint(x: half + glassW * 0.6, y: neckTopY + 60), options: [])
ctx.restoreGState()

// ── Sand fill in bottom bulb ──────────────────────────────────────────────────
ctx.saveGState()
ctx.addPath(botBulb()); ctx.clip()
let sandLevel: CGFloat = botY + 105   // how high the sand pile sits
let sandGrad = CGGradient(colorSpace: cs,
    colorComponents: [1.00, 0.82, 0.28, 0.96,   // golden top
                      1.00, 0.52, 0.10, 0.96],   // amber bottom
    locations: [0, 1], count: 2)!
ctx.drawLinearGradient(sandGrad,
    start: CGPoint(x: half, y: sandLevel),
    end:   CGPoint(x: half, y: botY + 5),
    options: [.drawsAfterEndLocation])
ctx.restoreGState()

// ── Caps (rounded bars at top and bottom) ─────────────────────────────────────
let capX = half - glassW - capOvr
let capTotalW = (glassW + capOvr) * 2

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 22, color: rgb(0.68, 0.38, 1.0, 0.55))
ctx.setFillColor(rgb(1, 1, 1, 0.97))
// Top cap
ctx.addPath(CGPath(roundedRect: CGRect(x: capX, y: topY, width: capTotalW, height: capH * 2),
                   cornerWidth: capR, cornerHeight: capR, transform: nil))
ctx.fillPath()
// Bottom cap
ctx.addPath(CGPath(roundedRect: CGRect(x: capX, y: botY - capH * 2, width: capTotalW, height: capH * 2),
                   cornerWidth: capR, cornerHeight: capR, transform: nil))
ctx.fillPath()
ctx.restoreGState()

// ── Falling sand beads (amber dots between neck and sand pile) ────────────────
for i in 0..<3 {
    let r: CGFloat = 13 - CGFloat(i) * 2
    let y: CGFloat = neckBotY - 22 - CGFloat(i) * 36
    let alpha = CGFloat(1.0 - Double(i) * 0.28)
    ctx.setFillColor(rgb(1.0, 0.78, 0.22, alpha))
    ctx.fillEllipse(in: CGRect(x: half - r, y: y - r, width: r * 2, height: r * 2))
}

// ── Neck connector (thin opaque bar bridging the gap between bulbs) ───────────
ctx.setFillColor(rgb(1, 1, 1, 0.92))
ctx.fill(CGRect(x: half - neckW, y: neckBotY, width: neckW * 2, height: neckTopY - neckBotY))

NSGraphicsContext.restoreGraphicsState()

// ── Write PNG ─────────────────────────────────────────────────────────────────
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon_1024.png"
let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("Saved \(outPath) (\(png.count / 1024) KB)")
