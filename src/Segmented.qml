import QtQuick
import QtQuick.Controls

// A row of choices with a highlight that slides to the picked one.
Rectangle {
    id: control
    property var labels: []
    property int currentIndex: 0
    signal activated(int index)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 32
    radius: Math.min(6, theme.radius)
    color: theme.background
    border.color: theme.border

    Rectangle {
        id: thumb
        readonly property Item target: repeater.count > control.currentIndex && control.currentIndex >= 0
                                        ? repeater.itemAt(control.currentIndex) : null
        visible: target !== null
        x: target ? row.x + target.x : 3
        y: 3
        width: target ? target.width : 0
        height: control.height - 6
        radius: Math.max(0, control.radius - 2)
        color: theme.accent
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        x: 3
        y: 3
        height: control.height - 6
        Repeater {
            id: repeater
            model: control.labels
            Item {
                required property string modelData
                required property int index
                readonly property bool selected: index === control.currentIndex
                width: label.implicitWidth + 26
                height: row.height
                Label {
                    id: label
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 13
                    font.weight: parent.selected ? Font.DemiBold : Font.Normal
                    color: parent.selected ? theme.accentForeground : hover.hovered ? theme.text : theme.muted
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: control.activated(parent.index) }
            }
        }
    }
}
