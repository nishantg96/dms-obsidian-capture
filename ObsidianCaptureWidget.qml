import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Bar pill showing today's open task count, with a popout listing the
// day's notes and tasks. Reads the same daily note the daemon writes.
PluginComponent {
    id: root

    pluginId: "obsidianCapture"
    pluginService: PluginService

    property var notes: []
    property var tasks: []          // [{text, done}]
    readonly property int openCount: {
        let n = 0;
        for (var i = 0; i < tasks.length; i++)
            if (!tasks[i].done)
                n++;
        return n;
    }

    readonly property string home: Quickshell.env("HOME")
    readonly property string vaultPath: {
        const p = (pluginData.vaultPath || "").trim();
        return p === "" ? home + "/Documents/Vault" : p.replace(/^~/, home);
    }
    readonly property string notesHeading: (pluginData.notesHeading || "Notes").trim()
    readonly property string tasksHeading: (pluginData.tasksHeading || "Tasks").trim()

    function today() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
    }

    readonly property string dailyPath: vaultPath + "/" + today()
        + (pluginData.filenameSuffix !== undefined ? pluginData.filenameSuffix : " daily") + ".md"

    // Parse the note into its two sections. Anything outside them is ignored
    // rather than guessed at — the user may keep their own sections here.
    function parse(body) {
        const out = {"notes": [], "tasks": []};
        let section = "";
        const lines = (body || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.indexOf("## ") === 0) {
                const h = line.substring(3).trim();
                section = (h === notesHeading) ? "notes" : (h === tasksHeading ? "tasks" : "");
                continue;
            }
            const t = line.trim();
            if (t === "" || section === "")
                continue;
            if (section === "tasks") {
                const m = t.match(/^[-*+]\s+\[([ xX])\]\s+(.*)$/);
                if (m)
                    out.tasks.push({
                        "text": m[2],
                        "done": m[1].toLowerCase() === "x",
                        "line": i,        // exact line, so a toggle cannot hit a twin
                        "raw": line
                    });
            } else {
                const m2 = t.match(/^[-*+]\s+(.*)$/);
                out.notes.push({"text": m2 ? m2[1] : t, "line": i, "raw": line});
            }
        }
        return out;
    }

    function refresh() {
        fileReader.createObject(root, {});
    }

    Component {
        id: fileReader
        FileView {
            path: root.dailyPath
            blockLoading: true
            preload: true
            printErrors: false
            onLoaded: {
                const p = root.parse(text());
                root.notes = p.notes;
                root.tasks = p.tasks;
                destroy();
            }
            onLoadFailed: {
                root.notes = [];
                root.tasks = [];
                destroy();
            }
        }
    }

    property bool addAsTask: true       // quick-add mode, remembered across popouts
    property var pendingWrite: null      // {lines:[...]} handed to the writer

    // Flip one checkbox. Re-reads first and refuses if the line moved or
    // changed underneath us — the file is also open in an editor, and
    // silently overwriting someone's edit is worse than doing nothing.
    function toggleTask(task) {
        toggleReader.createObject(root, {"task": task});
    }

    function addLine(kind, text) {
        const t = (text || "").trim();
        if (t === "")
            return;
        addReader.createObject(root, {"kind": kind, "body": t});
    }

    function commit(lines) {
        root.pendingWrite = lines;
        fileWriter.createObject(root, {
            "path": root.dailyPath,
            "content": lines.join("\n").replace(/\n+$/, "") + "\n"
        });
    }

    Component {
        id: toggleReader
        FileView {
            property var task
            path: root.dailyPath
            blockLoading: true
            preload: true
            printErrors: false
            onLoaded: {
                const lines = text().split("\n");
                if (task.line >= lines.length || lines[task.line] !== task.raw) {
                    ToastService.showWarning("Note changed", "Refreshed instead of overwriting.");
                    root.refresh();
                    destroy();
                    return;
                }
                lines[task.line] = task.done
                    ? task.raw.replace(/\[[xX]\]/, "[ ]")
                    : task.raw.replace(/\[ \]/, "[x]");
                root.commit(lines);
                destroy();
            }
            onLoadFailed: destroy()
        }
    }

    Component {
        id: addReader
        FileView {
            property string kind
            property string body
            path: root.dailyPath
            blockLoading: true
            preload: true
            printErrors: false
            onLoaded: {
                const isTask = kind === "task";
                const heading = "## " + (isTask ? root.tasksHeading : root.notesHeading);
                const prefix = isTask
                    ? (root.pluginData.taskPrefix !== undefined ? root.pluginData.taskPrefix : "- [ ] ")
                    : (root.pluginData.notePrefix !== undefined ? root.pluginData.notePrefix : "- ");
                const lines = text().split("\n");
                let start = -1;
                for (var i = 0; i < lines.length; i++)
                    if (lines[i].trim() === heading) {
                        start = i;
                        break;
                    }
                if (start === -1) {
                    lines.push("", heading, prefix + body);
                } else {
                    let end = start + 1;
                    while (end < lines.length && lines[end].indexOf("## ") !== 0)
                        end++;
                    let at = end;
                    while (at > start + 1 && lines[at - 1].trim() === "")
                        at--;
                    lines.splice(at, 0, prefix + body);
                }
                root.commit(lines);
                destroy();
            }
            onLoadFailed: destroy()
        }
    }

    Component {
        id: fileWriter
        FileView {
            property string content
            blockWrites: false
            atomicWrites: true
            Component.onCompleted: setText(content)
            onSaved: {
                root.refresh();
                destroy();
            }
            onSaveFailed: {
                ToastService.showError("Write failed", "Today's note was not changed.");
                destroy();
            }
        }
    }

    Component.onCompleted: refresh()

    // Cheap poll: the file is small and only this user writes it. Also catches
    // edits made in the editor, which no signal would tell us about.
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "edit_note"
                size: Theme.iconSizeSmall
                color: root.openCount > 0 ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.openCount.toString()
                color: root.openCount > 0 ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 0

            DankIcon {
                name: "edit_note"
                size: Theme.iconSizeSmall
                color: root.openCount > 0 ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.openCount.toString()
                color: root.openCount > 0 ? Theme.primary : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 420

    popoutContent: Component {
        FocusScope {
            id: contentFocusScope

            // The popout Loader sizes to implicitHeight. An Item with only
            // anchors.fill and no implicitHeight collapses to zero and renders
            // nothing — which is exactly what happened the first time.
            width: parent ? parent.width : 0
            implicitHeight: mainContent.implicitHeight
            focus: true

            // PluginPopout assigns these on the loaded root so the header's
            // close button actually closes the popout.
            property var closePopout: null
            property var parentPopout: null

            Component.onCompleted: root.refresh()

            PopoutComponent {
                id: mainContent
                width: parent.width
                headerText: root.today()
                detailsText: root.openCount + (root.openCount === 1 ? " task open" : " tasks open")
                showCloseButton: true
                closePopout: contentFocusScope.closePopout
                parentPopout: contentFocusScope.parentPopout

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: root.tasksHeading
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                        visible: root.tasks.length > 0
                    }

                    Repeater {
                        model: root.tasks
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: taskRow.implicitHeight + Theme.spacingS
                            radius: Theme.cornerRadius
                            color: taskArea.containsMouse ? Theme.primaryHoverLight : "transparent"

                            MouseArea {
                                id: taskArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTask(parent.modelData)
                            }

                            Row {
                                id: taskRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingXS
                                anchors.rightMargin: Theme.spacingXS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: parent.parent.modelData.done ? "check_box" : "check_box_outline_blank"
                                    size: Theme.iconSizeSmall
                                    color: parent.parent.modelData.done ? Theme.surfaceVariantText : Theme.primary
                                }

                                StyledText {
                                    width: parent.width - Theme.iconSizeSmall - Theme.spacingS * 2
                                    text: parent.parent.modelData.text
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: parent.parent.modelData.done ? Theme.surfaceVariantText : Theme.surfaceText
                                }
                            }
                        }
                    }

                    StyledText {
                        text: root.notesHeading
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: Theme.surfaceVariantText
                        topPadding: Theme.spacingM
                        visible: root.notes.length > 0
                    }

                    Repeater {
                        model: root.notes
                        StyledText {
                            width: parent.width
                            text: "\u2022  " + modelData.text
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                        }
                    }

                    StyledText {
                        text: "Nothing captured today yet."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        visible: root.notes.length === 0 && root.tasks.length === 0
                    }

                    Item {
                        width: parent.width
                        height: Theme.spacingM
                    }

                    DankTextField {
                        id: quickAdd
                        width: parent.width
                        placeholderText: root.addAsTask ? "Add a task…" : "Add a note…"
                        leftIconName: root.addAsTask ? "check_box_outline_blank" : "edit_note"
                        onAccepted: {
                            root.addLine(root.addAsTask ? "task" : "note", text);
                            text = "";
                        }
                    }

                    // DankToggle does not flip itself — it emits toggled(checked)
                    // and the caller owns the state.
                    DankToggle {
                        width: parent.width
                        text: "Add as task"
                        checked: root.addAsTask
                        onToggled: checked => root.addAsTask = checked
                    }
                }
            }
        }
    }
}
