import QtQuick
import QtQuick.Controls

// A token count that rolls to its new value instead of jumping.
Label {
    id: number
    property real value: 0
    property bool compact: true
    property real shown: value
    Behavior on shown { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    text: compact ? backend.compact(shown) : backend.full(shown)
    color: theme.text
    font.features: { "tnum": 1 }
}
