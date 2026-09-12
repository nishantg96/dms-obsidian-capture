import "./dms-common"
import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Setting widgets must be DIRECT children of PluginSettings — DMS only
// iterates its immediate content list to call loadValue(). Anything nested
// inside a Column or Rectangle silently keeps its defaultValue forever.
//
// The daemon reads these directly; the plugin writes the daily note itself
// through FileView, so there is nothing external to install or configure.
PluginSettings {
    id: root
    pluginId: "dmsVault"

    StyledText {
        text: "Vault"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingS
    }

    StringSetting {
        settingKey: "vaultPath"
        label: "Daily notes folder"
        description: "Folder the daily note is written into. Created if missing."
        placeholder: "~/Documents/Vault"
        defaultValue: ""
    }

    StyledText {
        text: "Daily note"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    StringSetting {
        settingKey: "filenameSuffix"
        label: "Filename suffix"
        description: "Appended after the date. Today's file becomes 2026-09-12<suffix>.md"
        placeholder: " daily"
        defaultValue: " daily"
    }

    StringSetting {
        settingKey: "dailyType"
        label: "Frontmatter type"
        description: "The type: value written into new daily notes."
        placeholder: "daily-scratch"
        defaultValue: "daily-scratch"
    }

    StringSetting {
        settingKey: "notesHeading"
        label: "Notes heading"
        description: "Section notes are appended under."
        placeholder: "Notes"
        defaultValue: "Notes"
    }

    StringSetting {
        settingKey: "tasksHeading"
        label: "Tasks heading"
        description: "Section tasks are appended under."
        placeholder: "Tasks"
        defaultValue: "Tasks"
    }

    StringSetting {
        settingKey: "notePrefix"
        label: "Note prefix"
        description: "Put before each captured note. Include the trailing space."
        placeholder: "- "
        defaultValue: "- "
    }

    StringSetting {
        settingKey: "taskPrefix"
        label: "Task prefix"
        description: "Put before each captured task. Include the trailing space."
        placeholder: "- [ ] "
        defaultValue: "- [ ] "
    }

    StyledText {
        text: "Behaviour"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    ToggleSetting {
        settingKey: "notifyOnCapture"
        label: "Notify on capture"
        description: "Show a notification confirming what was added."
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "defaultMode"
        label: "Default mode"
        description: "Used when invoked without note/task."
        options: [
            { "label": "Note", "value": "note" },
            { "label": "Task", "value": "task" }
        ]
        defaultValue: "note"
    }

    StyledText {
        text: "Shortcuts"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingM
    }

    StyledText {
        text: "Bind these in your compositor config. For niri, add them to a binds { } block."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        width: parent ? parent.width : 0
    }

    CopyBox {
        label: "Capture a note"
        text: "dms ipc call dmsVault note"
    }

    CopyBox {
        label: "Capture a task"
        text: "dms ipc call dmsVault task"
    }

    CopyBox {
        label: "niri bind — note"
        text: "Mod+Ctrl+N hotkey-overlay-title=\"Vault: Note\" { spawn \"dms\" \"ipc\" \"call\" \"dmsVault\" \"note\"; }"
    }

    CopyBox {
        label: "niri bind — task"
        text: "Mod+Ctrl+T hotkey-overlay-title=\"Vault: Task\" { spawn \"dms\" \"ipc\" \"call\" \"dmsVault\" \"task\"; }"
    }
}
