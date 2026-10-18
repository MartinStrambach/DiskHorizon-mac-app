// Writes App/DiskHorizon/Assets.xcassets/AppIcon.appiconset: the section's sunburst rising over a
// horizon at dusk, at every size macOS asks for; and AppIconDebug.appiconset, the same icon with
// a red "DEBUG" ribbon across its top-right corner, which the Debug configuration uses.
//
//   swift scripts/make-icon.swift
//
// Rerun it after changing the drawing below.

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appending(path: "App/DiskHorizon/Assets.xcassets")

/// The 1024 pt master, on macOS's icon grid: an 824 pt rounded square centred in the canvas,
/// leaving room for the shadow the system draws. Drawn top-down (y grows downwards). `debug` adds
/// the Debug configuration's ribbon.
func master(debug: Bool) -> NSImage {
	let size = NSSize(width: 1024, height: 1024)
	return NSImage(size: size, flipped: true) { _ in
		let context = NSGraphicsContext.current!.cgContext
		let body = CGRect(x: 100, y: 100, width: 824, height: 824)
		let square = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

		context.saveGState()
		context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
		context.addPath(square)
		context.setFillColor(NSColor.black.cgColor)
		context.fillPath()
		context.restoreGState()

		context.saveGState()
		context.addPath(square)
		context.clip()
		drawScene(in: context, body: body)
		context.restoreGState()
		if debug {
			drawDebugRibbon(in: context, clippedTo: square, body: body)
		}
		return true
	}
}

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
	NSColor(
		srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
	).cgColor
}

/// Where the sun meets the ground, and the sunburst's centre.
let horizon: CGFloat = 610
let centre = CGPoint(x: 512, y: horizon)

/// One ring of the sunburst: its radii, and the share of the half circle each segment takes,
/// left to right. Thin outer rings with gaps, like a folder's deeper levels.
struct Ring {
	let inner: CGFloat
	let outer: CGFloat
	let segments: [CGFloat]
}

let rings = [
	Ring(inner: 132, outer: 212, segments: [0.34, 0.22, 0.26, 0.18]),
	Ring(inner: 222, outer: 286, segments: [0.2, 0.1, 0.04, 0.12, 0.1, 0.16, 0.1, 0.08, 0.1]),
	Ring(inner: 296, outer: 340, segments: [0.12, 0.06, -0.02, 0.06, 0.04, -0.06, 0.1, 0.06, 0.08, -0.04, 0.1, 0.06, -0.08, 0.06]),
]

/// The segment's colour from its midpoint along the arc, 0 at the left end and 1 at the right:
/// violet through blue and green to amber, as the app's chart shades neighbours into each other.
func segmentColor(at position: CGFloat, ring: Int) -> CGColor {
	let hue = 0.76 - 0.66 * position
	let brightness = 1 - CGFloat(ring) * 0.08
	let saturation = 0.72 - CGFloat(ring) * 0.1
	return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1).cgColor
}

func drawScene(in context: CGContext, body: CGRect) {
	// Dusk: night at the top, a warm glow where the sun comes up.
	let sky = CGGradient(
		colorsSpace: nil,
		colors: [rgb(0x0B0E2C), rgb(0x24195A), rgb(0x6A2C78), rgb(0xE9795A)] as CFArray,
		locations: [0, 0.42, 0.78, 1]
	)!
	context.drawLinearGradient(sky, start: CGPoint(x: 512, y: body.minY), end: CGPoint(x: 512, y: horizon), options: [])

	// A few stars in the dark part of the sky.
	for (x, y, r) in [(210.0, 210.0, 4.0), (300, 160, 2.5), (780, 190, 3.5), (850, 290, 2.5), (176, 330, 2.5), (690, 140, 2.5)] {
		context.setFillColor(rgb(0xFFFFFF, alpha: 0.75))
		context.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
	}

	// The sun's glow behind the rings.
	let glow = CGGradient(
		colorsSpace: nil,
		colors: [rgb(0xFFD58A, alpha: 0.55), rgb(0xFF9A5C, alpha: 0)] as CFArray,
		locations: [0, 1]
	)!
	context.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 440, options: [])

	context.saveGState()
	context.clip(to: CGRect(x: body.minX, y: body.minY, width: body.width, height: horizon - body.minY))
	drawSunburst(in: context)
	context.restoreGState()

	// The ground, with the sunburst's reflection fading into it.
	let groundRect = CGRect(x: body.minX, y: horizon, width: body.width, height: body.maxY - horizon)
	let ground = CGGradient(colorsSpace: nil, colors: [rgb(0x2A1745), rgb(0x0A0A1E)] as CFArray, locations: [0, 1])!
	context.saveGState()
	context.clip(to: groundRect)
	context.drawLinearGradient(ground, start: CGPoint(x: 512, y: horizon), end: CGPoint(x: 512, y: body.maxY), options: [])
	context.saveGState()
	context.setAlpha(0.22)
	// Mirrored in the horizon and squashed, as on still water.
	context.translateBy(x: 0, y: horizon)
	context.scaleBy(x: 1, y: -0.55)
	context.translateBy(x: 0, y: -horizon)
	drawSunburst(in: context)
	context.restoreGState()
	let fade = CGGradient(colorsSpace: nil, colors: [rgb(0x0A0A1E, alpha: 0), rgb(0x0A0A1E, alpha: 1)] as CFArray, locations: [0, 1])!
	context.drawLinearGradient(fade, start: CGPoint(x: 512, y: horizon), end: CGPoint(x: 512, y: horizon + 220), options: [.drawsAfterEndLocation])
	context.restoreGState()

	// The horizon itself: a thin line of light.
	let line = CGGradient(
		colorsSpace: nil,
		colors: [rgb(0xFFE2B0, alpha: 0), rgb(0xFFE2B0, alpha: 0.95), rgb(0xFFE2B0, alpha: 0)] as CFArray,
		locations: [0, 0.5, 1]
	)!
	context.saveGState()
	context.clip(to: CGRect(x: body.minX, y: horizon - 3, width: body.width, height: 6))
	context.drawLinearGradient(line, start: CGPoint(x: body.minX, y: horizon), end: CGPoint(x: body.maxX, y: horizon), options: [])
	context.restoreGState()
}

/// The half of the chart above the horizon: a glowing centre and three rings of segments.
func drawSunburst(in context: CGContext) {
	let gap: CGFloat = 0.012
	for (index, ring) in rings.enumerated() {
		var start: CGFloat = 0
		for share in ring.segments {
			let width = abs(share)
			defer { start += width }
			// A negative share is space the ring leaves empty, as a folder's children too thin to draw.
			guard share > 0 else { continue }
			let from = CGFloat.pi * (1 + start + gap / 2), to = CGFloat.pi * (1 + start + width - gap / 2)
			let segment = CGMutablePath()
			segment.addArc(center: centre, radius: ring.outer, startAngle: from, endAngle: to, clockwise: false)
			segment.addArc(center: centre, radius: ring.inner, startAngle: to, endAngle: from, clockwise: true)
			segment.closeSubpath()
			context.addPath(segment)
			context.setFillColor(segmentColor(at: start + width / 2, ring: index))
			context.fillPath()
		}
	}

	let core = CGGradient(colorsSpace: nil, colors: [rgb(0xFFF6DC), rgb(0xFFC56B), rgb(0xFF8A4C)] as CFArray, locations: [0, 0.6, 1])!
	context.saveGState()
	context.addPath(CGPath(ellipseIn: CGRect(x: centre.x - 120, y: centre.y - 120, width: 240, height: 240), transform: nil))
	context.clip()
	context.drawRadialGradient(core, startCenter: CGPoint(x: centre.x, y: centre.y - 30), startRadius: 0, endCenter: centre, endRadius: 120, options: [.drawsAfterEndLocation])
	context.restoreGState()
}

/// A red band reading "DEBUG" across the body's top-right corner, so a debug build is told apart
/// from the release app in the Dock and the app switcher. Its ends run off the rounded square.
func drawDebugRibbon(in context: CGContext, clippedTo square: CGPath, body: CGRect) {
	// The band's centre line runs from `offset` left of the corner to `offset` below it.
	let offset = body.width * 0.36, thickness = body.width * 0.12
	let length = offset * 2.squareRoot() + thickness * 2
	let strip = CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness)
	let edge = thickness / 14

	context.saveGState()
	context.addPath(square)
	context.clip()
	context.translateBy(x: body.maxX - offset / 2, y: body.minY + offset / 2)
	context.rotate(by: .pi / 4)
	context.saveGState()
	context.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: NSColor.black.withAlphaComponent(0.35).cgColor)
	context.setFillColor(rgb(0xD62828))
	context.fill(strip)
	context.restoreGState()
	context.setFillColor(NSColor.white.withAlphaComponent(0.43).cgColor)
	context.fill(CGRect(x: strip.minX, y: strip.minY, width: length, height: edge))
	context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
	context.fill(CGRect(x: strip.minX, y: strip.maxY - edge, width: length, height: edge))

	let text = NSAttributedString(string: "DEBUG", attributes: [
		.font: NSFont.systemFont(ofSize: thickness * 0.62, weight: .heavy),
		.foregroundColor: NSColor.white,
	])
	let size = text.size()
	text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
	context.restoreGState()
}

func png(_ image: NSImage, pixels: Int) -> Data {
	let rep = NSBitmapImageRep(
		bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
		samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
		bytesPerRow: 0, bitsPerPixel: 0
	)!
	rep.size = NSSize(width: pixels, height: pixels)
	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
	image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
	NSGraphicsContext.restoreGraphicsState()
	return rep.representation(using: .png, properties: [:])!
}

/// Writes `<name>.appiconset` into the asset catalog: `image` at every size macOS asks for.
func writeIconSet(named name: String, image: NSImage) throws {
	let iconSet = assets.appending(path: "\(name).appiconset")
	try? FileManager.default.removeItem(at: iconSet)
	try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

	var entries: [String] = []
	for points in [16, 32, 128, 256, 512] {
		for scale in [1, 2] {
			let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
			try png(image, pixels: points * scale).write(to: iconSet.appending(path: name))
			entries.append("""
			    { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
			""")
		}
	}
	let contents = """
	{
	  "images" : [
	\(entries.joined(separator: ",\n"))
	  ],
	  "info" : { "author" : "xcode", "version" : 1 }
	}

	"""
	try contents.write(to: iconSet.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
	print("Wrote \(iconSet.path)")
}

try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try """
{
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(to: assets.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
try writeIconSet(named: "AppIcon", image: master(debug: false))
try writeIconSet(named: "AppIconDebug", image: master(debug: true))
