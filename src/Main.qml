import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1180
    height: 860
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "Token Tally"
    color: Colors.window

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    // Cache reads are usually most of the total and cheap; hiding them lets
    // the chart show what was actually written and read fresh.
    property bool showCacheRead: true
    readonly property var periodKeys: ["today", "week", "month", "all"]
    readonly property var periodNames: [qsTr("Today"), qsTr("This week"), qsTr("This month"), qsTr("All time")]

    function cycleAgent() {
        const list = [""].concat(backend.agents)
        backend.agentFilter = list[(list.indexOf(backend.agentFilter) + 1) % list.length]
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
            contentHeight: content.implicitHeight + 48
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: content
                x: 24
                y: 24
                width: flick.width - 48
                spacing: 16

                // Title, agent filter, and when the logs were last read.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        text: qsTr("Token usage")
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Colors.text
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [""].concat(backend.agents)
                        FilterChip {
                            required property string modelData
                            text: modelData === "" ? qsTr("All agents") : modelData
                            selected: backend.agentFilter === modelData
                            onClicked: backend.agentFilter = modelData
                        }
                    }
                    Label {
                        text: backend.loading ? qsTr("Reading logs…")
                              : backend.lastUpdated ? qsTr("Updated %1").arg(backend.lastUpdated) : ""
                        color: Colors.muted
                        font.pixelSize: 12
                        Layout.leftMargin: 8
                    }
                }

                // The four totals people check most, always visible.
                GridLayout {
                    Layout.fillWidth: true
                    columns: content.width > 900 ? 4 : 2
                    columnSpacing: 12
                    rowSpacing: 12
                    Repeater {
                        model: 4
                        PeriodTile {
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

                // The selected period over time.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: chartColumn.implicitHeight + 32

                    ColumnLayout {
                        id: chartColumn
                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            ToolButton {
                                text: "‹"
                                font.pixelSize: 20
                                enabled: backend.period !== 3
                                onClicked: backend.shift(-1)
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Previous (←)")
                            }
                            ToolButton {
                                text: "›"
                                font.pixelSize: 20
                                enabled: backend.offset < 0
                                onClicked: backend.shift(1)
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Next (→)")
                            }
                            ColumnLayout {
                                spacing: 2
                                Layout.leftMargin: 4
                                Label {
                                    text: backend.periodTitle
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    color: Colors.text
                                }
                                Label {
                                    readonly property real total: backend.summary.total || 0
                                    readonly property real previous: backend.summary.previousTotal === undefined ? -1 : backend.summary.previousTotal
                                    text: {
                                        let line = qsTr("%1 tokens · %n requests", "", backend.summary.requests || 0)
                                                     .arg(backend.full(total))
                                        if (previous > 0) {
                                            const change = (total - previous) / previous * 100
                                            line += " · " + qsTr("%1% vs. previous")
                                                .arg((change > 0 ? "+" : "") + change.toLocaleString(Qt.locale(), 'f', 0))
                                        }
                                        return line
                                    }
                                    color: Colors.muted
                                    font.pixelSize: 12
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: [
                                    { name: qsTr("Output"), color: Colors.output(theme.accent) },
                                    { name: qsTr("Input"), color: Colors.input(theme.accent) },
                                    { name: qsTr("Cache write"), color: Colors.cacheWrite(theme.accent) },
                                    { name: qsTr("Cache read"), color: Colors.cacheRead, toggle: true }
                                ]
                                RowLayout {
                                    required property var modelData
                                    spacing: 6
                                    Layout.leftMargin: 10
                                    opacity: modelData.toggle && !win.showCacheRead ? 0.4 : 1
                                    HoverHandler { enabled: !!modelData.toggle; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { enabled: !!modelData.toggle; onTapped: win.showCacheRead = !win.showCacheRead }
                                    ToolTip.visible: !!modelData.toggle && legendHover.hovered
                                    ToolTip.text: qsTr("Show or hide cache reads (C)")
                                    HoverHandler { id: legendHover }
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: Math.min(2, theme.radius)
                                        color: modelData.color
                                    }
                                    Label { text: modelData.name; color: Colors.muted; font.pixelSize: 12 }
                                }
                            }
                        }

                        UsageChart {
                            showCacheRead: win.showCacheRead
                            Layout.fillWidth: true
                            Layout.preferredHeight: 280
                        }
                    }
                }

                // Where the tokens went, and at what time of the week.
                GridLayout {
                    Layout.fillWidth: true
                    columns: content.width > 1050 ? 3 : 2
                    columnSpacing: 12
                    rowSpacing: 12

                    BreakdownCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        title: qsTr("Models")
                        items: backend.models
                    }
                    BreakdownCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        title: qsTr("Projects")
                        items: backend.projects
                    }
                    BreakdownCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        title: qsTr("Token types")
                        showRequests: false
                        items: {
                            const s = backend.summary
                            const t = s.total || 0
                            const share = v => t ? v / t : 0
                            return [
                                { name: qsTr("Output"), total: s.output || 0, share: share(s.output || 0) },
                                { name: qsTr("Input"), total: s.input || 0, share: share(s.input || 0) },
                                { name: qsTr("Cache write"), total: s.cacheWrite || 0, share: share(s.cacheWrite || 0) },
                                { name: qsTr("Cache read"), total: s.cacheRead || 0, share: share(s.cacheRead || 0) }
                            ].filter(item => t > 0)
                        }
                    }
                    BreakdownCard {
                        visible: backend.agents.length > 1 && backend.agentFilter === ""
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        title: qsTr("Agents")
                        items: backend.agentShares
                    }
                    ActivityHeatmap {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 2
                        Layout.columnSpan: 2
                        Layout.fillHeight: true
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
                    color: Colors.text
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Colors.muted
                    text: qsTr("Token Tally reads the logs Claude Code and Codex write. None were found in:") + "\n" + backend.roots.join("\n")
                }
            }
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
