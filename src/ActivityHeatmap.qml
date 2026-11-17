import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// When in the week the tokens of the selected period were spent: one row per
// weekday, one cell per hour, brighter where more went through.
Card {
    id: card
    readonly property var values: backend.heatmap
    readonly property real maxValue: {
        let m = 0
        for (const v of values)
            m = Math.max(m, v)
        return m
    }
    property int hovered: -1
    readonly property int dayColumn: 44

    implicitHeight: column.implicitHeight + 32

    ColumnLayout {
        id: column
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("When you use it"); color: Colors.muted; font.pixelSize: 13; Layout.fillWidth: true }
            Label {
                // Qt numbers weekdays from Sunday; the grid starts on Monday.
                text: card.hovered >= 0
                      ? qsTr("%1, %2:00 · %3 tokens")
                            .arg(Qt.locale().dayName((Math.floor(card.hovered / 24) + 1) % 7, Locale.LongFormat))
                            .arg(card.hovered % 24)
                            .arg(backend.compact(card.values[card.hovered] || 0))
                      : ""
                color: Colors.text
                font.pixelSize: 12
            }
        }

        Item {
            id: grid
            Layout.fillWidth: true
            readonly property real cell: (width - card.dayColumn) / 24
            implicitHeight: cell * 7 * 0.8 + 18

            Repeater {
                model: 7
                Label {
                    required property int index
                    y: index * grid.cell * 0.8
                    height: grid.cell * 0.8
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
                    color: Colors.muted
                    font.pixelSize: 11
                }
            }
            Repeater {
                model: 7 * 24
                Rectangle {
                    required property int index
                    readonly property real value: card.values[index] || 0
                    x: card.dayColumn + (index % 24) * grid.cell + 1
                    y: Math.floor(index / 24) * grid.cell * 0.8 + 1
                    width: grid.cell - 2
                    height: grid.cell * 0.8 - 2
                    radius: Math.min(3, theme.radius)
                    color: value > 0 ? Colors.tint(theme.accent, 0.15 + 0.85 * Math.sqrt(value / card.maxValue)) : Colors.grid
                    border.width: card.hovered === index ? 1 : 0
                    border.color: Colors.text
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                card.hovered = parent.index
                            else if (card.hovered === parent.index)
                                card.hovered = -1
                        }
                    }
                }
            }
            Repeater {
                model: [0, 6, 12, 18, 23]
                Label {
                    required property int modelData
                    x: card.dayColumn + modelData * grid.cell + 2
                    y: 7 * grid.cell * 0.8 + 3
                    text: modelData + ":00"
                    color: Colors.faint
                    font.pixelSize: 10
                }
            }
        }
    }
}
