import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: tile
    property string title
    property string hint
    property var stats: ({})
    property bool selected
    signal clicked()

    implicitHeight: 104
    radius: theme.radius
    color: hover.hovered ? Colors.cardHover : Colors.card
    border.width: selected ? 2 : 1
    border.color: selected ? theme.accent : Colors.line

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.clicked() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Label { text: tile.title; color: Colors.muted; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: tile.hint; color: Colors.faint; font.pixelSize: 11 }
        }
        Label {
            text: backend.compact(tile.stats.total || 0)
            font.pixelSize: 30
            font.weight: Font.DemiBold
            color: tile.selected ? theme.accent : Colors.text
        }
        Label {
            text: qsTr("%n requests", "", tile.stats.requests || 0) + " · " + qsTr("%1 out").arg(backend.compact(tile.stats.output || 0))
            color: Colors.muted
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
