import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Tokens.js" as Tokens

// When in the week the tokens of the selected period were spent: one row per
// weekday, one cell per hour, brighter where more went through.
ColumnLayout {
    id: heat
    readonly property var values: backend.heatmap
    readonly property real maxValue: {
        let m = 0
        for (const v of values)
            m = Math.max(m, v)
        return m
    }
    property int hovered: -1
    readonly property int dayColumn: 36
    spacing: 10

    function shade(value) {
        return value > 0 ? Tokens.tint(theme.accent, 0.18 + 0.82 * Math.sqrt(value / Math.max(1, maxValue))) : theme.grid
    }

    Item {
        id: grid
        Layout.fillWidth: true
        readonly property real cell: (width - heat.dayColumn) / 24
        readonly property real rowHeight: Math.min(26, cell)
        implicitHeight: rowHeight * 7 + 20

        Repeater {
            model: 7
            Label {
                required property int index
                y: index * grid.rowHeight
                height: grid.rowHeight
                verticalAlignment: Text.AlignVCenter
                // Qt numbers weekdays from Sunday; the grid starts on Monday.
                text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
                color: Math.floor(heat.hovered / 24) === index ? theme.text : theme.muted
                font.pixelSize: 11
            }
        }
        Repeater {
            model: 7 * 24
            Rectangle {
                id: cell
                required property int index
                readonly property real value: heat.values[index] || 0
                x: heat.dayColumn + (index % 24) * grid.cell + 1.5
                y: Math.floor(index / 24) * grid.rowHeight + 1.5
                width: grid.cell - 3
                height: grid.rowHeight - 3
                radius: Math.min(3, theme.radius)
                color: heat.shade(value)
                border.width: heat.hovered === index ? 1 : 0
                border.color: theme.text
                Behavior on color { ColorAnimation { duration: 300 } }
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            heat.hovered = cell.index
                        else if (heat.hovered === cell.index)
                            heat.hovered = -1
                    }
                }
            }
        }
        Repeater {
            model: [0, 6, 12, 18]
            Label {
                required property int modelData
                x: heat.dayColumn + modelData * grid.cell + 1
                y: 7 * grid.rowHeight + 4
                text: modelData + ":00"
                color: Math.floor(heat.hovered % 24 / 6) * 6 === modelData && heat.hovered >= 0 ? theme.text : theme.faint
                font.pixelSize: 10
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Label {
            Layout.fillWidth: true
            text: heat.hovered >= 0
                  ? qsTr("%1, %2:00 · %3 tokens")
                        .arg(Qt.locale().dayName((Math.floor(heat.hovered / 24) + 1) % 7, Locale.LongFormat))
                        .arg(heat.hovered % 24)
                        .arg(backend.compact(heat.values[heat.hovered] || 0))
                  : qsTr("Hover a cell for details")
            color: heat.hovered >= 0 ? theme.text : theme.faint
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Label { text: qsTr("less"); color: theme.faint; font.pixelSize: 10 }
        Repeater {
            model: [0, 0.1, 0.35, 0.7, 1]
            Rectangle {
                required property real modelData
                width: 11
                height: 11
                radius: Math.min(2, theme.radius)
                color: heat.shade(modelData * Math.max(1, heat.maxValue))
            }
        }
        Label { text: qsTr("more"); color: theme.faint; font.pixelSize: 10 }
    }
}
