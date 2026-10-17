import AppKit
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func c(_ h: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(red: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a) }
NSGradient(colors: [c(0x2B1B63), c(0x0A0D2B), c(0x050714)], atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!.draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: -80)
// Milky way glow
NSGraphicsContext.saveGraphicsState()
let glow = NSBezierPath(); glow.move(to: NSPoint(x: -50, y: 250)); glow.curve(to: NSPoint(x: 1100, y: 800), controlPoint1: NSPoint(x: 350, y: 300), controlPoint2: NSPoint(x: 650, y: 700))
glow.lineWidth = 260; c(0x8FA8FF, 0.16).setStroke()
let sh = NSShadow(); sh.shadowColor = c(0x8FA8FF, 0.5); sh.shadowBlurRadius = 120; sh.shadowOffset = .zero; sh.set()
glow.stroke()
NSGraphicsContext.restoreGraphicsState()
// Stars
var seed: UInt64 = 42
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF) }
for _ in 0..<70 {
    let x = rnd() * S, y = rnd() * S, r = 2 + rnd() * 5
    c(0xFFFFFF, 0.35 + rnd() * 0.6).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)).fill()
}
// Crescent moon with glow
NSGraphicsContext.saveGraphicsState()
let sh2 = NSShadow(); sh2.shadowColor = c(0xBFD0FF, 0.9); sh2.shadowBlurRadius = 60; sh2.shadowOffset = .zero; sh2.set()
let m = NSRect(x: 250, y: 250, width: 520, height: 520)
let cut = CGRect(x: m.minX + 150, y: m.minY + 70, width: 470, height: 470)
let crescent = CGPath(ellipseIn: m, transform: nil).subtracting(CGPath(ellipseIn: cut, transform: nil))
let g = NSGraphicsContext.current!.cgContext
g.addPath(crescent); g.setFillColor(c(0xF4F1E6).cgColor); g.fillPath()
NSGraphicsContext.restoreGraphicsState()
// Bright star
func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let p = NSBezierPath()
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        let rr = i % 2 == 0 ? r : r * 0.22
        let pt = NSPoint(x: cx + rr * cos(a), y: cy + rr * sin(a))
        if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
    }
    p.close()
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow(); s.shadowColor = c(0xFFD98A, 0.9); s.shadowBlurRadius = 30; s.shadowOffset = .zero; s.set()
    c(0xFFE9A8).setFill(); p.fill()
    NSGraphicsContext.restoreGraphicsState()
}
star(720, 700, 100)
star(300, 830, 44)
NSGraphicsContext.restoreGraphicsState()
let cg = rep.cgImage!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
