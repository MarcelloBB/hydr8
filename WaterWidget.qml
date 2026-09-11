import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
    id: root

    property var bar
    property var settings: ({})

    readonly property string dataDir: Quickshell.env("HOME") + "/.local/share/hydr8"
    readonly property string dataPath: dataDir + "/water.json"

    property string today: ""
    property int totalMl: 0
    property int goalMl: 2500
    property int reminderMinutes: 60
    property bool remindersEnabled: true
    property double lastDrinkAt: 0
    property var entries: []
    property bool loaded: false
    property bool popupOpen: false

    readonly property real progress: goalMl > 0 ? Math.min(1, totalMl / goalMl) : 0
    readonly property int remainingMl: Math.max(0, goalMl - totalMl)

    implicitWidth: 32
    implicitHeight: bar.barSize

    function dateKey() {
        var d = new Date()
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    function formatLiters(ml) {
        if (ml >= 1000)
            return (ml / 1000).toFixed(2).replace(/\.?0+$/, "") + " L"
        return ml + " ml"
    }

    function formatNextReminder() {
        if (!remindersEnabled || lastDrinkAt <= 0)
            return "disabled"

        var remaining = Math.max(
            0,
            reminderMinutes * 60 * 1000 - (Date.now() - lastDrinkAt)
        )
        var minutes = Math.ceil(remaining / 60000)
        if (minutes <= 0)
            return "now"
        if (minutes < 60)
            return minutes + " min"
        var hours = Math.floor(minutes / 60)
        var mins = minutes % 60
        return mins === 0 ? hours + " h" : hours + " h " + mins + " min"
    }

    function resetForToday() {
        totalMl = 0
        entries = []
        lastDrinkAt = 0
        today = dateKey()
        persist()
    }

    function ensureToday() {
        var current = dateKey()
        if (today !== current) {
            totalMl = 0
            entries = []
            lastDrinkAt = 0
            today = current
            persist()
        }
    }

    function loadData() {
        var raw = dataFile.text()
        if (!raw || raw.trim() === "") {
            today = dateKey()
            persist()
            loaded = true
            return
        }

        try {
            var data = JSON.parse(raw)
            today = data.date || dateKey()
            goalMl = Number(data.goalMl || 2500)
            reminderMinutes = Number(data.reminderMinutes || 60)
            remindersEnabled = data.remindersEnabled !== false
            totalMl = Number(data.totalMl || 0)
            lastDrinkAt = Number(data.lastDrinkAt || 0)
            entries = Array.isArray(data.entries) ? data.entries : []
        } catch (e) {
            console.warn("hydr8: invalid data, starting fresh:", e)
            today = dateKey()
            totalMl = 0
            entries = []
            lastDrinkAt = 0
        }

        ensureToday()
        loaded = true
    }

    function persist() {
        if (!loaded)
            return

        var data = {
            date: today || dateKey(),
            goalMl: goalMl,
            reminderMinutes: reminderMinutes,
            remindersEnabled: remindersEnabled,
            totalMl: totalMl,
            lastDrinkAt: lastDrinkAt,
            entries: entries
        }

        dataFile.setText(JSON.stringify(data, null, 2))
    }

    function addWater(amountMl) {
        ensureToday()

        var now = Date.now()
        entries.push({
            amountMl: amountMl,
            timestamp: now
        })
        totalMl += amountMl
        lastDrinkAt = now
        persist()

        if (totalMl >= goalMl)
            sendNotification("Daily goal reached", "You reached " + formatLiters(totalMl) + " today. 󰆫")
    }

    function removeLastWater() {
        if (entries.length === 0)
            return

        var last = entries[entries.length - 1]
        totalMl = Math.max(0, totalMl - Number(last.amountMl || 0))
        entries.pop()
        lastDrinkAt = entries.length > 0 ? Number(entries[entries.length - 1].timestamp || 0) : 0
        persist()
    }

    function sendNotification(title, body) {
        notificationProcess.command = [
            "notify-send",
            "--app-name=hydr8",
            "--icon=dialog-information",
            title,
            body
        ]
        notificationProcess.running = true
    }

    function maybeRemind() {
        if (!loaded || !remindersEnabled || lastDrinkAt <= 0)
            return

        if (totalMl >= goalMl)
            return

        var elapsed = Date.now() - lastDrinkAt
        if (elapsed >= reminderMinutes * 60 * 1000) {
            sendNotification(
                "Time to drink 󰆫",
                "You've gone " + Math.floor(elapsed / 60000) + " min without drinking water."
            )
            lastDrinkAt = Date.now()
            persist()
        }
    }

    FileView {
        id: dataFile
        path: root.dataPath
        atomicWrites: true
        watchChanges: false
        printErrors: false

        onLoaded: root.loadData()
    }

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.dataDir]
        running: true

        onExited: function(exitCode) {
            if (exitCode === 0)
                dataFile.reload()
        }
    }

    Process {
        id: notificationProcess
        running: false
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            ensureToday()
            maybeRemind()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰆫"
            font.family: bar.fontFamily
            font.pixelSize: Math.max(14, bar.barSize - 8)
            color: totalMl >= goalMl ? bar.urgent : bar.foreground
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                popup.visible = !popup.visible
                root.popupOpen = popup.visible
            }

            onEntered: {
                bar.showTooltip(root, root.formatLiters(root.totalMl) + " / " + root.formatLiters(root.goalMl))
            }

            onExited: bar.hideTooltip(root)
        }
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.rect.x: root.width / 2 - width / 2
        anchor.rect.y: root.height + 4
        width: 320
        height: content.implicitHeight + 24
        color: "transparent"
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Color.popups.background
            border.width: 1
            border.color: Color.popups.border

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "󰆫  Water today"
                        color: Color.popups.text
                        font.family: bar.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.formatLiters(root.totalMl)
                        color: root.totalMl >= root.goalMl ? Color.accent : Color.popups.text
                        font.family: bar.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Color.popups.text
                    opacity: 0.12

                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: 4
                        color: Color.accent
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.totalMl >= root.goalMl
                          ? "󰔸  Goal reached!"
                          : root.formatLiters(root.remainingMl) + " left to reach goal"
                    color: Color.popups.text
                    opacity: 0.75
                    font.family: bar.fontFamily
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [150, 250, 500]

                        Button {
                            required property int modelData
                            Layout.fillWidth: true
                            iconText: "󰐗"
                            text: modelData + " ml"
                            foreground: Color.popups.text
                            fontFamily: bar.fontFamily
                            bordered: true

                            onClicked: root.addWater(modelData)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        Layout.fillWidth: true
                        iconText: "󰕌"
                        text: "Undo last"
                        foreground: Color.popups.text
                        fontFamily: bar.fontFamily
                        bordered: true
                        enabled: root.entries.length > 0
                        onClicked: root.removeLastWater()
                    }

                    Button {
                        iconText: "󰜉"
                        text: "Reset"
                        foreground: Color.popups.text
                        fontFamily: bar.fontFamily
                        bordered: true
                        onClicked: root.resetForToday()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Color.popups.text
                    opacity: 0.12
                }

                Text {
                    text: "Settings"
                    color: Color.popups.text
                    font.family: bar.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Goal (ml)"
                        color: Color.popups.text
                        font.family: bar.fontFamily
                        font.pixelSize: 11
                        Layout.preferredWidth: 90
                    }

                    TextField {
                        id: goalField
                        Layout.fillWidth: true
                        text: String(root.goalMl)
                        foreground: Color.popups.text
                        font.family: bar.fontFamily
                        validator: IntValidator { bottom: 250; top: 10000 }

                        onAccepted: {
                            root.goalMl = Number(text)
                            root.persist()
                        }
                    }

                    Button {
                        iconText: "󰆓"
                        text: "Save"
                        foreground: Color.popups.text
                        fontFamily: bar.fontFamily
                        bordered: true
                        onClicked: {
                            root.goalMl = Number(goalField.text)
                            root.persist()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Row {
                        Layout.preferredWidth: 90
                        spacing: 4

                        Text {
                            text: "󰅐"
                            color: Color.popups.text
                            font.family: bar.fontFamily
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Reminder"
                            color: Color.popups.text
                            font.family: bar.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TextField {
                        id: reminderField
                        Layout.fillWidth: true
                        text: String(root.reminderMinutes)
                        foreground: Color.popups.text
                        font.family: bar.fontFamily
                        validator: IntValidator { bottom: 5; top: 360 }

                        onAccepted: {
                            root.reminderMinutes = Number(text)
                            root.persist()
                        }
                    }

                    Text {
                        text: "min"
                        color: Color.popups.text
                        font.family: bar.fontFamily
                        font.pixelSize: 11
                    }

                    Button {
                        iconText: root.remindersEnabled ? "󰂚" : "󰂛"
                        text: root.remindersEnabled ? "On" : "Off"
                        foreground: Color.popups.text
                        fontFamily: bar.fontFamily
                        bordered: true
                        onClicked: {
                            root.remindersEnabled = !root.remindersEnabled
                            root.persist()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Next reminder: " + root.formatNextReminder()
                    color: Color.popups.text
                    opacity: 0.65
                    font.family: bar.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
