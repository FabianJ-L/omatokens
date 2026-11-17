import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: overlay
    signal dismissed()
    color: "#cc000000"

    TapHandler { onTapped: overlay.dismissed() }

    Card {
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 48)
        implicitHeight: grid.implicitHeight + 72

        Label {
            id: heading
            x: 24
            y: 20
            text: qsTr("Keyboard shortcuts")
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Colors.text
        }
        GridLayout {
            id: grid
            x: 24
            anchors.top: heading.bottom
            anchors.topMargin: 14
            width: parent.width - 48
            columns: 2
            rowSpacing: 8
            columnSpacing: 20
            Repeater {
                model: [
                    "1 – 4", qsTr("Today, week, month, all time"),
                    "← →", qsTr("Previous or next period"),
                    "0", qsTr("Back to the current period"),
                    "A", qsTr("Switch agent"),
                    "C", qsTr("Show or hide cache reads"),
                    "Space", qsTr("Read the logs again"),
                    "?", qsTr("Show or hide this help"),
                    "Q", qsTr("Quit")
                ]
                delegate: Label {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index % 2 ? Colors.text : theme.accent
                    font.family: index % 2 ? "" : "monospace"
                    Layout.fillWidth: index % 2 === 1
                }
            }
        }
    }
}
