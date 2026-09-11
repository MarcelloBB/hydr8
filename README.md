## hydr8

Hydration tracker and reminder widget for the Omarchy Shell bar.

<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/0c994400-3ff0-4624-9665-a664b7e1f6f6" />

### Install

Copy this folder into your Omarchy plugins directory, matching the plugin id (`hydr8`):

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r hydr8 ~/.config/omarchy/plugins/hydr8
```

Then enable it:

```bash
omarchy plugin enable hydr8
```

The widget should land in the `right` section of the bar by default (set by
`barWidget.defaultSection` in `manifest.json`).

If it doesn't show up, add it explicitly:

```bash
omarchy bar put hydr8 --section right
```

or move it if it's already on the bar somewhere else:

```bash
omarchy bar move hydr8 --section right
```

### Validate

From the plugin's folder:

```bash
omarchy plugin validate .
```

Exits silently with status `0` when the manifest is valid.

## Applying changes after editing

Omarchy hot-reloads most plugin edits automatically as soon as you save a
file under `~/.config/omarchy/plugins/hydr8/`. If a change doesn't seem to
take effect (this can happen with structural changes, like altering a
`required property` or adding an `import`), force a full reload:

```bash
omarchy restart shell
```

This is the most reliable way to guarantee a change was picked up, since it
fully reloads the shell process instead of relying on the plugin watcher.

You can also force a plugin rescan without a full restart:

```bash
omarchy-shell shell rescanPlugins
```

### Data

History is stored at:

```text
~/.local/share/hydr8/water.json
```

The plugin does not send data anywhere over the network.

### About notifications

The first version uses `notify-send`, which is simple and works with the
Linux desktop notification system. If your installation doesn't have it
available:

```bash
command -v notify-send
```

### Requirements

- A Nerd Font that includes the Material Design Icons set (Omarchy's default,
  `JetBrainsMono Nerd Font`, already covers this) — the bar icon and popup
  icons are Nerd Font glyphs rendered with `bar.fontFamily`.
- Runs only inside the Omarchy shell (Quickshell): the widget imports
  `qs.Commons` and `qs.Ui`, which resolve through the shell's own QML import
  path.
