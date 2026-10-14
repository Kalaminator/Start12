# Start12 taskbar plan (2026-10-14)

Source: docs/research/start11-features.md section 10 mapped to Plasma 6.7 (Arch, Wayland). Start11 patches
explorer's taskbar; on Plasma the taskbar = a panel (per screen) + Task Manager widget + the Plasma Style
(desktoptheme) that paints `widgets/panel-background.svg` and `widgets/tasks.svg`. We already generate such
styles for XP (`package/contents/ui/code/xptheme.py`, applied/restored by `main.qml syncDesktopTheme`), so
"taskbar look" features are mostly a generalisation of that. Anything that needs to re-layout task buttons
inside the stock Task Manager is out of reach without forking it (not worth it).

Legend: (a) stock Plasma, name the setting. (b) Start12 / generated style / small extra. (c) not doable.

## Map

| Start11 feature | Class | Plasma 6.7 |
|---|---|---|
| Enable taskbar enhancement, compat warnings, "let Windows control position", explorer restart | c | Windows-only; nothing to do |
| Taskbar size / "Allow the taskbar to be resized" | a | Panel: Edit Mode > Height (and Width: Fill / Fit content / Custom) |
| Taskbar position top/bottom, per display | a | Panel: Position (per panel, one panel per screen) |
| Vertical alignment of buttons inside the bar | c | Task Manager fills the panel thickness; no setting, no visible value |
| Horizontally/vertically centre buttons, padding keeps them centred | a | Panel: Alignment Center + Width "Fit content", or two flexible spacers around the Task Manager |
| Compact buttons, button width/height, icon size | a (part) | Task Manager: Appearance > Icon spacing Small/Normal/Large; icon size follows panel height; exact px not settable |
| Multi-row taskbar (`RowCount`) | a | Task Manager: Appearance > Maximum rows |
| Combine: Always / Sometimes / Never | a | Task Manager: Behavior > Group "By program name" / "Do not group", "Group only when the Task Manager is full" |
| Combine: "Only pinned", per primary/secondary modes | c | not in Task Manager; per-screen panels each have their own Task Manager settings, which covers "per display" |
| Always hide text (`AlwaysHideText`) | a | use Icons-Only Task Manager (or regular one for text) |
| Button text shadow | c | labels come from the Task Manager, no shadow option |
| Button style, "focused less transparent", hide taskbar line | b | `tasks.svg` + `panel-background.svg` in a generated Plasma Style (T31/T33) |
| Disable taskbar animations | a | System Settings > Quick Settings > Animation speed (Instant); Task Manager has no own switch |
| `SeparatePins` | a | Task Manager: Behavior > Keep launchers separate |
| `ShowAllNonUWAOnTaskbar`, `DoNotExcludeTaskbarPinned`, touch-mode detection, Win10 taskbar mode | c | UWP / Win-specific; Plasma has no touch taskbar mode |
| Show buttons on: all / main + window's / window's taskbar | a | Task Manager: Behavior > "Show only tasks from the current screen" (per panel) |
| Pins per display (auto / primary / secondary / all) | a | each panel's Task Manager keeps its own launcher list |
| Taskbar transparency, force solid | a (base) / b | Panel: Opacity Adaptive / Opaque / Translucent; exact alpha value -> generated style (T31) |
| Blur the wallpaper under the taskbar | a | KWin Blur effect + a translucent panel (the style's `translucent/` prefix; generated style sets it) |
| Override / automatic taskbar colour | b | generated style `colors` + panel-background fill (T31); "automatic" = Breeze follows the colour scheme |
| Custom texture (tile / stretch / align / accent tint / texture alpha) | b | image inside the generated `panel-background.svg` (T33) |
| Rounded corners, levels; animate corner changes | b (part) | corner radius drawn in the generated panel-background (T31); Plasma draws it as given, no animation of changes |
| X/Y offset (floating taskbar) | a (part) | Panel: Floating on/off; gap size fixed by Plasma, no offset slider |
| Per-state look (no maximized window / maximized window) | a (part) | Plasma: floating panel docks and Adaptive opacity turns opaque when a window touches it |
| Autohide, "only hide when a window overlaps", "keep height consistent / overlap possible" | a | Panel: Visibility Auto Hide / Dodge Windows / Windows Go Below / Windows Can Cover |
| Autohide toggle in the taskbar menu | b | start-button right-click action flipping the panel's `hiding` via plasmashell scripting (T29) |
| Reserve one pixel at the edge | c | Plasma's autohide keeps its own edge strip; moot |
| Clock seconds | a | Digital Clock: Appearance > Show seconds Always / Only in tooltip / Never |
| Show / hide search on taskbar | b | Plasma has no search bar widget; Start12 can draw one next to the start button (T30) |
| Taskbar pins: file, folder, website, "Browse for file", "Enter web address" | b | Task Manager launchers only take .desktop files; Start12 writes a .desktop per custom pin and adds it (T32) |
| Pin folder menu / open folder as a menu | a | Folder View widget in the panel (shows the folder as a popup list) |
| Multi-monitor primary / secondary | a | one panel per screen, each configured on its own (Edit Mode > Clone panel) |

Counts: a = 20 (4 partial), b = 8, c = 8.

## Jobs (b items), smallest-useful first

Same rules as docs/TODO.md: one agent per job, `./install.sh`, check on screen, errors via journalctl, new keys in
`config/main.xml` with a `<label>` naming the Start11 value. Context cap ~100k per agent.

### T29 Autohide toggle in the start-button menu (S)
Build: id `autohide` in `buttonMenuItems` (ConfigButton list, main.qml `contextualActions` next to "Show desktop"/
"Edit panel"): runs `qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript` with a script that finds the panel on
`Plasmoid.screen` + `Plasmoid.location` (`panels()` loop) and flips `panel.hiding` between `none` and `autohide`.
Mirrors "Show autohide toggle on taskbar menu". Check: right-click the start button, "Auto-hide panel" hides the
panel; again restores it.

### T30 Search box on the taskbar (M)
Build: key `taskbarSearch` (Bool, default off, Start11 "Show search on taskbar") + `taskbarSearchWidth`; in
`StartButton.qml` (horizontal panels only) add a TextField right of the button, `Layout.preferredWidth` grows the
compact representation; typing or Enter sets `root.searchText` and `root.expanded = true` so SearchView opens with
the text; Esc clears. Draw it in the menu style's colours (Metrics). ConfigButton checkbox + width.
Check: field visible on the panel, type "dolp", menu opens on Dolphin results, Esc closes and empties the field.

### T31 Generated taskbar style for every menu style (M) -- DONE (no settings UI yet; T36)
Build: generalise `ui/code/xptheme.py` (new entry `--taskbar colour=#.. alpha=0.8 radius=8 line=0 sub=flat`) to
write `start12-taskbar-<hash>` with `[Settings] FallbackTheme=` the current Plasma Style so only
`widgets/panel-background.svg` (incl. `translucent/` prefix for blur), `widgets/tasks.svg` and `colors` are
replaced; keys `taskbarTheme` (off|custom), `taskbarColor`, `taskbarAlpha`, `taskbarRadius`, `taskbarLine`
(Start11 `CustomColourTaskbar`, `TaskbarAlphaValue`, rounded corners, `HideTaskbarLineEntirely`). `main.qml
syncDesktopTheme` generates (same path as the XP `-custom-<hex>` case) and applies it, restores
`savedDesktopTheme` when switched off; XP keeps precedence. Check: set colour red, alpha 50 %, radius 12: panel
shows it, other widgets unchanged; switch off restores Breeze.

### T32 Pin files, folders and websites to the taskbar (M)
Build: "Pin to taskbar" in `ContextMenu.qml` for `custom|...` pins (T01) and for All-apps rows that kicker's
"Add to panel" does not cover: write `~/.local/share/applications/start12-pin-<n>.desktop` (`Exec=xdg-open
<target>`, icon/name from `Tiles.customFor`), then plasmashell `evaluateScript` appends its url to the `launchers`
config of the Task Manager (`org.kde.plasma.icontasks` or `taskmanager`) in the start button's panel. "Unpin from
taskbar" removes both. Check: pin a URL and ~/Pictures from the menu, both appear on the panel and open; unpin removes them.

### T33 Taskbar texture (M)
Build: on top of T31: keys `taskbarImage`, `taskbarImageMode` (tile|stretch|top|middle|bottom), `taskbarImageAlpha`,
`taskbarImageTint` (accent colour multiply) (Start11 `TaskbarImage`, `CustomTextureAlignment`); xptheme.py embeds
the image (base64 `<image>` with `preserveAspectRatio`/pattern) into panel-background.svg; ConfigLook-style picker.
Check: pick a PNG, tiled vs stretched visible on the panel; alpha 30 % blends with the colour.

### T34 Taskbar button style (M)
Build: on top of T31: key `taskbarButtons` (plasma|win10|win11|win7): xptheme.py writes `tasks.svg` variants
(Win10 flat bar under active + hover fill, Win11 pill indicator and rounded hover, Win7 glass button) and
`taskbarFocusedSolid` (active task less transparent, Start11 "Paint focused item backgrounds less transparent").
Check: each variant on an Icons-Only Task Manager with 3 open windows, active one distinct.

### T35 Taskbar follows the menu style (S)
Build: key `taskbarFollowsStyle` (default off): when on, `syncDesktopTheme` picks a preset per menuStyle
(windows10 = #101010 opaque square, windows11 = light translucent radius 8 win11 buttons, windows7 = blue
translucent glass, xp = existing XP style, others = off) instead of the custom keys. ConfigStyle checkbox.
Check: switch Win10 -> Win11 -> XP, panel follows each time; off restores the saved style.

### T36 Settings page "Taskbar" (S)
Build: `config/ConfigTaskbar.qml` gathering the keys of T29-T35 plus a short note with buttons for what stock
Plasma covers: "Edit panel…" (reuse the T10 `editpanel` action), "Task Manager settings…" (evaluateScript
`widget.showConfigurationInterface()` on the panel's task manager). Register in `config/config.qml`. Translate new
strings (`package/Messages.sh`, po/es.po). Check: page opens from Start12 Settings, both buttons open the right dialog.

## Not planned
Per-pin display selection, "only combine pinned", touch mode, text shadow, animated corner changes, offset
sliders: either stock Plasma decides it or it needs a Task Manager fork. Revisit only if the user asks.
