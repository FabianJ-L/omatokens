import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Card {
    id: card
    property string title
    property var items: []
    property bool showRequests: true

    implicitHeight: column.implicitHeight + 32

    ColumnLayout {
        id: column
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        Label { text: card.title; color: Colors.muted; font.pixelSize: 13 }

        Repeater {
            model: card.items
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: modelData.name
                        color: Colors.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: card.showRequests && modelData.requests !== undefined
                        text: qsTr("%n requests", "", modelData.requests || 0)
                        color: Colors.faint
                        font.pixelSize: 12
                    }
                    Label { text: backend.compact(modelData.total); color: Colors.text; font.weight: Font.DemiBold }
                    Label {
                        text: (modelData.share * 100).toLocaleString(Qt.locale(), 'f', 0) + " %"
                        color: Colors.muted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 40
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: Math.min(2, theme.radius)
                    color: Colors.grid
                    Rectangle {
                        width: parent.width * modelData.share
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                    }
                }
            }
        }

        Label {
            visible: !card.items || card.items.length === 0
            text: qsTr("Nothing in this period")
            color: Colors.faint
        }
    }
}
