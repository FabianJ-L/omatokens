import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Tokens.js" as Tokens

ApplicationWindow {
    id: win
    width: 1200
    height: 920
    minimumWidth: 780
    minimumHeight: 560
    visible: true
    title: "OmaTokens"
    // See-through like the terminal, so Hyprland's blur shows behind it.
    color: Qt.alpha(theme.background, 0.72)

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius
    Material.background: theme.surfaceHover
    Material.foreground: theme.text

    property bool helpVisible: false
    // Cache reads are usually most of the total and cheap; hiding them lets
    // the chart show what was actually written and read fresh.
    property bool showCacheRead: true
    property int breakdownTab: 0
    readonly property int gap: 14
    readonly property bool wide: content.width > 960
    readonly property var periodKeys: ["today", "week", "month", "all"]
    readonly property var periodNames: [qsTr("Today"), qsTr("This week"), qsTr("This month"), qsTr("All time")]
    readonly property var agentList: [""].concat(backend.agents)
    readonly property var shades: Tokens.colors(theme.accent, theme.text)

    function cycleAgent() {
        backend.agentFilter = agentList[(agentList.indexOf(backend.agentFilter) + 1) % agentList.length]
    }

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Esc"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequences: ["Space", "R"]; context: Qt.ApplicationShortcut; onActivated: backend.refresh() }
    Shortcut { sequence: "1"; context: Qt.ApplicationShortcut; onActivated: backend.period = 0 }
    Shortcut { sequence: "2"; context: Qt.ApplicationShortcut; onActivated: backend.period = 1 }
    Shortcut { sequence: "3"; context: Qt.ApplicationShortcut; onActivated: backend.period = 2 }
    Shortcut { sequence: "4"; context: Qt.ApplicationShortcut; onActivated: backend.period = 3 }
    Shortcut { sequences: ["Left", "H"]; context: Qt.ApplicationShortcut; onActivated: backend.shift(-1) }
    Shortcut { sequences: ["Right", "L"]; context: Qt.ApplicationShortcut; onActivated: backend.shift(1) }
    Shortcut { sequences: ["Home", "0"]; context: Qt.ApplicationShortcut; onActivated: backend.offset = 0 }
    Shortcut { sequence: "A"; context: Qt.ApplicationShortcut; onActivated: win.cycleAgent() }
    Shortcut { sequence: "B"; context: Qt.ApplicationShortcut; onActivated: win.breakdownTab = (win.breakdownTab + 1) % 3 }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; onActivated: win.showCacheRead = !win.showCacheRead }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: content.implicitHeight + 56
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 4000
            ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

            ColumnLayout {
                id: content
                x: 28
                y: 24
                width: flick.width - 56
                spacing: win.gap

                // ── Header: name, agent filter, live state ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    spacing: 12

                    ColumnLayout {
                        spacing: 0
                        Label {
                            text: "OmaTokens"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: theme.text
                        }
                        RowLayout {
                            spacing: 6
                            Rectangle {
                                id: liveDot
                                width: 7
                                height: 7
                                radius: 3.5
                                color: theme.accent
                                SequentialAnimation {
                                    id: pulse
                                    NumberAnimation { target: liveDot; property: "scale"; to: 1.8; duration: 180; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: liveDot; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutCubic }
                                }
                                Connections {
                                    target: backend
                                    function onUpdated() { pulse.restart() }
                                }
                            }
                            Label {
                                text: backend.loading && !backend.lastUpdated ? qsTr("Reading logs…")
                                      : qsTr("Live · updated %1").arg(backend.lastUpdated)
                                color: theme.faint
                                font.pixelSize: 11
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Segmented {
                        visible: backend.agents.length > 1
                        labels: win.agentList.map(a => a === "" ? qsTr("All agents") : a)
                        currentIndex: win.agentList.indexOf(backend.agentFilter)
                        onActivated: index => backend.agentFilter = win.agentList[index]
                    }
                    ToolButton {
                        text: "?"
                        font.pixelSize: 15
                        onClicked: win.helpVisible = true
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Keyboard shortcuts")
                    }
                }

                // ── The four totals, which also pick the period ──
                GridLayout {
                    Layout.fillWidth: true
                    columns: win.wide ? 4 : 2
                    columnSpacing: win.gap
                    rowSpacing: win.gap
                    Repeater {
                        model: 4
                        StatTile {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            title: win.periodNames[index]
                            hint: String(index + 1)
                            stats: backend.overview[win.periodKeys[index]] || ({})
                            selected: backend.period === index
                            onClicked: backend.period = index
                        }
                    }
                }

                // ── Claude plan limits, when Claude Desktop is installed ──
                PlanCard {
                    visible: Object.keys(backend.planUsage).length > 0
                    Layout.fillWidth: true
                }

                // ── The selected period: headline numbers, then the chart ──
                Card {
                    Layout.fillWidth: true
                    implicitHeight: periodColumn.implicitHeight + 44

                    ColumnLayout {
                        id: periodColumn
                        x: 22
                        y: 22
                        width: parent.width - 44
                        spacing: 18

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 24

                            ColumnLayout {
                                spacing: 6
                                RowLayout {
                                    spacing: 2
                                    RoundButton {
                                        flat: true
                                        text: "‹"
                                        font.pixelSize: 18
                                        implicitWidth: 34
                                        implicitHeight: 34
                                        enabled: backend.period !== 3
                                        onClicked: backend.shift(-1)
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Previous (←)")
                                    }
                                    RoundButton {
                                        flat: true
                                        text: "›"
                                        font.pixelSize: 18
                                        implicitWidth: 34
                                        implicitHeight: 34
                                        enabled: backend.offset < 0
                                        onClicked: backend.shift(1)
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Next (→)")
                                    }
                                    Label {
                                        text: backend.periodTitle
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        color: theme.text
                                        Layout.leftMargin: 6
                                    }
                                    Button {
                                        visible: backend.offset < 0
                                        flat: true
                                        text: qsTr("Back to now")
                                        font.pixelSize: 12
                                        Material.foreground: theme.accent
                                        onClicked: backend.offset = 0
                                        Layout.leftMargin: 4
                                    }
                                }
                                RowLayout {
                                    spacing: 12
                                    Layout.leftMargin: 6
                                    AnimatedNumber {
                                        value: backend.summary.total || 0
                                        font.pixelSize: 42
                                        font.weight: Font.Bold
                                    }
                                    ColumnLayout {
                                        spacing: 4
                                        DeltaPill {
                                            current: backend.summary.total || 0
                                            previous: backend.summary.previousTotal === undefined ? -1 : backend.summary.previousTotal
                                        }
                                        Label {
                                            text: qsTr("%1 tokens").arg(backend.full(backend.summary.total || 0))
                                            color: theme.faint
                                            font.pixelSize: 11
                                            font.features: { "tnum": 1 }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Token types double as the chart legend; cache
                            // reads can be switched off here.
                            GridLayout {
                                columns: win.wide ? 5 : 3
                                columnSpacing: 26
                                rowSpacing: 12
                                Layout.alignment: Qt.AlignBottom

                                Repeater {
                                    model: [
                                        { key: "requests", name: qsTr("Requests"), color: "transparent" },
                                        { key: "output", name: qsTr("Output"), color: win.shades.output },
                                        { key: "input", name: qsTr("Input"), color: win.shades.input },
                                        { key: "cacheWrite", name: qsTr("Cache write"), color: win.shades.cacheWrite },
                                        { key: "cacheRead", name: qsTr("Cache read"), color: win.shades.cacheRead, toggle: true }
                                    ]
                                    ColumnLayout {
                                        id: stat
                                        required property var modelData
                                        readonly property bool off: !!modelData.toggle && !win.showCacheRead
                                        spacing: 3
                                        opacity: off ? 0.45 : 1
                                        Behavior on opacity { NumberAnimation { duration: 160 } }

                                        RowLayout {
                                            spacing: 6
                                            Rectangle {
                                                visible: stat.modelData.key !== "requests"
                                                width: 8
                                                height: 8
                                                radius: Math.min(2, theme.radius)
                                                color: stat.modelData.color
                                            }
                                            Label {
                                                text: stat.modelData.name
                                                color: theme.muted
                                                font.pixelSize: 12
                                                font.strikeout: stat.off
                                            }
                                        }
                                        AnimatedNumber {
                                            value: backend.summary[stat.modelData.key] || 0
                                            font.pixelSize: 17
                                            font.weight: Font.DemiBold
                                        }
                                        HoverHandler {
                                            id: statHover
                                            enabled: !!stat.modelData.toggle
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            enabled: !!stat.modelData.toggle
                                            onTapped: win.showCacheRead = !win.showCacheRead
                                        }
                                        ToolTip.visible: statHover.hovered
                                        ToolTip.delay: 300
                                        ToolTip.text: qsTr("Show or hide cache reads in the chart (C)")
                                    }
                                }
                            }
                        }

                        // How the period's tokens split, as one bar.
                        Rectangle {
                            id: shareBar
                            Layout.fillWidth: true
                            implicitHeight: 6
                            radius: Math.min(3, theme.radius)
                            color: theme.grid
                            clip: true
                            readonly property real total: backend.summary.total || 0
                            function part(key) { return total > 0 ? (backend.summary[key] || 0) / total * width : 0 }
                            Row {
                                height: parent.height
                                Repeater {
                                    model: [
                                        ["output", win.shades.output],
                                        ["input", win.shades.input],
                                        ["cacheWrite", win.shades.cacheWrite],
                                        ["cacheRead", win.shades.cacheRead]
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        height: shareBar.height
                                        width: shareBar.part(modelData[0])
                                        color: modelData[1]
                                        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }

                        UsageChart {
                            showCacheRead: win.showCacheRead
                            Layout.fillWidth: true
                            Layout.preferredHeight: 270
                        }
                    }
                }

                // ── Where it went, and when ──
                GridLayout {
                    Layout.fillWidth: true
                    columns: win.wide ? 2 : 1
                    columnSpacing: win.gap
                    rowSpacing: win.gap

                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        implicitHeight: breakdownColumn.implicitHeight + 40

                        ColumnLayout {
                            id: breakdownColumn
                            x: 20
                            y: 20
                            width: parent.width - 40
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: qsTr("Breakdown")
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                    Layout.fillWidth: true
                                }
                                Segmented {
                                    labels: [qsTr("Models"), qsTr("Projects"), qsTr("Agents")]
                                    currentIndex: win.breakdownTab
                                    onActivated: index => win.breakdownTab = index
                                    implicitHeight: 28
                                }
                            }
                            BreakdownList {
                                Layout.fillWidth: true
                                Layout.leftMargin: -8
                                Layout.rightMargin: -8
                                items: [backend.models, backend.projects, backend.agentShares][win.breakdownTab]
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        implicitHeight: heatColumn.implicitHeight + 40

                        ColumnLayout {
                            id: heatColumn
                            x: 20
                            y: 20
                            width: parent.width - 40
                            spacing: 14
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                Label {
                                    text: qsTr("When you use it")
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: theme.text
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: win.periodNames[backend.period]
                                    color: theme.faint
                                    font.pixelSize: 12
                                }
                            }
                            ActivityHeatmap { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        // Nothing to show: say where the logs were looked for.
        Card {
            visible: !backend.loading && backend.recordCount === 0 && backend.lastUpdated !== ""
            anchors.centerIn: parent
            width: Math.min(560, parent.width - 48)
            implicitHeight: emptyColumn.implicitHeight + 48
            ColumnLayout {
                id: emptyColumn
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 8
                Label {
                    text: qsTr("No usage found")
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: theme.text
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: theme.muted
                    text: qsTr("OmaTokens reads the logs that Claude Code, Codex, Gemini CLI, Qwen Code, and OpenCode write. None were found in:") + "\n" + backend.roots.join("\n")
                }
            }
        }

        HelpOverlay {
            anchors.fill: parent
            shown: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
