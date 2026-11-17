import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Tokens.js" as Tokens

// Stacked bars of the selected period: cache reads at the bottom, then cache
// writes, input, and output on top in the full accent. Bars keep their
// delegates while the number of buckets stays the same, so paging through
// weeks or a fresh poll animates heights instead of rebuilding them.
Item {
    id: chart
    property bool showCacheRead: true
    readonly property var buckets: backend.buckets
    readonly property int count: buckets.length
    readonly property var shades: Tokens.colors(theme.accent, theme.text)

    function shown(b) { return showCacheRead ? b.total : b.total - b.cacheRead }
    readonly property real rawMax: {
        let m = 0
        for (const b of buckets)
            m = Math.max(m, shown(b))
        return m
    }
    readonly property real niceMax: Tokens.niceCeiling(rawMax)
    property real scaleMax: niceMax
    Behavior on scaleMax { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    readonly property real average: {
        let sum = 0, n = 0
        for (const b of buckets)
            if (!b.future) { sum += shown(b); n++ }
        return n ? sum / n : 0
    }

    property int hovered: -1
    property int tipIndex: -1
    onHoveredChanged: if (hovered >= 0) tipIndex = hovered

    readonly property int axisWidth: 52
    readonly property int labelHeight: 24
    readonly property real slot: count ? plot.width / count : 0
    // Skip axis labels when they would collide.
    readonly property int labelStride: Math.max(1, Math.ceil(count * 34 / Math.max(1, plot.width)))

    Item {
        id: plot
        x: chart.axisWidth
        y: 6
        width: chart.width - chart.axisWidth
        height: chart.height - chart.labelHeight - 6
    }

    Repeater {
        model: 5
        Item {
            required property int index
            y: plot.y + plot.height * index / 4
            width: chart.width
            Rectangle {
                x: chart.axisWidth
                width: plot.width
                height: 1
                color: index === 4 ? theme.border : theme.grid
            }
            Label {
                width: chart.axisWidth - 12
                y: -height / 2
                horizontalAlignment: Text.AlignRight
                text: chart.rawMax > 0 || index === 4 ? backend.compact(chart.niceMax * (1 - index / 4)) : ""
                color: theme.faint
                font.pixelSize: 11
                font.features: { "tnum": 1 }
            }
        }
    }

    Repeater {
        model: chart.count
        Item {
            id: bar
            required property int index
            readonly property var b: chart.buckets[index] || ({ total: 0, output: 0, input: 0, cacheWrite: 0, cacheRead: 0 })
            readonly property bool active: chart.hovered === index
            readonly property real barWidth: Math.max(3, Math.min(40, chart.slot * 0.62))

            property real vOutput: b.output
            property real vInput: b.input
            property real vCacheWrite: b.cacheWrite
            property real vCacheRead: chart.showCacheRead ? b.cacheRead : 0
            Behavior on vOutput { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on vInput { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on vCacheWrite { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on vCacheRead { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

            // New bars grow in from the left, one after the other.
            property real grow: 0
            SequentialAnimation on grow {
                PauseAnimation { duration: Math.min(260, bar.index * 11) }
                NumberAnimation { to: 1; duration: 460; easing.type: Easing.OutCubic }
            }

            function h(value) { return chart.scaleMax > 0 ? value / chart.scaleMax * plot.height * grow : 0 }

            x: plot.x + index * chart.slot
            y: plot.y
            width: chart.slot
            height: plot.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.min(4, theme.radius)
                color: theme.text
                opacity: bar.active ? 0.05 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
            Column {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: bar.barWidth
                opacity: chart.hovered === -1 || bar.active ? 1 : 0.45
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Rectangle { width: parent.width; height: bar.h(bar.vOutput); color: chart.shades.output }
                Rectangle { width: parent.width; height: bar.h(bar.vInput); color: chart.shades.input }
                Rectangle { width: parent.width; height: bar.h(bar.vCacheWrite); color: chart.shades.cacheWrite }
                Rectangle { width: parent.width; height: bar.h(bar.vCacheRead); color: chart.shades.cacheRead }
            }
            Label {
                visible: bar.index % chart.labelStride === 0 || bar.b.current === true
                anchors.top: parent.bottom
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: bar.b.label || ""
                font.pixelSize: 11
                font.weight: bar.b.current ? Font.DemiBold : Font.Normal
                color: bar.b.current ? theme.accent : bar.b.future ? theme.faint : theme.muted
            }
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        chart.hovered = bar.index
                    else if (chart.hovered === bar.index)
                        chart.hovered = -1
                }
            }
        }
    }

    // The average of the buckets so far, as a dashed line.
    Item {
        id: averageLine
        visible: chart.average > 0 && chart.count > 1
        x: plot.x
        width: plot.width
        y: plot.y + plot.height - chart.average / Math.max(1, chart.scaleMax) * plot.height
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Row {
            spacing: 4
            Repeater {
                model: Math.max(0, Math.ceil(averageLine.width / 8))
                Rectangle { width: 4; height: 1; color: theme.accent; opacity: 0.55 }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.top
            anchors.bottomMargin: 3
            implicitWidth: averageLabel.implicitWidth + 10
            implicitHeight: 18
            radius: Math.min(4, theme.radius)
            color: theme.surface
            Label {
                id: averageLabel
                anchors.centerIn: parent
                text: qsTr("avg %1").arg(backend.compact(chart.average))
                font.pixelSize: 10
                font.features: { "tnum": 1 }
                color: theme.accent
            }
        }
    }

    // Details for the bar under the pointer, beside it.
    Rectangle {
        id: tip
        readonly property var b: chart.tipIndex >= 0 && chart.tipIndex < chart.count ? chart.buckets[chart.tipIndex] : null
        opacity: chart.hovered >= 0 && b ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        width: tipColumn.implicitWidth + 28
        height: tipColumn.implicitHeight + 22
        color: theme.surfaceHover
        border.color: theme.border
        radius: Math.min(6, theme.radius)
        y: plot.y + 4
        x: {
            const center = plot.x + (chart.tipIndex + 0.5) * chart.slot
            const right = center + chart.slot / 2 + 8
            return right + width <= chart.width ? right : Math.max(0, center - chart.slot / 2 - 8 - width)
        }
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: tipColumn
            x: 14
            y: 11
            spacing: 4
            Label { text: tip.b ? tip.b.detail : ""; color: theme.muted; font.pixelSize: 12 }
            Label {
                text: tip.b ? qsTr("%1 tokens").arg(backend.full(tip.b.total)) : ""
                color: theme.text
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Repeater {
                model: tip.b ? [
                    [qsTr("Output"), tip.b.output, chart.shades.output],
                    [qsTr("Input"), tip.b.input, chart.shades.input],
                    [qsTr("Cache write"), tip.b.cacheWrite, chart.shades.cacheWrite],
                    [qsTr("Cache read"), tip.b.cacheRead, chart.shades.cacheRead]
                ] : []
                RowLayout {
                    required property var modelData
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: Math.min(2, theme.radius); color: modelData[2] }
                    Label { text: modelData[0]; color: theme.muted; font.pixelSize: 12; Layout.fillWidth: true; Layout.rightMargin: 12 }
                    Label { text: backend.compact(modelData[1]); color: theme.text; font.pixelSize: 12; font.features: { "tnum": 1 } }
                }
            }
            Label {
                text: tip.b ? qsTr("%n requests", "", tip.b.requests) : ""
                color: theme.faint
                font.pixelSize: 11
            }
        }
    }
}
