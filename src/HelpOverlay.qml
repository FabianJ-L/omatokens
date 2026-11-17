import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: overlay
    property bool shown: false
    signal dismissed()

    color: Qt.rgba(0, 0, 0, 0.55)
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 160 } }

    TapHandler { onTapped: overlay.dismissed() }

    Card {
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 48)
        implicitHeight: column.implicitHeight + 48
        scale: overlay.shown ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: column
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            Label {
                text: qsTr("Keyboard shortcuts")
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: theme.text
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 18
                Repeater {
                    model: [
                        "1 – 4", qsTr("Today, week, month, all time"),
                        "← →", qsTr("Previous or next period"),
                        "0", qsTr("Back to the current period"),
                        "A", qsTr("Switch agent"),
                        "B", qsTr("Switch breakdown"),
                        "C", qsTr("Show or hide cache reads"),
                        "Space", qsTr("Read the logs again"),
                        "?", qsTr("Show or hide this help"),
                        "Q", qsTr("Quit")
                    ]
                    delegate: Item {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: index % 2 === 1
                        implicitWidth: index % 2 ? text.implicitWidth : keyCap.implicitWidth
                        implicitHeight: 24
                        Rectangle {
                            id: keyCap
                            visible: index % 2 === 0
                            implicitWidth: Math.max(28, keyLabel.implicitWidth + 14)
                            height: 24
                            radius: Math.min(4, theme.radius)
                            color: theme.background
                            border.color: theme.border
                            Label { id: keyLabel; anchors.centerIn: parent; text: modelData; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                        Label {
                            id: text
                            visible: index % 2 === 1
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: theme.text
                        }
                    }
                }
            }
        }
    }
}
