.pragma library

// The four token types share one hue, so the chart reads as one thing:
// output in the full accent, input and cache writes fading out, and cache
// reads (usually the bulk) in a quiet neutral.
function tint(color, alpha) {
    const c = Qt.color(color)
    return Qt.rgba(c.r, c.g, c.b, alpha)
}

function colors(accent, text) {
    return {
        output: Qt.color(accent),
        input: tint(accent, 0.6),
        cacheWrite: tint(accent, 0.3),
        cacheRead: tint(text, 0.17)
    }
}

// Rounds an axis maximum up to a number people read at a glance.
function niceCeiling(value) {
    if (value <= 0)
        return 1
    const magnitude = Math.pow(10, Math.floor(Math.log10(value)))
    for (const step of [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10])
        if (step * magnitude >= value)
            return step * magnitude
    return 10 * magnitude
}
