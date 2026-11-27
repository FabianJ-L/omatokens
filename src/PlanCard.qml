import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// How much of the Claude plan's limits is used, as Claude Desktop last saw it.
// Chats in the app and on claude.ai have no token counts on disk, so this is
// the only place they show up; the meters cover everything on the account.
Card {
    id: card
    readonly property var plan: backend.planUsage
    readonly property var history: plan.history || []

    implicitHeight: column.implicitHeight + 40

    ColumnLayout {
        id: column
        x: 20
        y: 20
        width: parent.width - 40
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Label {
                    text: qsTr("Claude plan limits")
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: theme.text
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("From Claude Desktop · includes chats in the app and on claude.ai, and Claude Code")
                    color: theme.faint
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            Label {
                text: card.plan.sampledAt
                      ? qsTr("as of %1").arg(new Date(card.plan.sampledAt).toLocaleString(Qt.locale(), Locale.ShortFormat))
                      : ""
                color: theme.faint
                font.pixelSize: 11
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: win.wide ? 3 : 1
            columnSpacing: 28
            rowSpacing: 14

            Repeater {
                model: [
                    { key: "fiveHour", name: qsTr("5-hour limit"), stale: qsTr("No reading in the last 5 hours") },
                    { key: "sevenDay", name: qsTr("Weekly limit"), stale: qsTr("No reading this week") }
                ]
                ColumnLayout {
                    id: meter
                    required property var modelData
                    readonly property int value: card.plan[modelData.key] === undefined ? -1 : card.plan[modelData.key]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: meter.modelData.name
                            color: theme.muted
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Label {
                            text: meter.value < 0 ? "–" : meter.value + " %"
                            color: meter.value >= 80 ? theme.accent : theme.text
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: Math.min(3, theme.radius)
                        color: theme.grid
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: Math.max(0, Math.min(100, meter.value)) / 100 * parent.width
                            color: theme.accent
                            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        }
                    }
                    Label {
                        visible: meter.value < 0
                        text: meter.modelData.stale
                        color: theme.faint
                        font.pixelSize: 11
                    }
                }
            }

            // The weekly meter over the last seven days, as the app sampled it.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 6
                Label {
                    text: qsTr("Weekly limit, last 7 days")
                    color: theme.muted
                    font.pixelSize: 12
                }
                Canvas {
                    id: spark
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    readonly property var points: card.history
                    readonly property color stroke: theme.accent
                    onPointsChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const pts = points.filter(p => p.sevenDay >= 0)
                        if (pts.length < 2)
                            return
                        const t0 = pts[0].time, t1 = pts[pts.length - 1].time
                        const x = t => t1 > t0 ? (t - t0) / (t1 - t0) * (width - 2) + 1 : 1
                        const y = v => height - 1 - Math.min(100, v) / 100 * (height - 2)
                        ctx.strokeStyle = stroke
                        ctx.lineWidth = 1.5
                        ctx.beginPath()
                        pts.forEach((p, i) => i ? ctx.lineTo(x(p.time), y(p.sevenDay)) : ctx.moveTo(x(p.time), y(p.sevenDay)))
                        ctx.stroke()
                    }
                }
            }
        }
    }
}
