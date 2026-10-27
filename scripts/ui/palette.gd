class_name Palette
extends RefCounted
## sRGB design tokens (spec §8). Contrast pairs are checked in
## tests/unit/test_palette_contrast.gd.

const BACKGROUND := Color("#FAF9F6")
const CARD := Color("#F0EFEB")
const INK := Color("#25282B")
const SECONDARY := Color("#62686D")
const ACCENT := Color("#47677C")
const GRID := Color("#D9D8D2")
const FOCUS := Color("#244A63")
const ERROR := Color("#8A4E48")
const ON_ACCENT := Color("#FFFFFF")
const SCRIM := Color(0.145, 0.157, 0.169, 0.45)

## Base unit for spacing (px at the 720x1280 reference viewport).
const SPACE := 8
## Minimum touch target: 48 dp. The reference viewport is 720 px wide, about
## 2x a 360 dp phone, so 48 dp maps to 96 px; we use 96 as the floor.
const TOUCH_MIN := 96


## WCAG 2.x relative luminance and contrast ratio.
static func luminance(c: Color) -> float:
	var ch := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
