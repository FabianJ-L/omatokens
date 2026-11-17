import QtQuick
import QtQuick.Controls

Rectangle {
    id: chip
    property string text
    property bool selected
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: Math.min(4, theme.radius)
    color: selected ? theme.accent : hover.hovered ? Colors.cardHover : Colors.card
    border.color: selected ? theme.accent : Colors.line

    Label {
        id: label
        anchors.centerIn: parent
        text: chip.text
        font.pixelSize: 13
        color: chip.selected ? theme.accentForeground : Colors.text
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: chip.clicked() }
}
