import QtQuick

Rectangle {
    color: theme.surface
    border.color: theme.border
    border.width: 1
    radius: theme.radius
    Behavior on color { ColorAnimation { duration: 200 } }
}
