# Start12 TODO: Start11 menu features still missing (2026-10-14)

Source: docs/research/start11-features.md checked against package/contents (config/main.xml keys,
ui/**). One job = one agent, 1-3 files, under ~40 tool calls, context cap ~100k. Every job: `./install.sh`,
open the menu, do the check; errors via `journalctl --user --since "-15 s" | grep start12`. New keys go
in `package/contents/config/main.xml` with a `<label>` naming the Start11 registry value. Ordered by
what the user notices first. Sizes: S = under ~1 h of agent work, M = one full agent.

Already done (do not redo): 7 styles + substyles, tiles (4 sizes, groups, drag, icon/colour/caption,
lock, resort, tooltip), Win11 pinned pages + Recommended, app list (A-Z, jump grid, folders, new badge),
left rail modes + custom locations, power menu + button action, search (grouped, Best match, web search,
runner choice), colours/dark mode/transparency/corners/textures/font, 24 start buttons, type-to-search,
Super key (`launchermenu`), kicker right-click actions (jump list, add to panel/desktop, edit, manage).

## Jobs

### T01 Pin websites, files and folders to Start (M) -- DONE 2026-10-14 (not yet checked on screen)
Build: accept custom ids `custom|name|icon|target` (same format as `railItems`) in `main.qml pin()`,
`tileGroups` and `pinnedGrid`; `Tile.qml` / `PinnedGrid.qml` / `AppCanvas.qml` launch them through
`root.openUrl` or `root.run`; resolve name/icon from the url (`KIO` mime icon, host name for http).
Add "Pin website…", "Pin file…", "Pin folder…" to the menu-surface menu in `TileArea.qml` and
`PinnedGrid.qml` (reuse the custom-location dialog from `config/ConfigRail.qml`; website = text field,
file/folder = `QtQuick.Dialogs` FileDialog). Optional: favicon from `https://icons.duckduckgo.com/ip3/<host>.ico`.
Check: pin a URL, a PDF and ~/Pictures; they appear as tiles/icons, click opens them, unpin works.

### T02 Keyboard navigation inside the menu (M) -- DONE 2026-10-14 (not yet checked on screen; Win7 "All Programs" button, Win11 Recommended, canvas tabs not reachable by keys)
Build: arrow keys move a focus highlight through `win10/AppList.qml`, `win10/TileArea.qml` (tiles),
`common/PinnedGrid.qml`, `common/PinnedPane.qml`, `win10/LeftRail.qml`; Tab/Shift-Tab switch panes;
Enter launches, Menu key opens the context menu, Esc as now. Hook in each `styles/*.qml` `Keys.onPressed`
(type-to-search must keep working). Files: AppList.qml, TileArea.qml, PinnedGrid.qml (+ styles for Tab).
Check: open with Super, press Down x3, Enter launches the 3rd app; Tab moves into tiles; Esc closes.

### T03 Search filter icons (M) -- DONE (in win10/SearchView, so every style has it)
Build: `FilterIcons`: row of toggle icons above results in `win10/SearchView.qml` (Apps, Settings,
Documents, Music, Pictures, Videos, Files, Web); a filter keeps rows whose runner id / mimetype matches
(apps: `krunner_services`; files: `baloosearch` + mimetype role; settings: `krunner_kcms`). Keys:
`searchFilterIcons` Bool, `searchFilter` String (last used). Checkbox in `config/ConfigSearch.qml`.
Check: type "a", click Documents: only files remain; click again: all.

### T04 Win7/Modern: drag to reorder pins + jump-list arrows (M) -- DONE (+ web/file/folder pins, empty-space pin menu)
Build: in `styles/windows7.qml` pinned list, drag rows (copy the drag code of `PinnedGrid.qml`, store
through `root.movePinned`); an arrow at the right of pinned/most-used rows that opens a submenu with
the kicker jump-list actions (`contextMenu.kickerActions`) + "Pin/Unpin". Key: none.
Check: drag a pin to the top, reopen the menu, order kept; arrow on Dolphin shows recent folders.

### T05 Win10 tile folders (M) -- DONE 2026-10-14 (not yet checked on screen)
Build: drop a tile onto another tile -> folder tile `{ kind: "folder", name, tiles: [...] }` in
`code/tiles.js` (`place` into folder, `remove`, `sizeOf`) + `tests/test_tiles.js`; `win10/Tile.qml`
draws a folder as a grid of mini icons; click expands a row below the group (`TileGroup.qml`) showing
its tiles; right-click "Name folder", "Unpin folder". Mirrors `FoldersInPlace`.
Check: `node tests/test_tiles.js` passes; drop Firefox on Dolphin, folder tile appears, opens, closes.

### T06 Win11 pinned folders (M) - DONE
Build: `pinnedGrid` entry `folder|name|id1,id2,...`; `common/PinnedGrid.qml` draws it with 4 mini icons,
click opens a popup grid (`PC3.Popup`) with its apps; drop an icon onto an icon creates one; right-click
"Rename folder", "Unpin folder". Helpers in `code/tiles.js` (`folderOf`, `placeInFolder`) + tests.
Check: drop two pins together, folder shows, opening it launches an app, unpin restores both.

### T07 Win10 tile pages (M) -- DONE 2026-10-14 (not yet checked on screen; tiles cannot be dragged across pages, move the group)
Build: `tileGroups` JSON gets `{ pages: [ { groups: [...] } ] }` (migrate the old flat list in
`Tiles.parse`); `code/tiles.js` `newPage`, `deletePage`, `moveGroupToPage` + tests; `win10/TileArea.qml`
page dots at the bottom, wheel/dots change page, surface menu "New page", "Delete this page", group menu
"Move to next/previous page". Key: `tilePage` Int (last page).
Check: New page, move a group to it, dots switch pages, restart plasmashell, layout kept.

### T08 Hide apps from the list (S) DONE
Build: key `hiddenApps` StringList (`ShowHidden`); `win10/AppList.qml` filters them out; item
right-click "Hide from apps"; `config/ConfigMenu.qml` "Hidden apps" list with "Show"/"Clear hidden list".
(Check first whether `Kicker.RootModel` exposes `hiddenEntries`; if so bind it instead of filtering.)
Check: hide Konsole, it vanishes from A-Z and search folders; Clear brings it back.

### T09 More places (S) -- DONE
Build: add to `common/Places.qml` ids `computer` (`file:///`), `trash` (`trash:/`), `recent`
(`recentlyused:/`), `games` (`applications:/Games`), `printers` (`systemsettings kcm_printer_manager`),
`users` (`systemsettings kcm_users`), `updates` (`plasma-discover --mode update`), `separator`;
list them in `config/ConfigRail.qml` for rail and bottom items; separator draws a line.
Check: add Trash + separator to the left rail, they show and open.

### T10 Start button menu + surface menu extras (S) - DONE
Build: `main.qml contextualActions` add "Show desktop" (`Plasmoid.containment.corona`... or
`qdbus6 org.kde.kglobalaccel /component/kwin invokeShortcut "Show Desktop"`), "Edit panel"
(`Plasmoid.containment.corona.editMode = true`), "System Settings", "Task Manager"-like "System Monitor"
exists; register ids in `buttonMenuItems` + `config/ConfigButton.qml`. `win10/TileArea.qml` surface
menu: "Lock menu"/"Unlock menu" toggling `tilesLocked`.
Check: right-click the start button, Show desktop minimises all; Lock menu stops tile drags.

### T11 Item right-click extras (S)
Build: `ContextMenu.qml` own items for app rows: "Open file location" (dir of the kicker `url` role via
`root.openUrl`), "Rename" for `pinnedGrid` items (key `pinnedCaptions` String JSON id->name, used by
`PinnedGrid.qml`/`PinnedPane.qml`), "Create shortcut on desktop" (kicker's "Add to Desktop" exists;
only add if missing). Hook in `win10/AppList.qml`, `common/PinnedGrid.qml`, `styles/windows7.qml`.
Check: Open file location on Firefox opens /usr/share/applications; renamed pin keeps its name.

### T12 Reset positions / reset all settings (S)
Build: `config/ConfigMenu.qml` "Reset icon positions" (clears `tileGroups`, `pinnedGrid`); a "Reset
Start12 settings" button on `config/ConfigStyle.qml` that sets every key back to its `main.xml` default
(list the keys in a JS object in `code/defaults.js`; or `kwriteconfig6 --delete` per key via
`extras/start12-reset.sh`). Confirm dialog first.
Check: change colour and tiles, Reset, menu is back to the fresh-install look.

### T13 Backup / restore settings (M)
Build: `extras/start12-backup.sh backup|restore <file>` that copies the
`[Containments][*][Applets][*][Configuration]` block of the Start12 applet from
`~/.config/plasma-org.kde.plasma.desktop-appletsrc` (find by `plugin=org.start12.menu`), restore writes
it back and restarts plasmashell; buttons "Backup settings…" / "Restore settings…" on `ConfigStyle.qml`
(FileDialog, run the script). Pins are included (unlike Start11).
Check: backup, reset (T12), restore, settings and pins are back.

### T14 Full screen menu (M)
Build: keys `fullScreen` Bool (`UseFullScreenMenu`), `keepPanelVisible` Bool (`SemiFull`); `main.qml`
sets the popup to the screen size (`Plasmoid.containment.screenGeometry`, minus the panel when
`keepPanelVisible`); `common/Metrics.qml heightFor()` honours it; Win10 tile area gets more columns.
Check: enable, menu covers the screen, Esc closes; disable, back to Tall.

### T15 App canvas: user-made tabs and groups (M)
Build: `common/AppCanvas.qml`: key `canvasLayout` String JSON `{ tabs: [ { name, groups: [ { name,
colour, ids } ] } ] }` (today's Pinned/Apps/Recent stay as built-in tabs); surface menu "New tab", "Add
group", "Rename", "Delete group", "Move tab left/right"; drag pins between groups (reuse DragGhost);
"Always open on this tab" uses `canvasTab`. Helpers + tests in `code/tiles.js` (`placeInList` style).
Check: make tab "Work" with two groups, drag apps in, restart plasmashell, layout kept.

### T16 App canvas: group settings and sources (M)
Build (after T15): per-group settings menu in `AppCanvas.qml`: colour, "Icon tinting"/"Auto tint"
(`Kirigami.ImageColors`), row count (Automatic/1/2/...), icon size, "Launch entire group", "Resort A-Z",
"Background texture" pick (TabTextures already shipped); group sources: "Add a folder as group"
(`Qt.labs.folderlistmodel`), "Add Steam folder" (desktop files `steam_app_*`), "Recent searches" (T18).
Check: folder ~/Projects as a group lists its files; Launch entire group opens all.

### T17 Filtered folders (M, low)
Build (after T16): key `filteredFolders` String JSON `[ { name, path, include, exclude } ]`;
`config/ConfigMenu.qml` "Manage filtered folders" (path, include regex, exclude regex); usable as a
canvas group source and as a Win7 All Programs folder. Filter with JS `RegExp` over file names.
Check: folder ~/Downloads, include `pdf$`, group lists only PDFs.

### T18 Search history (S)
Build: key `searchHistory` StringList (last 10 launched queries, written in `SearchView.activate`);
shown under the box when the field is empty and focused (Win11/Pro/Launcher styles with a search box);
"Clear search history" button in `config/ConfigSearch.qml`; `searchHistoryEnabled` Bool.
Check: search "kate", Enter, reopen: "kate" listed, click runs it; Clear empties it.

### T19 Tile look extras (S)
Build: keys `tileImage` String + `tileImageOpacity` Int (`TileImage`, image behind every tile, picker in
`config/ConfigLook.qml` Tiles group), `greyIcons` Bool (`MultiEffect` saturation 0 in `Tile.qml` and
`AppList.qml`), per-tile "Hide caption" (tiles.js `setProp(id, "hideText")`, `Tile.qml` context menu).
Check: pick an image, all tiles show it; grey icons toggle; one tile without caption after restart.

### T20 Separate header and item fonts (S)
Build: keys `headerFontFamily` String, `headerFontSize` Int, `itemFontSize` Int (`CaptionFontSize`);
`common/Metrics.qml` exposes `headerFont`/`itemFont`; use them in TileGroup names, AppList letters, Win11
"Pinned"/"Recommended" headers; two more rows in `config/ConfigLook.qml` Fonts group.
Check: header font Serif 16, group names change, items do not.

### T21 Small toggles (S)
Build: `railAlignBottom` Bool (`RightIconMode` 3: rail icons at the bottom, `win10/LeftRail.qml`),
`recentHideFolders` Bool (`Win11HideRecentFolders`, filter in `common/Recommended.qml`), `smallPlaces`
Bool (`SmallRight`, row height in `common/Places.qml`), `powerButtonIcon` Bool (`IconOnShutdownButton`,
`styles/windows7.qml` split button), `webFavicons` Bool default false (Start11 "Web links pinned to the
start menu should obtain the favicon image": today `code/tiles.js` always loads icons.duckduckgo.com; when
off use the "internet-web-browser" icon); checkboxes on the matching config pages.
Check: each toggle changes the look after reopening the menu.

### T22 Win7 All Programs extras (S)
Build: `styles/windows7.qml` tree: `autoExpand` Bool (`AutoExpand`, open folders on hover after 400 ms),
`desktopInTree` Bool (`DesktopInTree`, ~/Desktop as a folder), `allAppsAsMenu` Bool (categories as a
cascading `PlasmaExtras.Menu` instead of the in-place tree). Checkboxes in `config/ConfigMenu.qml`.
Check: hover a category, it opens; Desktop folder lists desktop files.

### T23 Open animation toggle (S)
Build: `animateMenu` Bool (inverse `NoAnims`); `main.qml` fullRepresentation fades/slides in 120 ms on
`expanded` (`Behavior on opacity`, `Kirigami.Units.shortDuration`); checkbox in `config/ConfigLook.qml`.
Check: on/off visibly different; no flash with the solid menu.

### T24 Classic (Start10) search (S)
Build: `classicSearch` Bool: `win10/SearchView.qml` compact mode (small icons, one line per result, no
Best match card); checkbox in `config/ConfigSearch.qml`.
Check: results show as a dense list in Win7 style.

### T25 Translations (S)
Build: `package/Messages.sh` (xgettext over `contents/ui`), `po/es.po`, install `.mo` to
`contents/locale/es/LC_MESSAGES/plasma_applet_org.start12.menu.mo` in `install.sh`; translate the
config pages and menu strings to Spanish first.
Check: `LANGUAGE=es plasmashell --replace`, settings window in Spanish.

### T26 Full custom XP theme (M, later -- user will say when)
User wants a custom theme that covers more than menu + taskbar + Start button (details to ask them
when we start). Builds on `code/xptheme.py` and the XP palettes in `styles/xp.qml`.

## Later phase
- Taskbar (features doc section 10): separate phase after the menu, if the user wants it.

## SKIP (Windows-only or not possible on KDE/Wayland)
- Native Windows menu choices (Ctrl-click, Win key opens Windows menu, Win+X, hot corner, tablet mode,
  `OldWinKeyLogic`): no Windows menu; Plasma owns the Super key and the panel.
- Start button position/visibility per taskbar, centre alignment, offset from taskbar, horizontal
  offset, "open on the screen the mouse is on": Plasma panel decides where the widget and popup sit.
- Mica/Acrylic: KWin blur is already behind the menu; no Mica on Linux.
- WindowBlinds/Curtains buttons and skins, `.spak` theme engine, ThemeEdit, "black edges" theme:
  textures + colours cover it; a layered-image skin engine is too big for its value.
- Edge favourites/open tabs, Cortana, Windows Search indexer, Everything, Pinyin: KRunner + Baloo instead.
- Universal/Modern apps folder, "Run as administrator", uninstall prompt: no UWP; no kdesu; kicker's
  "Manage" already opens Discover.
- Live tile themes (Element/Flow/Reflow/Sonar), close button on active tiles: Windows live tiles.
- Suggested apps: ads; Fences/Groupy/Steam sources except the Steam folder (T16).
- Power: Update and restart (no offline-update API worth it), RDP options, Undock/Disconnect, "someone
  else is using this PC", sign-in options link, go to desktop at login, Windows 8 hot corners/charms.
- Reboot warnings, explorer restart, compat hacks, updates/licence, Group Policy lock-down, Stardock sync.
- "Search file contents", "include desktop in search": Baloo already indexes content and ~/Desktop.
