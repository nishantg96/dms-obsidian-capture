import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.Modals.Common

// Capture a note or a task into today's daily note.
//
//   dms ipc call dmsVault note
//   dms ipc call dmsVault task
//
// Fully self-contained: reads and writes the daily note itself through
// FileView with atomicWrites, so there is no external script to install.
PluginComponent {
    id: root

    pluginId: "dmsVault"
    pluginService: PluginService

    property string mode: "note"
    property string pendingLine: ""
    property string pendingSection: ""

    readonly property string home: Quickshell.env("HOME")

    // ── Settings, with defaults that work before anything is configured ──────
    readonly property string vaultPath: {
        const p = (pluginData.vaultPath || "").trim();
        return p === "" ? home + "/Documents/Vault" : p.replace(/^~/, home);
    }
    readonly property string notesHeading: (pluginData.notesHeading || "Notes").trim()
    readonly property string tasksHeading: (pluginData.tasksHeading || "Tasks").trim()
    readonly property string notePrefix: pluginData.notePrefix !== undefined ? pluginData.notePrefix : "- "
    readonly property string taskPrefix: pluginData.taskPrefix !== undefined ? pluginData.taskPrefix : "- [ ] "
    readonly property string dailyType: (pluginData.dailyType || "daily-scratch").trim()
    readonly property string filenameSuffix: pluginData.filenameSuffix !== undefined ? pluginData.filenameSuffix : " daily"
    readonly property bool notifyOnCapture: pluginData.notifyOnCapture !== false
    readonly property string defaultMode: pluginData.defaultMode || "note"

    function today() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate());
    }

    function dailyPath() {
        return vaultPath + "/" + today() + filenameSuffix + ".md";
    }

    function emptyDaily() {
        return "---\ncreated: " + today() + "\ntype: " + dailyType + "\n---\n\n"
             + "## " + notesHeading + "\n\n## " + tasksHeading + "\n";
    }

    // Insert `line` at the end of `section`, leaving every other line untouched.
    // If the heading is absent the section is appended rather than guessed at.
    function insert(body, section, line) {
        const lines = body.split("\n");
        const head = "## " + section;
        let start = -1;
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].trim() === head) {
                start = i;
                break;
            }
        }
        if (start === -1)
            return body.replace(/\n+$/, "") + "\n\n" + head + "\n" + line + "\n";

        let end = start + 1;
        while (end < lines.length && lines[end].indexOf("## ") !== 0)
            end++;
        let at = end;
        while (at > start + 1 && lines[at - 1].trim() === "")
            at--;                       // insert before the blank padding
        lines.splice(at, 0, line);
        return lines.join("\n");
    }

    function openFor(kind) {
        const k = (kind === "note" || kind === "task") ? kind : defaultMode;
        root.mode = (k === "task") ? "task" : "note";
        capture.showWithOptions({
            "title": root.mode === "task" ? "New task" : "New note",
            "message": "Appends to today's daily note",
            "placeholder": root.mode === "task" ? "What needs doing?" : "What's on your mind?",
            "confirmText": "Add",
            "onConfirm": text => root.capture(text)
        });
    }

    function capture(body) {
        const text = (body || "").trim();
        if (text.length === 0)
            return;
        const isTask = root.mode === "task";
        root.pendingSection = isTask ? tasksHeading : notesHeading;
        root.pendingLine = (isTask ? taskPrefix : notePrefix) + text;
        reader.createObject(root, {});
    }

    function finish(existing) {
        const base = (existing && existing.trim() !== "") ? existing : emptyDaily();
        const next = insert(base, pendingSection, pendingLine);
        writer.createObject(root, {
            "path": dailyPath(),
            "content": next.replace(/\n+$/, "") + "\n"
        });
    }

    function toast(title, body, critical) {
        if (critical)
            ToastService.showError(title, body);
        else
            ToastService.showInfo(title, body);
    }

    IpcHandler {
        target: "dmsVault"
        enabled: true

        function note(): string {
            root.openFor("note");
            return "SUCCESS";
        }

        function task(): string {
            root.openFor("task");
            return "SUCCESS";
        }

        function close(): string {
            capture.close();
            return "SUCCESS";
        }

        // Scriptable capture with no UI — the CLI path, natively:
        //   dms ipc call dmsVault add task "send Eric the dataset tool"
        function add(kind: string, text: string): string {
            if (kind !== "note" && kind !== "task")
                return "ERROR: kind must be note or task";
            if (!text || text.trim() === "")
                return "ERROR: empty text";
            root.mode = kind;
            root.capture(text);
            return "SUCCESS";
        }
    }

    Component {
        id: reader
        FileView {
            path: root.dailyPath()
            blockLoading: true
            preload: true
            printErrors: false
            onLoaded: {
                root.finish(text());
                destroy();
            }
            // Missing file is the normal first-capture-of-the-day case.
            onLoadFailed: {
                root.finish("");
                destroy();
            }
        }
    }

    Component {
        id: writer
        FileView {
            property string content
            blockWrites: false
            atomicWrites: true
            Component.onCompleted: setText(content)
            onSaved: {
                if (root.notifyOnCapture)
                    root.toast(root.mode === "task" ? "Task added" : "Note added",
                               root.pendingLine, false);
                destroy();
            }
            // A capture that fails silently is worse than one that errors: the
            // text is gone and you believe it was saved. Always say so, and
            // include the text so it can be recovered from the notification.
            onSaveFailed: {
                root.toast("NOT captured — write failed",
                           "Nothing was saved. Text: " + root.pendingLine, true);
                destroy();
            }
        }
    }

    InputModal {
        id: capture
    }
}
