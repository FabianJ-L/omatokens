import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One of the four totals at the top; it also picks the period below, and
// shows that period's shape as a small bar trend.
Rectangle {
    id: tile
    property string title
    property string hint
    property var stats: ({})
    property bool selected
    signal clicked()

    readonly property color accent: theme.accent
    readonly property var series: stats.series || []
    readonly property real seriesMax: {
        let m = 0
        for (const v of series)
            m = Math.max(m, v)
        return m
    }

    implicitHeight: 128
    radius: theme.radius
    color: selected ? Qt.tint(theme.surface, Qt.rgba(accent.r, accent.g, accent.b, 0.07))
                    : hover.hovered ? theme.surfaceHover : theme.surface
    border.width: 1
    border.color: selected ? theme.accent : theme.border
    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.clicked() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: 14
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: tile.title
                color: tile.selected ? theme.text : theme.muted
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                implicitWidth: 18
                implicitHeight: 18
                radius: Math.min(4, theme.radius)
                color: "transparent"
                border.color: theme.border
                Label { anchors.centerIn: parent; text: tile.hint; color: theme.faint; font.pixelSize: 10 }
            }
        }
        RowLayout {
            spacing: 10
            AnimatedNumber {
                value: tile.stats.total || 0
                font.pixelSize: 28
                font.weight: Font.DemiBold
                color: tile.selected ? theme.accent : theme.text
            }
            DeltaPill {
                current: tile.stats.total || 0
                previous: tile.stats.previousTotal === undefined ? -1 : tile.stats.previousTotal
            }
        }
        Item { Layout.fillHeight: true }

        // The trend: future buckets (-1) stay as faint stubs.
        Row {
            id: spark
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: tile.series.length > 40 ? 1 : 2
            readonly property real barWidth: tile.series.length
                                             ? (width - spacing * (tile.series.length - 1)) / tile.series.length : 0
            Repeater {
                model: tile.series.length
                Item {
                    required property int index
                    readonly property real v: tile.series[index] === undefined ? 0 : tile.series[index]
                    width: spark.barWidth
                    height: spark.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.v < 0 ? 2 : Math.max(2, tile.seriesMax > 0 ? parent.v / tile.seriesMax * parent.height : 0)
                        radius: Math.min(1, theme.radius)
                        color: parent.v > 0 ? (tile.selected ? theme.accent : theme.faint) : theme.border
                        opacity: parent.v < 0 ? 0.5 : 1
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                }
            }
        }
    }
}
