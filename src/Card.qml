import QtQuick

// Cards only tint the see-through window; a solid one sits over other
// content of the same window (the help overlay).
Rectangle {
    property bool solid: false
    color: solid ? theme.surface : Qt.alpha(theme.surface, 0.55)
    border.color: theme.border
    border.width: 1
    radius: theme.radius
    Behavior on color { ColorAnimation { duration: 200 } }
}
