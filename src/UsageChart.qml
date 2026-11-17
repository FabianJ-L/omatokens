import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Stacked bars of the selected period: cache reads at the bottom (usually the
// bulk), then cache writes, input, and output on top in the full accent.
Item {
    id: chart
    readonly property var buckets: backend.buckets
    property bool showCacheRead: true
    function shown(b) { return showCacheRead ? b.total : b.total - b.cacheRead }
    readonly property real maxValue: {
        let m = 0
        for (const b of buckets)
            m = Math.max(m, shown(b))
        return m
    }
    property int hovered: -1
    readonly property int axisWidth: 60
    readonly property int labelHeight: 22
    readonly property real slot: buckets.length ? plot.width / buckets.length : 0
    // Skip axis labels when they would collide.
    readonly property int labelStride: Math.max(1, Math.ceil(buckets.length * 38 / Math.max(1, plot.width)))

    Item {
        id: plot
        x: chart.axisWidth
        y: 8
        width: chart.width - chart.axisWidth
        height: chart.height - chart.labelHeight - 8
    }

    Repeater {
        model: 5
        Item {
            required property int index
            y: plot.y + plot.height * index / 4
            width: chart.width
            Rectangle { x: chart.axisWidth; width: plot.width; height: 1; color: Colors.grid }
            Label {
                width: chart.axisWidth - 10
                y: -height / 2
                horizontalAlignment: Text.AlignRight
                text: chart.maxValue > 0 ? backend.compact(chart.maxValue * (1 - index / 4)) : (index === 4 ? "0" : "")
                color: Colors.faint
                font.pixelSize: 11
            }
        }
    }

    Repeater {
        model: chart.buckets
        Item {
            id: slotItem
            required property var modelData
            required property int index
            readonly property real barWidth: Math.max(2, Math.min(36, chart.slot * 0.7))
            function seg(value) { return chart.maxValue > 0 ? value / chart.maxValue * plot.height : 0 }

            x: plot.x + index * chart.slot
            y: plot.y
            width: chart.slot
            height: plot.height

            Rectangle {
                anchors.fill: parent
                color: chart.hovered === slotItem.index ? "#0fffffff" : "transparent"
                radius: Math.min(4, theme.radius)
            }
            Column {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: slotItem.barWidth
                opacity: chart.hovered === -1 || chart.hovered === slotItem.index ? 1 : 0.55
                Rectangle { width: parent.width; height: slotItem.seg(modelData.output); color: Colors.output(theme.accent) }
                Rectangle { width: parent.width; height: slotItem.seg(modelData.input); color: Colors.input(theme.accent) }
                Rectangle { width: parent.width; height: slotItem.seg(modelData.cacheWrite); color: Colors.cacheWrite(theme.accent) }
                Rectangle { width: parent.width; height: chart.showCacheRead ? slotItem.seg(modelData.cacheRead) : 0; color: Colors.cacheRead }
            }
            Label {
                visible: slotItem.index % chart.labelStride === 0
                anchors.top: parent.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                font.pixelSize: 11
                font.weight: modelData.current ? Font.DemiBold : Font.Normal
                color: modelData.current ? theme.accent : Colors.muted
            }
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        chart.hovered = slotItem.index
                    else if (chart.hovered === slotItem.index)
                        chart.hovered = -1
                }
            }
        }
    }

    // Details for the bar under the pointer, placed beside it.
    Rectangle {
        id: tip
        readonly property var b: chart.hovered >= 0 && chart.hovered < chart.buckets.length ? chart.buckets[chart.hovered] : null
        visible: b !== null
        width: tipColumn.implicitWidth + 24
        height: tipColumn.implicitHeight + 20
        color: "#242429"
        border.color: Colors.line
        radius: Math.min(6, theme.radius)
        y: plot.y + 6
        x: {
            const center = plot.x + (chart.hovered + 0.5) * chart.slot
            const right = center + 14
            return right + width <= chart.width ? right : Math.max(0, center - 14 - width)
        }

        ColumnLayout {
            id: tipColumn
            x: 12
            y: 10
            spacing: 3
            Label { text: tip.b ? tip.b.detail : ""; color: Colors.muted; font.pixelSize: 12 }
            Label {
                text: tip.b ? qsTr("%1 tokens").arg(backend.full(tip.b.total)) : ""
                color: Colors.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Repeater {
                model: tip.b ? [
                    [qsTr("Output"), tip.b.output],
                    [qsTr("Input"), tip.b.input],
                    [qsTr("Cache write"), tip.b.cacheWrite],
                    [qsTr("Cache read"), tip.b.cacheRead]
                ] : []
                RowLayout {
                    required property var modelData
                    spacing: 16
                    Label { text: modelData[0]; color: Colors.muted; font.pixelSize: 12; Layout.fillWidth: true }
                    Label { text: backend.compact(modelData[1]); color: Colors.text; font.pixelSize: 12 }
                }
            }
            Label {
                text: tip.b ? qsTr("%n requests", "", tip.b.requests) : ""
                color: Colors.faint
                font.pixelSize: 12
            }
        }
    }
}
