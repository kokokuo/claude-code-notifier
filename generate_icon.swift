import Cocoa

let size: CGFloat = 1024
let cornerRadius: CGFloat = 180  // macOS style rounded corners
let clawdScale: CGFloat = 0.85   // 85% of canvas

// Load clawd image
let defaultClawdPath = NSString(string: "~/.claude/hooks/claude-code-notifier/assets/clawd-normal.png").expandingTildeInPath
let clawdPath = (CommandLine.argc > 2 ? CommandLine.arguments[2] : defaultClawdPath)
guard let clawdImage = NSImage(contentsOfFile: clawdPath) else {
    print("Failed to load clawd image")
    exit(1)
}

// Create canvas
let canvasRect = NSRect(x: 0, y: 0, width: size, height: size)
let canvas = NSImage(size: NSSize(width: size, height: size))

canvas.lockFocus()

// Draw white rounded rectangle background
let bgPath = NSBezierPath(roundedRect: canvasRect, xRadius: cornerRadius, yRadius: cornerRadius)
NSColor.white.setFill()
bgPath.fill()

// Optional: subtle border
NSColor(white: 0.85, alpha: 1.0).setStroke()
bgPath.lineWidth = 2
bgPath.stroke()

// Calculate clawd size maintaining aspect ratio
let clawdOrigW = clawdImage.size.width
let clawdOrigH = clawdImage.size.height
let targetW = size * clawdScale
let scale = targetW / clawdOrigW
let targetH = clawdOrigH * scale

let x = (size - targetW) / 2
let y = (size - targetH) / 2

// Draw clawd centered
clawdImage.draw(in: NSRect(x: x, y: y, width: targetW, height: targetH),
                from: NSRect(origin: .zero, size: clawdImage.size),
                operation: .sourceOver,
                fraction: 1.0)

canvas.unlockFocus()

// Save as PNG
guard let tiffData = canvas.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG")
    exit(1)
}

let outputPath = (CommandLine.argc > 1 ? CommandLine.arguments[1] : "./clawd-\(Int(size)).png")
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Icon generated: \(Int(targetW))x\(Int(targetH)) clawd on \(Int(size))x\(Int(size)) canvas")
