pragma Singleton
import QtQuick

// The neutral colors every card shares, plus the four token-type shades,
// derived from the Omarchy accent so they follow a theme switch.
QtObject {
    readonly property color window: "#0e0e10"
    readonly property color card: "#16161a"
    readonly property color cardHover: "#1c1c21"
    readonly property color line: "#26262c"
    readonly property color grid: "#222228"
    readonly property color text: "#ececef"
    readonly property color muted: "#8b8b93"
    readonly property color faint: "#5d5d66"
    readonly property color cacheRead: "#45454d"

    function tint(accent, alpha) {
        const c = Qt.color(accent)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }
    function output(accent) { return Qt.color(accent) }
    function input(accent) { return tint(accent, 0.62) }
    function cacheWrite(accent) { return tint(accent, 0.32) }
}
