import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ranked rows with a share bar. Rows are kept by position, so switching tabs
// or a new poll slides the bars to their new length.
ColumnLayout {
    id: list
    property var items: []
    spacing: 2

    Repeater {
        model: list.items.length
        Rectangle {
            id: row
            required property int index
            readonly property var item: list.items[index] || ({ name: "", total: 0, share: 0 })
            Layout.fillWidth: true
            implicitHeight: 46
            radius: Math.min(4, theme.radius)
            color: hover.hovered ? theme.surfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: hover }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        text: row.item.name
                        color: theme.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: row.item.requests !== undefined
                        text: qsTr("%n requests", "", row.item.requests || 0)
                        color: theme.faint
                        font.pixelSize: 11
                        opacity: hover.hovered ? 1 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    AnimatedNumber {
                        value: row.item.total
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: (row.item.share * 100).toLocaleString(Qt.locale(), 'f', row.item.share < 0.1 && row.item.share > 0 ? 1 : 0) + " %"
                        color: theme.muted
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 46
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: Math.min(2, theme.radius)
                    color: theme.grid
                    Rectangle {
                        width: parent.width * row.item.share
                        height: parent.height
                        radius: parent.radius
                        color: theme.accent
                        opacity: 1 - Math.min(0.5, row.index * 0.09)
                        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Label {
        visible: list.items.length === 0
        text: qsTr("Nothing in this period")
        color: theme.faint
        Layout.topMargin: 8
        Layout.leftMargin: 8
    }
}
