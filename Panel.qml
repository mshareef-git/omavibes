import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
    id: root

    moduleName: "io.github.mshareef-git.omavibes"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var omaState: OmaVibesState

    property string searchText: ""
    property int highlightedIndex: -1
    property string activeView: "sounds" // "sounds" | "profile" | "stats"
    property string analyticsGraphView: "day" // "day" | "week" | "month"

    function analyticsWordsTooltip(item) {
        if (!item) return ""
        const words = Number(item.value || 0).toLocaleString()
        if (item.dateKey) {
            const parts = String(item.dateKey).split("-")
            if (parts.length === 3)
                return String(item.label) + " " + Number(parts[2]) + "  •  " + words + " words"
        }
        return String(item.label) + "  •  " + words + " words"
    }

    readonly property string uiFont:
        root.bar ? root.bar.fontFamily : Style.font.family

    // Theme-derived visualization palette. Quattro exposes accent/urgent and
    // the neutral foreground ramp to plugins; derive extra shades from those
    // roles instead of hard-coding a separate color scheme.
    // Live Quattro theme palette. Keep visualizations tied to semantic
    // theme roles so the whole profile adapts when the user changes theme.
    readonly property color vizPrimary: Color.accent
    readonly property color vizSecondary: Color.urgent
    readonly property color vizTertiary: Color.foreground
    readonly property color vizQuaternary: Qt.lighter(Color.accent, 1.22)
    readonly property color vizNeutral: Color.muted
    readonly property color vizMuted: Color.muted

    function tint(colorValue, alpha) {
        return Qt.rgba(
            colorValue.r,
            colorValue.g,
            colorValue.b,
            Math.max(0, Math.min(1, alpha))
        )
    }

    function vizColor(index) {
        const palette = [
            vizPrimary,
            vizSecondary,
            vizTertiary,
            vizQuaternary
        ]
        return palette[Math.max(0, Number(index) || 0) % palette.length]
    }

    function keyDisplayLabel(key) {
        const labels = {
            "BACKSPACE": "BS",
            "SPACE": "SPC",
            "ENTER": "ENT",
            "CAPSLOCK": "CAPS",
            "LEFTSHIFT": "SHIFT",
            "RIGHTSHIFT": "SHIFT",
            "SHIFT": "SHIFT",
            "CTRL": "CTRL",
            "ALT": "ALT",
            "META": "META",
            "TAB": "TAB",
            "PAGEUP": "PGUP",
            "PAGEDOWN": "PGDN"
        }
        return labels[key] || key
    }

    readonly property var filteredPacks:
        omaState && omaState.packs
            ? omaState.packs.filter(
                p => p.name.toLowerCase().includes(searchText.toLowerCase())
              )
            : []

    function formatDuration(seconds) {
        const total = Math.max(0, Math.round(Number(seconds) || 0))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (hours > 0) return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    function tierColor(index) {
        const palette = [
            vizPrimary,
            vizSecondary,
            vizTertiary,
            vizQuaternary
        ]
        return palette[Math.max(0, Number(index) || 0) % palette.length]
    }

    function formatPackName(name) {
        if (!name)
            return ""

        var special = {
            "nl": "NL",
            "osu": "OSU",
            "nk": "NK",
            "eg": "EG",
            "pbt": "PBT",
            "abs": "ABS",
            "mx": "MX",
            "8": "8"
        }

        return name.split(" ").map(function(word) {
            var lower = word.toLowerCase()

            if (special[lower])
                return special[lower]

            if (lower === "cherrymx")
                return "CherryMX"

            if (!word.length)
                return word

            return word.charAt(0).toUpperCase() + word.slice(1)
        }).join(" ")
    }

    function open() {
        root.activeView = "sounds"
        root.controller.show()
        Qt.callLater(function() {
            if (searchField)
                searchField.forceActiveFocus()
        })
    }

    function close() {
        root.searchText = ""
        root.highlightedIndex = -1
        root.controller.hide()
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.open()
    }

    function setVolumeFromPosition(mouseX, width) {
        if (!omaState.currentPack || width <= 0)
            return

        var ratio = Math.max(0, Math.min(1, mouseX / width))
        var value = 1 + Math.round(ratio * 9)

        omaState.setVolume(value)
    }

    function resetHighlight() {
        Qt.callLater(function() {
            highlightedIndex = filteredPacks.length > 0 ? 0 : -1

            if (highlightedIndex >= 0)
                packList.positionViewAtIndex(
                    highlightedIndex,
                    ListView.Beginning
                )
        })
    }

    function moveHighlight(direction) {
        if (filteredPacks.length === 0) {
            highlightedIndex = -1
            return
        }

        var nextIndex = highlightedIndex + direction

        if (nextIndex < 0)
            nextIndex = 0

        if (nextIndex >= filteredPacks.length)
            nextIndex = filteredPacks.length - 1

        highlightedIndex = nextIndex

        packList.positionViewAtIndex(
            highlightedIndex,
            ListView.Contain
        )
    }

    function playHighlighted() {
        if (
            highlightedIndex >= 0 &&
            highlightedIndex < filteredPacks.length
        ) {
            omaState.play(
                filteredPacks[highlightedIndex].name
            )
        }
    }

    KeyboardPanel {
        id: panel

        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(400))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher

            anchors.fill: parent

            onCloseRequested: root.close()

            Column {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                anchors.margins: Style.space(2)

                spacing: Style.space(10)

                // ─────────────────────────
                // HEADER
                // ─────────────────────────

                Text {
                    width: parent.width

                    text: "⌨ OmaVibes"

                    color: Color.popups.text

                    font.family: root.uiFont
                    font.pixelSize: 24
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: root.activeView === "sounds"

                    text: omaState.todayRemarkText()

                    color: root.vizPrimary
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.bold: true

                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Column {
                    width: parent.width
                    visible: root.activeView === "settings"
                    height: visible ? implicitHeight : 0
                    spacing: Style.space(10)

                    Row {
                        spacing: Style.space(6)

                        Text {
                            text: "←"
                            color: Color.accent
                            font.family: root.uiFont
                            font.pixelSize: 16
                            font.bold: true
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: root.activeView = "sounds"
                            }
                        }

                        Text {
                            text: "Settings"
                            color: Color.muted
                            font.family: root.uiFont
                            font.pixelSize: 13
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: root.activeView = "sounds"
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Keyboard input"
                        color: Color.popups.text
                        font.family: root.uiFont
                        font.pixelSize: 17
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: "Choose the keyboard OmaVibes listens to. Your choice is saved and survives reconnects."
                        color: Color.muted
                        font.family: root.uiFont
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: Style.space(6)

                        Repeater {
                            model: omaState.keyboardDevices

                            delegate: Rectangle {
                                width: parent.width
                                height: 58
                                radius: 10
                                property bool selected: modelData.path === omaState.inputDevicePath
                                color: selected
                                    ? Style.selectedFillFor(Color.popups.text, Color.accent)
                                    : keyboardMouse.containsMouse
                                        ? Style.hoverFillFor(Color.popups.text, Color.accent)
                                        : Color.popups.background
                                border.width: 1
                                border.color: selected ? Color.accent : Color.popups.border

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: selectedMark.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 8
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        color: Color.popups.text
                                        font.family: root.uiFont
                                        font.pixelSize: 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.path
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                    }
                                }

                                Text {
                                    id: selectedMark
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.selected
                                    text: "✓"
                                    color: Color.accent
                                    font.family: root.uiFont
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                MouseArea {
                                    id: keyboardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: omaState.selectInputDevice(modelData.path)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: omaState.keyboardDevices.length === 0
                        text: "No keyboard devices found. Make sure the device is connected and your user can read /dev/input."
                        color: Color.urgent
                        font.family: root.uiFont
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }

                // ─────────────────────────
                // SEARCH
                // ─────────────────────────

                TextField {
                    id: searchField

                    width: parent.width
                    height: 39
                    visible: root.activeView === "sounds"

                    placeholderText: "Search soundpacks..."
                    text: root.searchText

                    font.family: root.uiFont
                    font.pixelSize: 14

                    onTextChanged: {
                        if (root.searchText !== text)
                            root.searchText = text

                        root.resetHighlight()
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            root.moveHighlight(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveHighlight(-1)
                            event.accepted = true
                        } else if (
                            event.key === Qt.Key_Return ||
                            event.key === Qt.Key_Enter
                        ) {
                            root.playHighlighted()
                            event.accepted = true
                        }
                    }
                }

                // ─────────────────────────
                // SOUND LIST + ACTIONS
                // ─────────────────────────

                Row {
                    id: mainArea

                    width: parent.width
                    height: 235
                    visible: root.activeView === "sounds"

                    spacing: Style.space(10)

                    // SOUND LIST
                    Rectangle {
                        width: parent.width * 0.68
                        height: parent.height

                        color: Color.popups.background
                        radius: Style.cornerRadius

                        border.width: 1
                        border.color: Color.popups.border

                        ListView {
                            id: packList

                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true
                            spacing: 2

                            model: root.filteredPacks
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                            }


                            delegate: Rectangle {
                                width: packList.width
                                height: 38

                                radius: 8

                                property bool selected:
                                    omaState.currentPack === modelData.name

                                property bool keyboardSelected:
                                    index === root.highlightedIndex

                                // subtle alternating row shading so eyes
                                // track rows while scanning a long list
                                readonly property color zebraColor: Qt.rgba(
                                    Color.popups.text.r,
                                    Color.popups.text.g,
                                    Color.popups.text.b,
                                    0.035
                                )

                                color:
                                    keyboardSelected
                                        ? Style.selectedFillFor(
                                            Color.popups.text,
                                            Color.accent
                                          )
                                        : selected
                                            ? Style.selectedFillFor(
                                                Color.popups.text,
                                                Color.accent
                                              )
                                            : mouseArea.containsMouse
                                                ? Style.hoverFillFor(
                                                    Color.popups.text,
                                                    Color.accent
                                                  )
                                                : (index % 2 === 0 ? zebraColor : "transparent")

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12

                                    anchors.right: check.left
                                    anchors.rightMargin: 8

                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.formatPackName(modelData.name)

                                    color: Color.popups.text

                                    font.family: root.uiFont
                                    font.pixelSize: 14

                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: check

                                    anchors.right: parent.right
                                    anchors.rightMargin: 12

                                    anchors.verticalCenter: parent.verticalCenter

                                    text: "✓"

                                    visible: parent.selected

                                    color: Color.accent

                                    font.family: root.uiFont
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                MouseArea {
                                    id: mouseArea

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    onClicked: {
                                        root.highlightedIndex = index
                                        omaState.play(modelData.name)
                                    }
                                }
                            }
                        }
                    }

                    // ACTION BUTTONS
                    Column {
                        width: parent.width * 0.32 - parent.spacing
                        height: parent.height
                        spacing: Style.space(10)

                        Rectangle { width: parent.width; height: (parent.height - 3 * parent.spacing) / 4; radius: 10
                            color: profileMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.popups.background
                            border.width: 1; border.color: Color.popups.border
                            Column { anchors.centerIn: parent; spacing: 4
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf2bd"; color: Color.accent; font.family: root.uiFont; font.pixelSize: 20 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Profile"; color: Color.popups.text; font.family: root.uiFont; font.pixelSize: 13; font.bold: true }
                            }
                            MouseArea { id: profileMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.activeView = "profile" }
                        }

                        Rectangle { width: parent.width; height: (parent.height - 3 * parent.spacing) / 4; radius: 10
                            color: statsMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.popups.background
                            border.width: 1; border.color: Color.popups.border
                            Column { anchors.centerIn: parent; spacing: 4
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uf201"; color: Color.accent; font.family: root.uiFont; font.pixelSize: 20 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Stats"; color: Color.popups.text; font.family: root.uiFont; font.pixelSize: 13; font.bold: true }
                            }
                            MouseArea { id: statsMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.activeView = "stats" }
                        }

                        Rectangle { width: parent.width; height: (parent.height - 3 * parent.spacing) / 4; radius: 10
                            color: randomMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.popups.background
                            border.width: 1; border.color: Color.popups.border
                            Column { anchors.centerIn: parent; spacing: 4
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\uedec"; color: Color.accent; font.family: root.uiFont; font.pixelSize: 20 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Random"; color: Color.popups.text; font.family: root.uiFont; font.pixelSize: 13; font.bold: true }
                            }
                            MouseArea { id: randomMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { if (root.filteredPacks.length > 0) { const i=Math.floor(Math.random()*root.filteredPacks.length); omaState.play(root.filteredPacks[i].name) } } }
                        }

                        Rectangle { width: parent.width; height: (parent.height - 3 * parent.spacing) / 4; radius: 10
                            color: stopMouse.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent) : Color.popups.background
                            border.width: 1; border.color: Color.popups.border
                            Column { anchors.centerIn: parent; spacing: 4
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\udb81\udd81"; color: Color.accent; font.family: root.uiFont; font.pixelSize: 20 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Turn Off"; color: Color.popups.text; font.family: root.uiFont; font.pixelSize: 13; font.bold: true }
                            }
                            MouseArea { id: stopMouse; anchors.fill: parent; hoverEnabled: true; onClicked: omaState.stop() }
                        }
                    }

                    // Close mainArea Row before volume controls.
                }

                // ─────────────────────────
                // VOLUME HEADER
                // ─────────────────────────

                Text {
                    visible: root.activeView === "sounds"

                    text:
                        omaState.currentPack
                            ? "Volume: " +
                              Math.round(
                                  omaState.volumeFor(
                                      omaState.currentPack
                                  )
                              )
                            : "Volume: —"

                    color: Color.popups.text

                    font.family: root.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                // ─────────────────────────
                // VOLUME SLIDER
                // ─────────────────────────

                Rectangle {
                    id: volumeTrack

                    width: parent.width
                    height: 24
                    visible: root.activeView === "sounds"

                    color: "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        height: 5
                        radius: 3

                        color: Color.popups.border
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        width:
                            omaState.currentPack
                                ? volumeTrack.width *
                                  (
                                      (
                                          omaState.volumeFor(
                                              omaState.currentPack
                                          ) - 1
                                      ) / 9
                                  )
                                : 0

                        height: 5
                        radius: 3

                        color: Color.accent
                    }

                    Rectangle {
                        width: 16
                        height: 16

                        radius: 8

                        x:
                            omaState.currentPack
                                ? (
                                    volumeTrack.width - width
                                  ) *
                                  (
                                      (
                                          omaState.volumeFor(
                                              omaState.currentPack
                                          ) - 1
                                      ) / 9
                                  )
                                : 0

                        anchors.verticalCenter: parent.verticalCenter

                        color: Color.accent

                        border.width: 2
                        border.color: Color.popups.background
                    }

                    MouseArea {
                        anchors.fill: parent

                        enabled: omaState.currentPack !== ""

                        onPressed: function(mouse) {
                            root.setVolumeFromPosition(
                                mouse.x,
                                volumeTrack.width
                            )
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                root.setVolumeFromPosition(
                                    mouse.x,
                                    volumeTrack.width
                                )
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 44
                    visible: root.activeView === "sounds"
                    spacing: Style.space(10)

                    Text {
                        width: parent.width - keyboardSettings.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter

                        text:
                            omaState.isPlaying && omaState.currentPack
                                ? "Now playing: " +
                                  root.formatPackName(omaState.currentPack)
                                : "Now playing: None"

                        color: Color.muted
                        font.family: root.uiFont
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: keyboardSettings
                        width: 34
                        height: 34
                        y: Math.round((parent.height - height) / 2)
                        radius: 12
                        color: settingsMouse.containsMouse
                            ? Style.hoverFillFor(Color.popups.text, Color.accent)
                            : "transparent"
                        border.width: 2
                        border.color: Color.accent

                        Text {
                            anchors.centerIn: parent
                            text: "⚙"
                            color: Color.accent
                            font.family: root.uiFont
                            font.pixelSize: 17
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                omaState.loadKeyboardDevices()
                                root.activeView = "settings"
                            }
                        }
                    }
                }

                // ─────────────────────────
                // PROFILE / STATS
                // ─────────────────────────

                Column {
                    id: analyticsView

                    width: parent.width
                    visible: root.activeView === "profile" || root.activeView === "stats"
                    height: visible ? 550 : 0
                    spacing: Style.space(10)

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        Text {
                            text: "←"
                            color: Color.accent
                            font.family: root.uiFont
                            font.pixelSize: 16
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: root.activeView = "sounds"
                            }
                        }

                        Text {
                            text: root.activeView === "profile" ? "Back to Sounds  •  Profile" : "Back to Sounds  •  Stats"
                            color: Color.muted
                            font.family: root.uiFont
                            font.pixelSize: 13

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: root.activeView = "sounds"
                            }
                        }
                    }

                    Flickable {
                        id: analyticsFlick

                        width: parent.width
                        height: 520
                        clip: true

                        contentWidth: width
                        contentHeight: analyticsContent.implicitHeight

                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Column {
                            id: analyticsContent

                            width: analyticsFlick.width
                            spacing: Style.space(10)

                            // ── PROFILE ──
                            Column {
                                width: parent.width
                                visible: root.activeView === "profile"
                                height: visible ? implicitHeight : 0
                                spacing: Style.space(8)

                                Text {
                                    text: "PROFILE"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                // Tier hero card
                                Rectangle {
                                    width: parent.width
                                    height: 132
                                    radius: 12
                                    color: Color.popups.background
                                    border.width: 1
                                    border.color: root.tierColor(omaState.lifetimeTierIndex())

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        opacity: 0.22
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: root.tint(root.vizPrimary, 0.32) }
                                            GradientStop { position: 0.52; color: root.tint(root.vizSecondary, 0.18) }
                                            GradientStop { position: 1.0; color: root.tint(root.vizTertiary, 0.12) }
                                        }
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 6

                                        Row {
                                            width: parent.width
                                            spacing: 10

                                            Rectangle {
                                                width: 44
                                                height: 44
                                                radius: 12
                                                color: Qt.rgba(root.tierColor(omaState.lifetimeTierIndex()).r, root.tierColor(omaState.lifetimeTierIndex()).g, root.tierColor(omaState.lifetimeTierIndex()).b, 0.13)
                                                border.width: 1
                                                border.color: root.tierColor(omaState.lifetimeTierIndex())

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: omaState.lifetimeTier().symbol
                                                    color: root.tierColor(omaState.lifetimeTierIndex())
                                                    font.family: root.uiFont
                                                    font.pixelSize: 23
                                                    font.bold: true
                                                }
                                            }

                                            Column {
                                                width: parent.width - 54
                                                spacing: 1

                                                Row {
                                                    width: parent.width
                                                    spacing: 7

                                                    Text {
                                                        text: omaState.lifetimeTier().name
                                                        color: root.tierColor(omaState.lifetimeTierIndex())
                                                        font.family: root.uiFont
                                                        font.pixelSize: 18
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: "LV " + (omaState.lifetimeTierIndex() + 1) + "/" + omaState.typingTiers.length
                                                        color: root.tierColor(omaState.lifetimeTierIndex())
                                                        font.family: root.uiFont
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                    }
                                                }

                                                Text {
                                                    text: omaState.lifetimeWords().toLocaleString() + " lifetime words"
                                                    color: root.vizTertiary
                                                    font.family: root.uiFont
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 8
                                            radius: 4
                                            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.07)

                                            Rectangle {
                                                width: parent.width * omaState.lifetimeTierProgress()
                                                height: parent.height
                                                radius: 4
                                                color: root.tierColor(omaState.lifetimeTierIndex())
                                            }
                                        }

                                        Row {
                                            width: parent.width

                                            Text {
                                                width: parent.width * 0.72
                                                text: omaState.lifetimeNextTier()
                                                    ? omaState.lifetimeWordsToNextTier().toLocaleString() + " words to " + omaState.lifetimeNextTier().name
                                                    : "Maximum tier reached"
                                                color: Color.muted
                                                font.family: root.uiFont
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width * 0.28
                                                horizontalAlignment: Text.AlignRight
                                                text: Math.round(omaState.lifetimeTierProgress() * 100) + "%"
                                                color: root.tierColor(omaState.lifetimeTierIndex())
                                                font.family: root.uiFont
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                // Core lifetime numbers
                                Row {
                                    width: parent.width
                                    spacing: Style.space(6)

                                    Repeater {
                                        model: [
                                            { label: "WORDS", value: omaState.lifetimeWords().toLocaleString(), color: root.tierColor(0) },
                                            { label: "KEYS", value: omaState.lifetimeKeyPresses().toLocaleString(), color: root.tierColor(1) },
                                            { label: "TYPING", value: root.formatDuration(omaState.lifetimeTypingSeconds()), color: root.tierColor(2) },
                                            { label: "STREAK", value: omaState.lifetimeLongestStreak().toLocaleString() + "d", color: root.tierColor(3) }
                                        ]

                                        delegate: Rectangle {
                                            width: (parent.width - 3 * Style.space(6)) / 4
                                            height: 55
                                            radius: 9
                                            color: root.tint(modelData.color, 0.07)
                                            border.width: 1
                                            border.color: root.tint(modelData.color, 0.50)

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 1

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.value
                                                    color: modelData.color
                                                    font.family: root.uiFont
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.label
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "PERSONAL RECORDS"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Row {
                                    width: parent.width
                                    spacing: Style.space(6)

                                    Repeater {
                                        model: [
                                            { label: "BEST DAY", value: omaState.lifetimeBestDay().words.toLocaleString(), color: root.tierColor(4) },
                                            { label: "ACTIVE DAYS", value: omaState.lifetimeActiveDays().toLocaleString(), color: root.tierColor(5) },
                                            { label: "AVG / ACTIVE DAY", value: Math.round(omaState.lifetimeAverageWordsPerActiveDay()).toLocaleString(), color: root.tierColor(6) }
                                        ]

                                        delegate: Rectangle {
                                            width: (parent.width - 2 * Style.space(6)) / 3
                                            height: 54
                                            radius: 9
                                            color: root.tint(modelData.color, 0.06)
                                            border.width: 1
                                            border.color: root.tint(modelData.color, 0.44)

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 1

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.value
                                                    color: modelData.color
                                                    font.family: root.uiFont
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                }

                                                Text {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: modelData.label
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "ACHIEVEMENTS"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Column {
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: omaState.profileAchievements()

                                        delegate: Rectangle {
                                            width: parent.width
                                            height: 38
                                            radius: 8
                                            color: root.tint(root.tierColor(index + 7), 0.11)
                                            border.width: 1
                                            border.color: root.tint(root.tierColor(index + 7), 0.52)

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 9
                                                anchors.rightMargin: 9
                                                spacing: 8

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 20
                                                    text: modelData.symbol
                                                    color: root.tierColor(index + 7)
                                                    font.family: root.uiFont
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 28
                                                    spacing: 0

                                                    Text {
                                                        text: modelData.name
                                                        color: Color.popups.text
                                                        font.family: root.uiFont
                                                        font.pixelSize: 9
                                                        font.bold: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: modelData.detail
                                                        color: Color.muted
                                                        font.family: root.uiFont
                                                        font.pixelSize: 7
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: omaState.profileAchievements().length === 0
                                        text: "No achievements unlocked yet"
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            // STATS is a sibling of PROFILE, not a child of it.
                            // Keeping these two views separate is important because
                            // the PROFILE column is hidden while STATS is open.
                            Column {
                                width: parent.width
                                visible: root.activeView === "stats"
                                height: visible ? implicitHeight : 0
                                spacing: Style.space(10)

                                Text {
                                    text: "STATS"
                                    color: root.vizPrimary
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Text {
                                    visible: omaState.lifetimeWords() === 0 && omaState.lifetimeKeyPresses() === 0
                                    text: "No typing data yet — start typing while OmaVibes is active."
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }

                                Row {
                                    width: parent.width
                                    spacing: Style.space(6)

                                    Repeater {
                                        model: [
                                            { label: "WORDS", value: omaState.lifetimeWords().toLocaleString(), color: root.vizPrimary },
                                            { label: "TYPING", value: root.formatDuration(omaState.lifetimeTypingSeconds()), color: root.vizSecondary },
                                            { label: "KEYS", value: omaState.lifetimeKeyPresses().toLocaleString(), color: root.vizTertiary },
                                            { label: "ACTIVE", value: omaState.lifetimeActiveDays().toLocaleString() + "d", color: root.vizQuaternary }
                                        ]

                                        delegate: Rectangle {
                                            width: (parent.width - 3 * Style.space(6)) / 4
                                            height: 50
                                            radius: 9
                                            color: root.tint(modelData.color, 0.075)
                                            border.width: 1
                                            border.color: root.tint(modelData.color, 0.45)

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 1

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.value
                                                    color: modelData.color
                                                    font.family: root.uiFont
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: modelData.label
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Style.space(8)

                                    Rectangle {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 52
                                        radius: 9
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: omaState.lifetimeAverageWordsPerActiveDay().toFixed(1)
                                                color: root.vizPrimary
                                                font.family: root.uiFont
                                                font.pixelSize: 14
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "AVG WORDS / ACTIVE DAY"
                                                color: Color.muted
                                                font.family: root.uiFont
                                                font.pixelSize: 7
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 52
                                        radius: 9
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: omaState.wordsPerTypingHour() > 0
                                                    ? Math.round(omaState.wordsPerTypingHour()).toLocaleString()
                                                    : "0"
                                                color: root.vizSecondary
                                                font.family: root.uiFont
                                                font.pixelSize: 14
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "WORDS / TYPING HOUR"
                                                color: Color.muted
                                                font.family: root.uiFont
                                                font.pixelSize: 7
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "KEYBOARD"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Rectangle {
                                    id: keyboardPanel
                                    width: parent.width
                                    height: 150
                                    radius: 10
                                    color: Color.popups.background
                                    border.width: 1
                                    border.color: Color.popups.border

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 12
                                        spacing: 4

                                        Repeater {
                                            model: [
                                                ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
                                                ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
                                                ["Z", "X", "C", "V", "B", "N", "M"]
                                            ]

                                            delegate: Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 3

                                                Repeater {
                                                    model: modelData

                                                    delegate: Rectangle {
                                                        width: 30
                                                        height: 24
                                                        radius: 5

                                                        property color rowColor: index === 0 ? root.vizPrimary : (index === 1 ? root.vizSecondary : root.vizTertiary)
                                                        property real count: omaState.keyCount(modelData)
                                                        property real maxCount:
                                                            omaState.mostUsedKeys(1).length
                                                                ? omaState.mostUsedKeys(1)[0].count
                                                                : 1
                                                        property real ratio:
                                                            maxCount > 0
                                                                ? Math.min(1, count / maxCount)
                                                                : 0

                                                        color: Qt.rgba(
                                                            rowColor.r,
                                                            rowColor.g,
                                                            rowColor.b,
                                                            0.04 + ratio * 0.58
                                                        )
                                                        border.width: 1
                                                        border.color: Qt.rgba(
                                                            rowColor.r,
                                                            rowColor.g,
                                                            rowColor.b,
                                                            0.18 + ratio * 0.62
                                                        )

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: Color.popups.text
                                                            font.family: root.uiFont
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                        }

                                                        MouseArea {
                                                            id: keyMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                        }

                                                        Rectangle {
                                                            visible: keyMouse.containsMouse
                                                            z: 100
                                                            width: 136
                                                            height: 48
                                                            radius: 7
                                                            x: {
                                                                const point = parent.mapToItem(keyboardPanel, 0, 0).x
                                                                const desired = point - width - 10
                                                                const clamped = Math.max(4, Math.min(keyboardPanel.width - width - 4, desired))
                                                                return clamped - point
                                                            }
                                                            y: {
                                                                const point = parent.mapToItem(keyboardPanel, 0, 0).y
                                                                const desired = point - height - 8
                                                                const clamped = Math.max(4, Math.min(keyboardPanel.height - height - 4, desired))
                                                                return clamped - point
                                                            }
                                                            color: Color.popups.background
                                                            border.width: 1
                                                            border.color: rowColor

                                                            Column {
                                                                anchors.centerIn: parent
                                                                spacing: 1

                                                                Text {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    text: root.keyDisplayLabel(modelData) + "  •  " + omaState.keyCount(modelData).toLocaleString()
                                                                    color: rowColor
                                                                    font.family: root.uiFont
                                                                    font.pixelSize: 9
                                                                    font.bold: true
                                                                }

                                                                Text {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    text: omaState.lifetimeKeyPresses() > 0
                                                                        ? (omaState.keyCount(modelData) / omaState.lifetimeKeyPresses() * 100).toFixed(1) + "% of all keys"
                                                                        : "No presses yet"
                                                                    color: Color.muted
                                                                    font.family: root.uiFont
                                                                    font.pixelSize: 7
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Style.space(8)

                                    Rectangle {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 52
                                        radius: 9
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: omaState.mostUsedKeys(1).length
                                                    ? omaState.mostUsedKeys(1)[0].key
                                                    : "—"
                                                color: Color.accent
                                                font.family: root.uiFont
                                                font.pixelSize: 16
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "MOST USED KEY"
                                                color: Color.muted
                                                font.family: root.uiFont
                                                font.pixelSize: 7
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 52
                                        radius: 9
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 1

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: omaState.backspaceRate().toFixed(1) + "%"
                                                color: root.vizSecondary
                                                font.family: root.uiFont
                                                font.pixelSize: 15
                                                font.bold: true
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "BS RATE"
                                                color: Color.muted
                                                font.family: root.uiFont
                                                font.pixelSize: 7
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "KEY FREQUENCY"
                                    color: root.vizTertiary
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Text {
                                    visible: omaState.lifetimeKeyPresses() <= 0
                                    width: parent.width
                                    text: "No key data yet — type while OmaVibes is tracking."
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                }

                                Column {
                                    width: parent.width
                                    spacing: 5
                                    visible: omaState.lifetimeKeyPresses() > 0

                                    Repeater {
                                        model: omaState.mostUsedKeys(8)

                                        delegate: Row {
                                            width: parent.width
                                            height: 17
                                            spacing: 6

                                            Text {
                                                width: 46
                                                text: root.keyDisplayLabel(modelData.key)
                                                color: root.vizColor(index)
                                                font.family: root.uiFont
                                                font.pixelSize: 10
                                                font.bold: true
                                            }

                                            Rectangle {
                                                width: parent.width - 116
                                                height: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                                radius: 4
                                                color: Qt.rgba(
                                                    Color.popups.text.r,
                                                    Color.popups.text.g,
                                                    Color.popups.text.b,
                                                    0.07
                                                )

                                                Rectangle {
                                                    width: parent.width * (
                                                        modelData.count /
                                                        Math.max(
                                                            1,
                                                            omaState.mostUsedKeys(1).length
                                                                ? omaState.mostUsedKeys(1)[0].count
                                                                : 1
                                                        )
                                                    )
                                                    height: parent.height
                                                    radius: 4
                                                    color: root.vizColor(index)
                                                }
                                            }

                                            Text {
                                                width: 62
                                                horizontalAlignment: Text.AlignRight
                                                text: Number(modelData.count).toLocaleString()
                                                color: Color.popups.text
                                                font.family: root.uiFont
                                                font.pixelSize: 8
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "KEY FREQUENCY MAP"
                                    color: root.vizTertiary
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Text {
                                    visible: omaState.lifetimeKeyPresses() <= 0
                                    width: parent.width
                                    text: "No key data yet — type while OmaVibes is tracking."
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    id: keyScatterChart
                                    visible: omaState.lifetimeKeyPresses() > 0
                                    property var points: omaState.mostUsedKeys(40)
                                    property int pointCount: points.length
                                    width: parent.width
                                    height: 190
                                    radius: 10
                                    color: Color.popups.background
                                    border.width: 1
                                    border.color: Color.popups.border

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.top: parent.top
                                        anchors.topMargin: 7
                                        text: "presses"
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 7
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 7
                                        text: "least used ← most used"
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 7
                                    }

                                    Rectangle {
                                        id: keyScatterPlotArea
                                        x: 10
                                        y: 24
                                        width: parent.width - 20
                                        height: parent.height - 48
                                        color: "transparent"

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: root.tint(Color.popups.text, 0.16)
                                        }

                                        Repeater {
                                            model: keyScatterChart.points

                                            delegate: Rectangle {
                                                property real topCount: omaState.mostUsedKeys(1).length
                                                    ? omaState.mostUsedKeys(1)[0].count
                                                    : 1
                                                property real fraction: topCount > 0
                                                    ? Number(modelData.count) / topCount
                                                    : 0
                                                property color pointColor: root.vizColor(index)

                                                width: 12 + Math.min(10, fraction * 10)
                                                height: width
                                                radius: width / 2
                                                color: pointColor
                                                border.width: 1
                                                border.color: root.tint(pointColor, 0.82)
                                                // Most-used keys are on the RIGHT; least-used on the LEFT.
                                                x: keyScatterChart.pointCount <= 1
                                                    ? (parent.width - width) / 2
                                                    : 6 + ((keyScatterChart.pointCount - 1 - index) / (keyScatterChart.pointCount - 1)) * Math.max(1, parent.width - 12 - width)
                                                y: Math.max(5, parent.height - 8 - (fraction * (parent.height - width - 10)))
                                                z: keyPointMouse.containsMouse ? 10 : 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.keyDisplayLabel(modelData.key)
                                                    color: Color.popups.background
                                                    font.family: root.uiFont
                                                    font.pixelSize: width >= 18 ? 6 : 5
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    id: keyPointMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                Rectangle {
                                                    visible: keyPointMouse.containsMouse
                                                    width: 150
                                                    height: 49
                                                    radius: 7
                                                    // Keep the tooltip inside the scatter plot area.
                                                    // Prefer the left/above side, then clamp to the plot bounds.
                                                    x: {
                                                        const pointX = parent.x
                                                        const desired = pointX - width - 10
                                                        const clamped = Math.max(4, Math.min(keyScatterPlotArea.width - width - 4, desired))
                                                        return clamped - pointX
                                                    }
                                                    y: {
                                                        const pointY = parent.y
                                                        const desired = pointY - height - 8
                                                        const clamped = Math.max(4, Math.min(keyScatterPlotArea.height - height - 4, desired))
                                                        return clamped - pointY
                                                    }
                                                    color: Color.popups.background
                                                    border.width: 1
                                                    border.color: pointColor
                                                    z: 50

                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 1

                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: root.keyDisplayLabel(modelData.key)
                                                            color: pointColor
                                                            font.family: root.uiFont
                                                            font.pixelSize: 9
                                                            font.bold: true
                                                        }

                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: Number(modelData.count).toLocaleString() + " presses"
                                                            color: Color.popups.text
                                                            font.family: root.uiFont
                                                            font.pixelSize: 8
                                                        }

                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: omaState.lifetimeKeyPresses() > 0
                                                                ? (Number(modelData.count) / omaState.lifetimeKeyPresses() * 100).toFixed(1) + "% of all keys"
                                                                : ""
                                                            color: Color.muted
                                                            font.family: root.uiFont
                                                            font.pixelSize: 7
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── WORDS BAR CHART ──
                            Column {
                                width: parent.width
                                spacing: Style.space(6)

                                Text {
                                    text: "WORDS TYPED"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    id: wordsChart

                                    width: parent.width
                                    height: 150

                                    readonly property var series:
                                        omaState.analyticsWordsSeries(root.analyticsGraphView)

                                    readonly property real maxValue:
                                        wordsChart.series.reduce(
                                            function(maximum, item) {
                                                return Math.max(maximum, Number(item.value) || 0)
                                            },
                                            1
                                        )

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: Color.popups.border
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.bottomMargin: 10
                                        spacing: Style.space(4)

                                        Repeater {
                                            model: wordsChart.series

                                            delegate: Item {
                                                width:
                                                    (wordsChart.width -
                                                     (wordsChart.series.length - 1) * Style.space(4))
                                                    / wordsChart.series.length
                                                height: wordsChart.height - 10

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    width: Math.max(5, parent.width * 0.48)
                                                    height:
                                                        modelData.value > 0
                                                            ? Math.max(
                                                                3,
                                                                (parent.height - 24) *
                                                                (Number(modelData.value) / wordsChart.maxValue)
                                                              )
                                                            : 2

                                                    radius: 3
                                                    color:
                                                        modelData.isToday
                                                            ? root.vizSecondary
                                                            : (Number(modelData.value) > 0
                                                                ? root.vizPrimary
                                                                : Color.popups.border)
                                                }

                                                Text {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter

                                                    text: modelData.label
                                                    color:
                                                        modelData.isToday
                                                            ? Color.popups.text
                                                            : Color.muted

                                                    font.family: root.uiFont
                                                    font.pixelSize: 9
                                                    font.bold: modelData.isToday
                                                }

                                                Text {
                                                    visible: modelData.value > 0
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: 22
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter

                                                    text:
                                                        Number(modelData.value).toLocaleString()

                                                    color: root.vizNeutral
                                                    font.family: root.uiFont
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    id: wordsHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                Rectangle {
                                                    visible: wordsHover.containsMouse
                                                    z: 20
                                                    width: wordsTooltipText.implicitWidth + 16
                                                    height: 24
                                                    radius: 4
                                                    color: Color.popups.background
                                                    border.width: 1
                                                    border.color: Color.popups.border
                                                    x: {
                                                        const cursorX = wordsHover.mapToItem(wordsChart, wordsHover.mouseX, 0).x
                                                        const itemX = parent.mapToItem(wordsChart, 0, 0).x
                                                        const desired = cursorX - width - 10
                                                        const clamped = Math.max(4, Math.min(wordsChart.width - width - 4, desired))
                                                        return clamped - itemX
                                                    }
                                                    y: {
                                                        const cursorY = wordsHover.mapToItem(wordsChart, 0, wordsHover.mouseY).y
                                                        const itemY = parent.mapToItem(wordsChart, 0, 0).y
                                                        const desired = cursorY - height - 8
                                                        const clamped = Math.max(4, Math.min(wordsChart.height - height - 4, desired))
                                                        return clamped - itemY
                                                    }

                                                    Text {
                                                        id: wordsTooltipText
                                                        anchors.centerIn: parent
                                                        text: root.analyticsWordsTooltip(modelData)
                                                        color: Color.popups.text
                                                        font.family: root.uiFont
                                                        font.pixelSize: 9
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: wordsChart.series.every(function(item) {
                                            return Number(item.value) === 0
                                        })

                                        text: "No typing data for this period"
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── TYPING TREND LINE ──
                            Column {
                                width: parent.width
                                spacing: Style.space(6)

                                Text {
                                    text: "TYPING TIME TREND"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    id: typingLineChart

                                    width: parent.width
                                    height: 135

                                    readonly property var series:
                                        omaState.analyticsTypingSeries(root.analyticsGraphView)

                                    property int hoverIndex: -1

                                    Canvas {
                                        id: typingCanvas

                                        anchors.fill: parent

                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)

                                            const left = 6
                                            const right = width - 6
                                            const top = 8
                                            const bottom = height - 22
                                            const chartW = right - left
                                            const chartH = bottom - top

                                            const values = typingLineChart.series.map(
                                                function(item) {
                                                    return Number(item.value) || 0
                                                }
                                            )

                                            let maxValue = values.reduce(
                                                function(maximum, value) {
                                                    return Math.max(maximum, value)
                                                },
                                                1
                                            )

                                            ctx.strokeStyle = String(Color.popups.border)
                                            ctx.lineWidth = 1

                                            for (let i = 0; i < 3; i++) {
                                                const y = top + (chartH * i / 2)
                                                ctx.beginPath()
                                                ctx.moveTo(left, y)
                                                ctx.lineTo(right, y)
                                                ctx.stroke()
                                            }

                                            ctx.strokeStyle = String(root.vizPrimary)
                                            ctx.lineWidth = 2
                                            ctx.beginPath()

                                            for (let i = 0; i < values.length; i++) {
                                                const x =
                                                    values.length === 1
                                                        ? left + chartW / 2
                                                        : left + chartW * i / (values.length - 1)

                                                const y =
                                                    bottom -
                                                    chartH * (values[i] / maxValue)

                                                if (i === 0)
                                                    ctx.moveTo(x, y)
                                                else
                                                    ctx.lineTo(x, y)
                                            }

                                            ctx.stroke()

                                            ctx.fillStyle = String(root.vizPrimary)

                                            for (let i = 0; i < values.length; i++) {
                                                const x =
                                                    values.length === 1
                                                        ? left + chartW / 2
                                                        : left + chartW * i / (values.length - 1)

                                                const y =
                                                    bottom -
                                                    chartH * (values[i] / maxValue)

                                                ctx.fillStyle = String(
                                                    typingLineChart.series[i].isToday
                                                        ? root.vizSecondary
                                                        : root.vizPrimary
                                                )
                                                ctx.beginPath()
                                                ctx.arc(x, y, 3, 0, Math.PI * 2)
                                                ctx.fill()
                                            }

                                            ctx.fillStyle = String(Color.muted)
                                            ctx.font = "9px " + String(root.uiFont)

                                            for (let i = 0; i < typingLineChart.series.length; i++) {
                                                const x =
                                                    values.length === 1
                                                        ? left + chartW / 2
                                                        : left + chartW * i / (values.length - 1)

                                                ctx.textAlign = "center"
                                                ctx.fillText(
                                                    typingLineChart.series[i].label,
                                                    x,
                                                    height - 5
                                                )
                                            }

                                            if (values.every(function(value) { return value === 0 })) {
                                                ctx.fillStyle = String(Color.muted)
                                                ctx.textAlign = "center"
                                                ctx.fillText(
                                                    "No typing data for this period",
                                                    width / 2,
                                                    height / 2
                                                )
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: typingHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onPositionChanged: function(mouse) {
                                            const count = typingLineChart.series.length
                                            if (count <= 0) {
                                                typingLineChart.hoverIndex = -1
                                                return
                                            }
                                            const left = 6
                                            const right = width - 6
                                            const ratio = Math.max(0, Math.min(1, (mouse.x - left) / Math.max(1, right - left)))
                                            typingLineChart.hoverIndex = Math.max(0, Math.min(count - 1, Math.round(ratio * (count - 1))))
                                        }
                                        onExited: typingLineChart.hoverIndex = -1
                                    }

                                    Rectangle {
                                        visible: typingLineChart.hoverIndex >= 0
                                        z: 25
                                        width: typingTooltipText.implicitWidth + 16
                                        height: 28
                                        radius: 4
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border
                                        x: {
                                            if (typingLineChart.hoverIndex < 0) return 0
                                            const count = typingLineChart.series.length
                                            const left = 6
                                            const right = typingLineChart.width - 6
                                            const pointX = count <= 1 ? typingLineChart.width / 2 : left + (right - left) * typingLineChart.hoverIndex / (count - 1)
                                            return Math.max(0, Math.min(typingLineChart.width - width, pointX - width / 2))
                                        }
                                        y: 1

                                        Text {
                                            id: typingTooltipText
                                            anchors.centerIn: parent
                                            text: typingLineChart.hoverIndex < 0
                                                ? ""
                                                : String(typingLineChart.series[typingLineChart.hoverIndex].label) + "  •  " +
                                                  omaState.formatDurationPrecise(typingLineChart.series[typingLineChart.hoverIndex].value)
                                            color: Color.popups.text
                                            font.family: root.uiFont
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── TYPING VS IDLE DONUT ──
                            Row {
                                width: parent.width
                                spacing: Style.space(14)

                                Item {
                                    width: 125
                                    height: 125

                                    Canvas {
                                        id: donutCanvas
                                        anchors.fill: parent

                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)

                                            const centerX = width / 2
                                            const centerY = height / 2
                                            const radius = 48
                                            const lineWidth = 16

                                            const stats =
                                                omaState.analyticsPeriodStats(
                                                    root.analyticsGraphView
                                                )

                                            const typing = Math.max(0, Number(stats.typingSeconds) || 0)
                                            const idle = Math.max(0, Number(stats.idleSeconds) || 0)
                                            const total = typing + idle

                                            ctx.lineWidth = lineWidth

                                            if (total > 0) {
                                                const typingAngle =
                                                    (typing / total) * Math.PI * 2

                                                const idleAngle =
                                                    (idle / total) * Math.PI * 2

                                                ctx.strokeStyle = String(root.vizSecondary)
                                                ctx.beginPath()
                                                ctx.arc(
                                                    centerX,
                                                    centerY,
                                                    radius,
                                                    -Math.PI / 2 + typingAngle,
                                                    -Math.PI / 2 + typingAngle + idleAngle
                                                )
                                                ctx.stroke()

                                                ctx.strokeStyle = String(root.vizPrimary)
                                                ctx.beginPath()
                                                ctx.arc(
                                                    centerX,
                                                    centerY,
                                                    radius,
                                                    -Math.PI / 2,
                                                    -Math.PI / 2 + typingAngle
                                                )
                                                ctx.stroke()
                                            } else {
                                                ctx.strokeStyle = String(Color.popups.border)
                                                ctx.beginPath()
                                                ctx.arc(
                                                    centerX,
                                                    centerY,
                                                    radius,
                                                    0,
                                                    Math.PI * 2
                                                )
                                                ctx.stroke()
                                            }

                                            ctx.fillStyle = String(Color.popups.text)
                                            ctx.font = "bold 16px " + String(root.uiFont)
                                            ctx.textAlign = "center"
                                            ctx.fillText(
                                                omaState.formatDurationPrecise(typing + idle),
                                                centerX,
                                                centerY + 5
                                            )
                                        }
                                    }

                                    MouseArea {
                                        id: donutHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    Rectangle {
                                        visible: donutHover.containsMouse
                                        z: 20
                                        width: donutTooltipText.implicitWidth + 16
                                        height: 44
                                        radius: 4
                                        color: Color.popups.background
                                        border.width: 1
                                        border.color: Color.popups.border
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 0

                                        Text {
                                            id: donutTooltipText
                                            anchors.centerIn: parent
                                            readonly property var stats: omaState.analyticsPeriodStats(root.analyticsGraphView)
                                            text: "Typing " + omaState.formatDurationPrecise(stats.typingSeconds) + "\nIdle " + omaState.formatDurationPrecise(stats.idleSeconds)
                                            color: Color.popups.text
                                            font.family: root.uiFont
                                            font.pixelSize: 9
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Style.space(4)

                                    Text {
                                        text: "TYPING VS IDLE"
                                        color: Color.muted
                                        font.family: root.uiFont
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Text {
                                        readonly property var stats:
                                            omaState.analyticsPeriodStats(
                                                root.analyticsGraphView
                                            )

                                        text:
                                            "Typing   " +
                                            omaState.formatDuration(stats.typingSeconds)

                                        color: root.vizPrimary
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        readonly property var stats:
                                            omaState.analyticsPeriodStats(
                                                root.analyticsGraphView
                                            )

                                        text:
                                            "Idle     " +
                                            omaState.formatDuration(stats.idleSeconds)

                                        color: root.vizSecondary
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        readonly property var stats:
                                            omaState.analyticsPeriodStats(
                                                root.analyticsGraphView
                                            )

                                        text:
                                            stats.typingPercent.toFixed(0) + "% typing"
                                        color: root.vizPrimary
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── TYPING / IDLE BY PERIOD ──
                            Column {
                                width: parent.width
                                spacing: Style.space(6)

                                Text {
                                    text: "TYPING ACTIVITY"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    id: activityChart

                                    width: parent.width
                                    height: 120

                                    readonly property var series:
                                        omaState.analyticsActivitySeries(root.analyticsGraphView)

                                    readonly property real maxValue:
                                        activityChart.series.reduce(
                                            function(maximum, item) {
                                                return Math.max(
                                                    maximum,
                                                    Number(item.typingSeconds) +
                                                    Number(item.idleSeconds)
                                                )
                                            },
                                            1
                                        )

                                    Row {
                                        anchors.fill: parent
                                        anchors.bottomMargin: 16
                                        spacing: Style.space(4)

                                        Repeater {
                                            model: activityChart.series

                                            delegate: Item {
                                                width:
                                                    (activityChart.width -
                                                     (activityChart.series.length - 1) * Style.space(4))
                                                    / activityChart.series.length
                                                height: activityChart.height - 16

                                                Rectangle {
                                                    anchors.bottom: parent.bottom
                                                    anchors.horizontalCenter: parent.horizontalCenter

                                                    width: Math.max(7, parent.width * 0.56)

                                                    height:
                                                        Math.max(
                                                            2,
                                                            (parent.height - 20) *
                                                            (
                                                                (
                                                                    Number(modelData.typingSeconds) +
                                                                    Number(modelData.idleSeconds)
                                                                ) /
                                                                activityChart.maxValue
                                                            )
                                                        )

                                                    radius: 3
                                                    color: root.vizSecondary

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom

                                                        height:
                                                            parent.height *
                                                            (
                                                                Number(modelData.typingSeconds) /
                                                                Math.max(
                                                                    1,
                                                                    Number(modelData.typingSeconds) +
                                                                    Number(modelData.idleSeconds)
                                                                )
                                                            )

                                                        radius: 3
                                                        color: root.vizPrimary
                                                    }
                                                }

                                                Text {
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: 12
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: omaState.formatDurationPrecise(Number(modelData.typingSeconds) + Number(modelData.idleSeconds))
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 8
                                                }

                                                Text {
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter

                                                    text: modelData.label
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 9
                                                }

                                                MouseArea {
                                                    id: activityHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                }

                                                Rectangle {
                                                    visible: activityHover.containsMouse
                                                    z: 20
                                                    width: activityTooltipText.implicitWidth + 16
                                                    height: 44
                                                    radius: 4
                                                    color: Color.popups.background
                                                    border.width: 1
                                                    border.color: Color.popups.border
                                                    x: {
                                                        const cursorX = activityHover.mapToItem(activityChart, activityHover.mouseX, 0).x
                                                        const itemX = parent.mapToItem(activityChart, 0, 0).x
                                                        const desired = cursorX - width - 10
                                                        const clamped = Math.max(4, Math.min(activityChart.width - width - 4, desired))
                                                        return clamped - itemX
                                                    }
                                                    y: {
                                                        const cursorY = activityHover.mapToItem(activityChart, 0, activityHover.mouseY).y
                                                        const itemY = parent.mapToItem(activityChart, 0, 0).y
                                                        const desired = cursorY - height - 8
                                                        const clamped = Math.max(4, Math.min(activityChart.height - height - 4, desired))
                                                        return clamped - itemY
                                                    }

                                                    Text {
                                                        id: activityTooltipText
                                                        anchors.centerIn: parent
                                                        text: "Typing " + omaState.formatDurationPrecise(modelData.typingSeconds) + "\nIdle " + omaState.formatDurationPrecise(modelData.idleSeconds)
                                                        color: Color.popups.text
                                                        font.family: root.uiFont
                                                        font.pixelSize: 9
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── WORDS HEATMAP ──
                            Column {
                                width: parent.width
                                spacing: Style.space(6)

                                Text {
                                    text: "WORDS HEATMAP"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Text {
                                    text: omaState.analyticsHeatmapMonth(omaState.analyticsAnchor).monthLabel
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                }

                                Item {
                                    id: heatmapGrid
                                    width: parent.width
                                    height: 190

                                    readonly property var heatmap:
                                        omaState.analyticsHeatmapMonth(omaState.analyticsAnchor)

                                    function weekLabel(week) {
                                        for (let i = 0; i < week.length; ++i) {
                                            if (week[i].inMonth) {
                                                const p = String(week[i].key).split("-")
                                                return p.length === 3 ? String(Number(p[2])) : ""
                                            }
                                        }
                                        return ""
                                    }

                                    Column {
                                        anchors.fill: parent
                                        spacing: 4

                                        Row {
                                            width: parent.width
                                            height: 16
                                            spacing: 4

                                            Item { width: 30; height: 1 }

                                            Repeater {
                                                model: heatmapGrid.heatmap.weeks

                                                delegate: Item {
                                                    width: 24
                                                    height: 16

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: heatmapGrid.weekLabel(modelData)
                                                        color: root.vizMuted
                                                        font.family: root.uiFont
                                                        font.pixelSize: 8
                                                    }
                                                }
                                            }
                                        }

                                        Repeater {
                                            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                                            delegate: Row {
                                                property int rowIndex: index
                                                width: parent.width
                                                height: 22
                                                spacing: 4

                                                Text {
                                                    width: 30
                                                    height: parent.height
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: modelData
                                                    color: Color.muted
                                                    font.family: root.uiFont
                                                    font.pixelSize: 8
                                                }

                                                Repeater {
                                                    model: heatmapGrid.heatmap.weeks

                                                    delegate: Item {
                                                        width: 24
                                                        height: 22

                                                        readonly property var cell: modelData[rowIndex]

                                                        Rectangle {
                                                            width: 18
                                                            height: 18
                                                            anchors.centerIn: parent
                                                            radius: 3
                                                            visible: cell.inMonth

                                                            color: root.vizPrimary
                                                            opacity:
                                                                cell.words > 0
                                                                    ? 0.18 +
                                                                      0.82 * Math.sqrt(
                                                                          cell.words /
                                                                          Math.max(
                                                                              1,
                                                                              heatmapGrid.heatmap.maxWords
                                                                          )
                                                                      )
                                                                    : 0.06
                                                        }

                                                        Rectangle {
                                                            width: 18
                                                            height: 18
                                                            anchors.centerIn: parent
                                                            radius: 3
                                                            visible: cell.inMonth && cell.isToday
                                                            color: "transparent"
                                                            border.width: 1
                                                            border.color: root.vizSecondary
                                                        }

                                                        MouseArea {
                                                            id: heatmapHover
                                                            anchors.fill: parent
                                                            enabled: cell.inMonth
                                                            hoverEnabled: true
                                                        }

                                                        Rectangle {
                                                            visible: heatmapHover.containsMouse
                                                            z: 30
                                                            width: heatmapTooltipText.implicitWidth + 14
                                                            height: 34
                                                            radius: 4
                                                            color: Color.popups.background
                                                            border.width: 1
                                                            border.color: root.vizSecondary
                                                            x: {
                                                                const cursorX = heatmapHover.mapToItem(heatmapGrid, heatmapHover.mouseX, 0).x
                                                                const itemX = parent.mapToItem(heatmapGrid, 0, 0).x
                                                                const desired = cursorX - width - 10
                                                                const clamped = Math.max(4, Math.min(heatmapGrid.width - width - 4, desired))
                                                                return clamped - itemX
                                                            }
                                                            y: {
                                                                const cursorY = heatmapHover.mapToItem(heatmapGrid, 0, heatmapHover.mouseY).y
                                                                const itemY = parent.mapToItem(heatmapGrid, 0, 0).y
                                                                const desired = cursorY - height - 8
                                                                const clamped = Math.max(4, Math.min(heatmapGrid.height - height - 4, desired))
                                                                return clamped - itemY
                                                            }

                                                            Text {
                                                                id: heatmapTooltipText
                                                                anchors.centerIn: parent
                                                                text:
                                                                    cell.key + "\n" +
                                                                    Number(cell.words).toLocaleString() +
                                                                    " words"
                                                                color: Color.popups.text
                                                                font.family: root.uiFont
                                                                font.pixelSize: 8
                                                                horizontalAlignment: Text.AlignHCenter
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── CONSISTENCY ──
                            Column {
                                id: consistencySection
                                width: parent.width
                                spacing: Style.space(7)

                                Text {
                                    text: "CONSISTENCY"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                readonly property var stats:
                                    omaState.analyticsConsistencyStats(root.analyticsGraphView)

                                Row {
                                    width: parent.width
                                    spacing: Style.space(8)

                                    Item {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 38

                                        Text {
                                            anchors.top: parent.top
                                            text: "ACTIVE DAYS"
                                            color: Color.muted
                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            text: consistencySection.stats.activeDays + " / " + consistencySection.stats.totalDays
                                            color: Color.popups.text
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    Item {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 38

                                        Text {
                                            anchors.top: parent.top
                                            text: "LONGEST STREAK"
                                            color: Color.muted
                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            text: consistencySection.stats.longestStreak + " day" + (consistencySection.stats.longestStreak === 1 ? "" : "s")
                                            color: Color.popups.text
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Style.space(8)

                                    Item {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 38

                                        Text {
                                            anchors.top: parent.top
                                            text: "DAILY AVERAGE"
                                            color: Color.muted
                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            text: consistencySection.stats.dailyAverage.toFixed(1) + " words"
                                            color: Color.popups.text
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }

                                    Item {
                                        width: (parent.width - Style.space(8)) / 2
                                        height: 38

                                        Text {
                                            anchors.top: parent.top
                                            text: "BEST DAY"
                                            color: Color.muted
                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            text: (consistencySection.stats.bestDate || "—") + " · " + consistencySection.stats.bestWords
                                            color: root.vizTertiary
                                            font.family: root.uiFont
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Color.popups.border
                            }

                            // ── TRACKING ──
                            Column {
                                width: parent.width
                                spacing: Style.space(7)

                                Text {
                                    text: "TRACKING"
                                    color: Color.muted
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    width: parent.width
                                    height: 22

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter

                                        border.width: 1
                                        border.color: root.vizPrimary

                                        color:
                                            omaState.trackingMode === "onlyWhenSound"
                                                ? root.vizPrimary
                                                : "transparent"
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 22
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: "Only when sound effects are enabled"

                                        color: Color.popups.text
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: omaState.setTrackingMode("onlyWhenSound")
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 22

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7

                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter

                                        border.width: 1
                                        border.color: root.vizPrimary

                                        color:
                                            omaState.trackingMode === "always"
                                                ? root.vizSecondary
                                                : "transparent"
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 22
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: "Whenever OmaVibes is enabled"

                                        color: Color.popups.text
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: omaState.setTrackingMode("always")
                                    }
                                }

                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap

                                    text:
                                        "Analytics stay on this device. " +
                                        "Typed content is never stored."

                                    color: Color.muted
                                    opacity: 0.85

                                    font.family: root.uiFont
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }

                             }

                Connections {
                    target: omaState

                    function onDailyWordsChanged() {
                        typingCanvas.requestPaint()
                        donutCanvas.requestPaint()
                    }

                    function onDailyTypingSecondsChanged() {
                        typingCanvas.requestPaint()
                        donutCanvas.requestPaint()
                    }

                    function onDailyTrackedSecondsChanged() {
                        donutCanvas.requestPaint()
                    }

                    function onAnalyticsAnchorChanged() {
                        typingCanvas.requestPaint()
                        donutCanvas.requestPaint()
                    }
                }

Connections {
    target: root

    function onAnalyticsGraphViewChanged() {
        typingCanvas.requestPaint()
        donutCanvas.requestPaint()
    }
}
                }
            }
        }
    }
