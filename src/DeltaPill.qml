import QtQuick
import QtQuick.Controls

// The change against the same span before it. More usage isn't good or bad,
// so up is the accent and down stays neutral rather than red and green.
Rectangle {
    id: pill
    property real current: 0
    property real previous: -1
    readonly property real change: previous > 0 ? (current - previous) / previous * 100 : 0
    readonly property bool up: change >= 0

    visible: previous > 0
    implicitWidth: label.implicitWidth + 14
    implicitHeight: 20
    radius: Math.min(4, theme.radius)
    color: up ? Qt.rgba(Qt.color(theme.accent).r, Qt.color(theme.accent).g, Qt.color(theme.accent).b, 0.14)
              : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.08)

    Label {
        id: label
        anchors.centerIn: parent
        // Against a nearly empty stretch a percentage gets absurd; past ten
        // times as much, a factor reads better.
        text: (pill.up ? "▲ " : "▼ ") + (pill.change >= 900
              ? (pill.current / pill.previous).toLocaleString(Qt.locale(), 'f', 0) + "×"
              : Math.abs(pill.change).toLocaleString(Qt.locale(), 'f', 0) + " %")
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: pill.up ? theme.accent : theme.muted
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.delay: 400
    ToolTip.text: qsTr("Compared with the same stretch of the previous period (%1)").arg(backend.compact(pill.previous))
}
