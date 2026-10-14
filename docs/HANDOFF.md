# Start12 handoff (2026-10-14)

Start12 = Stardock Start11 v2 rebuilt as a KDE Plasma 6.7 widget (`org.start12.menu`) for the user's
Arch + Wayland PC. Goal: 1:1 Start11, every style switchable from a settings window. The user tests and
sends screenshots; they said "keep adding everything, once we have all functions we change things".

## Layout
- `package/` = the plasmoid. `./install.sh` (runs `node tests/test_tiles.js`, kpackagetool update,
  then `contents/ui/code/setup.sh --force`). `./install.sh --restart` also restarts plasmashell.
- `package/contents/ui/main.qml`: PlasmoidItem, kicker models (RootModel row 1 = all apps, RunnerModel,
  SystemModel created after refresh because it crashes with a null favoritesModel), pin logic
  (`usesTiles` = windows10 -> tile groups JSON `tileGroups`; grid styles -> `pinnedGrid` list),
  `builtStyles` list, start-button right-click actions, tile icon/colour dialogs, `openSettings()`.
- `ui/styles/<id>.qml`: one file per menu style. Built: all 7 (see Style status).
  Register new ones in `main.qml builtStyles` AND `config/ConfigStyle.qml built`.
- `ui/common/`: Metrics (sizes+colours, `px()`, `heightFor()`), MenuBackground (colour, transparency,
  texture; hides Plasma's `DialogBackground` so transparency is real), Places (rail/bottom shortcuts,
  user + power menus), PinnedGrid, Recommended.
- `ui/win10/`: LeftRail, AppList (A-Z, folders, jump grid, drag to pin), TileArea/TileGroup/Tile,
  SearchView (grouped KRunner results, web search). Other styles reuse AppList and SearchView.
- `ui/ContextMenu.qml`: right-click menus (own items with `run`, plus kicker actions).
- Keyboard: `common/KeyNav` in each style (panes list, arrows via `Tiles.nearest`, Tab, Enter, Menu key); items opt in with `kbNav: true` + `KeyFrame {}`, AppList uses `kbStep`.
- `ui/code/tiles.js`: pure logic (pack, place, moveGroup, placeInList, setProp...) + `tests/test_tiles.js`.
- Pinned websites/files/folders = `custom|name|icon|target` ids (`Tiles.custom/customFor`, `root.openCustom`,
  `root.pinNewItems` in the TileArea/PinnedGrid empty-space menu; AppCanvas shows them as a "Shortcuts" group).
- `config/`: settings pages (Start Menu, Layout, Left side, Look, Search, Start Button). `main.xml` holds
  all keys, labels name the Start11 registry value.
- `docs/research/start11-features.md` (330 Start11 features) and `start11-internals.md`.

## Store install (T44)
KDE Store/Discover only unpacks the package, so `main.qml` runs `code/setup.sh` on every start (`setupRunner`,
then syncDesktopTheme + readBrightness). setup.sh = xptheme.py (desktoptheme, --deco, --scheme) + installs
`contents/extras/start12-settings(.desktop)`; no-op unless `~/.local/share/start12/setup-version` != metadata
Version or a start12-xp-classic file / the command is missing. Translations: committed .mo in contents/locale
(install.sh recompiles when msgfmt exists). Release: `tools/make-release.sh` -> dist/*.plasmoid (git-tracked only,
Stardock check); store page text + upload steps in docs/STORE.md. Simulated store install verified: themes reappeared.

## Done and confirmed by the user or screenshots
Win10 style like their Start11 screenshot, tiles (4 sizes, groups, drag tiles + groups, per-tile icon/
colour/caption), settings window ("Start12 Settings" app works via config key `openSettingsRequest`),
real transparency, resizable popup, Arch start icon, Win11 style (search, pinned pages, all apps,
recommended fits above bottom bar).

## Style status (2026-10-14)
Reference pictures of every Start11 v2 style: https://www.xda-developers.com/start11-v2-review/ and
https://www.stardock.com/blog/523496/introducing-start11-v2 (user-approved sources). All 7 styles built and seen on screen.
- `windows7.qml` = Windows 7 AND Modern (`modern` flag from menuStyle; main.qml maps modern -> windows7).
  Win7: white left pane (second Metrics `pm` with mode forced light), pinned + most used, All Programs,
  search at the bottom, places (railItems minus user/power), split Shut down button. Modern: no pane, header
  with picture + name at top left, places with icons. Substyles `win7Substyle` / `modernSubstyle`.
- `app.qml`: top bar (picture, name, bottomItems + power), `common/AppCanvas.qml` (tabs Pinned/Apps/Recent,
  Fences-like coloured groups with images/TabTextures) on the left, AppList on the right, type to search.
- `pro.qml`: SearchBox + `common/PinnedPane.qml` (3 cols) left, darker right panel (picture, places with icons, power).
- `launcher.qml`: big picture + name, power top right, SearchBox, PinnedPane (up to 6 cols).
- `xp.qml` (menuStyle "xp", key `xpSubstyle` "classic" | "modern"): Luna header + picture, white pinned/most used
  + green All Programs, light blue places, Log Off / Turn Off bar. Modern = same palette, rounded cards. Not yet seen on screen.
- Shared: common/Avatar, SmallButton (Win11 uses it too), SearchBox (signal `cancel`), DragGhost, PinnedGrid
  `fixedCols`/`fixedRows`. Keys `canvasTab`, `canvasTextures`.
XP taskbar: Plasma Styles `start12-xp-{classic,modern}[-olive|-silver]` generated by `ui/code/xptheme.py` (install.sh; custom colour `-custom-<hex>` made by main.qml at apply time); keys `xpColor` blue|olive|silver|custom + `xpCustomColor` colour menu (xp.qml `schemes`) and taskbar; main.qml `syncDesktopTheme` applies them with XP style + key `xpTaskbarTheme`, restores `savedDesktopTheme` after. Not yet seen on screen.
Window decorations (T26a): key `windowTheme` (Taskbar page) -> main.qml `windowDecoration()` (XP only so far) -> `syncWindowDeco` writes kwinrc kdecoration2 library/theme `__aurorae__svg__start12-xp-*` + KWin reconfigure, saves/restores savedDecoLibrary/Theme; themes by `xptheme.py --deco`. Not seen on screen. Colours (T26b): same key -> `windowColors()` -> `syncWindowColors` runs plasma-apply-colorscheme `start12-xp-*` (xptheme.py --scheme, ~/.local/share/color-schemes), saves/restores savedColorScheme (kdeglobals General ColorScheme). Not seen on screen.
Window look for every style (T37): `xptheme.py --deco/--scheme` also write `start12-win10-light|dark`, `start12-win11-light|dark`, `start12-win7` (`write_win_deco`, `WIN_SCHEMES`); `windowDecoration()` = deco + colour scheme name (modern/app/pro/launcher = win11; 10/11 dark when `userDark`, read by `readBrightness()` from the user's own/saved scheme, which then runs both syncs). Taskbar page: two top switches "Apply the theme to the taskbar" (sets xpTaskbarTheme + taskbarFollowsStyle; non-XP styles without a preset use windows11) and "Apply the theme to windows". Rendered in PySide6 only, not seen on screen.
Win10 colours (T38): Start Menu page group for windows10 (colorMode, accentMode/accentColor shared with Look; `win10AccentStart` Metrics bg = darkened accent + taskbar = accent, `win10AccentTitles` deco/scheme `start12-win10-<light|dark>-accent-<hex>` made by `xptheme.py --deco|--scheme --custom hex --win10 light|dark`, cleaned like xp custom, `win10Transparency` menu solid / taskbar alpha .85 vs 1); main.qml `win10Dark`, `accentHex`, `customArgs()`. PySide6 render only, not seen on screen.
Colours page (T39): `config/ConfigColours.qml` (all styles but XP) = mode (colorMode), accent Automatic/Manual, `recentAccents` (5), 48 Windows swatches, colour dialog, the T38 switches now for every non-XP style: Metrics accentStart/transparency (win7 white pane opts out), taskbar presets win10/11/7 (accent, alpha), decos `start12-win10|win11-<mode>-accent-<hex>` / `start12-win7-accent-<hex>` (`xptheme.py --kind`), main.qml `winDark` (was win10Dark, win11 now follows colorMode too). PySide6 render only.
Window glass (T41): keys `windowOpacity` (%), `windowBlur`, `windowRadius` (-1 style/0 square), `titleHeight` (0 style), Taskbar page under "Apply the theme to windows"; main.qml `glassSuffix` -> deco `<windowDeco>-g<op>b<blur>r<r|d>t<t>` made by `xptheme.py --deco --name <windowDeco> --opacity --blur --radius --title` (OPT, `deco_for_name`, `glassify`: frame alpha + mask-* pieces for blur), colour scheme keeps the base name; `wantBlur` turns KWin blur on, user's blurEnabled saved in `savedBlur`. Corner outlines are now rings (no overlap; bounds integer). Seen on screen: win11 dark accent at 70%/40%, radius 10, title 40, blur behind; reset restores.
Taskbar style (T31): keys `taskbarTheme` off|custom, `taskbarColor`, `taskbarAlpha` (%), `taskbarRadius` (2 = square), `taskbarLine`; `xptheme.py --taskbar k=v... fallback=<style>` writes `start12-taskbar-<md5>` (panel-background plain/translucent/opaque + mask, flat tasks.svg, colors, FallbackTheme = saved style); main.qml `taskbarArgs` -> `syncDesktopTheme` (XP wins, same restore). No UI yet (set with kwriteconfig6). Not yet seen on screen.
Taskbar follows style (T35): key `taskbarFollowsStyle`; main.qml `taskbarPresets` (windows10/11/7, else none) feed `taskbarArgs` instead of the custom keys; ConfigStyle checkbox. Needs a user check.
Menu position (T42): key `menuPosition` 0 left/1 center/2 right + `centerTaskbar` (Start Menu page combo + checkbox). Popup: main.qml `full.place()` sets the AppletPopup's `visualParent` (via `Window.window`) to `StartButton.popupAnchor`, an empty item as wide as the popup under the screen centre / at the right edge (horizontal panels, not full screen). Right: `LayoutMirroring` on `frame`; styles flip explicit x (split handles, win7 header/pane/rows, xp user button/rows, LeftRail via anchors; SplitHandle drag direction), tile grids keep their inner order. `centerTaskbar`: main.qml `syncCenterPanel()` evaluateScript adds two marked (`start12Centre`) panel spacers around Start..Task Manager, sets Task Manager `fill` false (old value in `start12Fill`), writes AppletOrder; off removes them and restores fill. Live-tested 2026-10-14 (seen on screen): Center popup centred also on first open and with the centred taskbar; centerTaskbar on/off (off restores order + fill); Right in all 8 styles; Left unchanged. Fixes then: spacer order via `Widget.index` in a 2nd script 1 s later (AppletOrder writes do not reorder live) + flip spacers' `expanding` so their optimalSize recomputes; popupAnchor reparented to the panel window root (button-relative x went stale when the button moved); Pro/Win7/XP place rows had `width: ... - x` in a Row = polish loop when mirrored; SearchBox padding swaps for Right. XP classic green pill corners follow menuPosition (`xpPill.leftR/rightR`: Left square-left, Center round, Right square-right; Modern untouched). Strings translated in all 10 po. Test hook used: temporary `testOpen` key patched into the INSTALLED copy only (sets root.expanded). Left: Win7 jump-list chevrons still point right when mirrored (cosmetic); Win11/tile grids keep LTR order (by design).
Autohide (T29): button-menu id `autohide` (opt-in via Settings > Button; not in the default list), flips `hiding` none/autohide on the panel whose widgetIds has Plasmoid.id. Not run on screen.
XP Start button: `StartButton.qml` draws the green "start" pill (icon = buttonIcon) when menuStyle is "xp" in a horizontal panel; classic/modern shapes; key `xpStartGreen` (off = scheme colour). Not yet seen on screen.
Win7/Modern (T04): pins in cfg.pinnedGrid order incl. custom pins, drag to reorder, jump-list arrow, empty-space "Pin website/file/folder".
Search filters (T03): `win10/SearchView` filter icon row (all styles), `passes()` by runnerId/matchId prefix, favoriteId, url extension; keys `searchFilterIcons`, `searchFilter`. Needs a user check (roles not probed live).
Tile folders (T05): drop a tile on the right 3/4 of a tile -> `{kind:"folder", id:"folder|N", name, size, tiles}` (`Tiles.dropOnTile`, `findTile` searches folders, `tidy` dissolves 1-tile folders); Tile.qml mini-icon grid, TileGroup opens a row under the group (name field, tiles drag out). Left quarter = insert before.
Pin folders (T06): `pinnedGrid` entry `folder|name|id1,id2` (`Tiles.folderOf/folderEntry/allPins/removePin/placeInFolder`); PinnedGrid drop on right 3/4 of an icon = folder, 2x2 mini icons, click opens a `PC3.Popup` (name field, drag apps out); "Unpin folder" puts its apps back. Win7/App flatten folders; XP does not yet.
Tile pages (T07): `tileGroups` = `{pages:[{groups}]}` (`Tiles.parsePages` migrates the flat list; `setPage` keeps app ids unique across pages); `root.groups` = page `cfg.tilePage`, `saveGroups` writes that page, `savePages` all; TileArea dots + wheel (only when nothing scrolls), surface "New page"/"Delete this page" (groups merge into the neighbour), group menu "Move to next/previous page".
Hidden apps (T08): key `hiddenApps` (desktop ids); `root.isHidden/hideApp`; filtered in AppList, AppCanvas (`group.rows`), XP/Win7 most-used, SearchView `passes`; right-click "Hide from apps"; ConfigMenu list with Show/Clear. Kicker has no hiddenEntries property.
More places (T09): `Places.qml` ids computer/trash/recent/games/printers/users/updates/separator (`separator: true` item; drawn as a line in LeftRail, Win7/Modern, Pro, XP; skipped in bottom bars of App/Win11; Launcher unchanged); ConfigRail lists them, separator can be added repeatedly. Needs a user check.
Item menus (T11): `ContextMenu.show` adds "Open file location" for any row with a file: url; "Rename" on grid pins (PinnedGrid, Win7/Modern, XP) via `root.renamePin/capOf/setCap`, key `pinnedCaptions` JSON; Add to Desktop is kicker's. Not shown on Win10 tiles/AppCanvas.
Reset (T12): key `resetRequest` ("positions|all|time", set by a confirm dialog on ConfigMenu/ConfigStyle, acted on after Apply), `main.qml resetTimer` writes every `<key>Default`; `savedDesktopTheme` is kept so leaving XP restores the Plasma Style. Needs a user check (cfg.keys()/Default props untested live).
Backup/restore (T13): ConfigStyle "Backup settings…"/"Restore settings…" FileDialogs set `resetRequest` "backup|t|file" / "restore|t|file"; main.qml writes all `userKeys()` (pins included) as JSON via `Tiles.writeFileCmd`, `backupReader` reads it back, then `syncDesktopTheme()`. Needs a user check.
Start button menu (T10): `contextualActions` "Show desktop" (kglobalaccel) + "Edit panel" (ids `desktop`,`editpanel` in `buttonMenuItems`, ConfigButton); applies to every style incl. XP pill (Plasma owns the right-click, StartButton has no menu of its own); "Lock menu" already existed in TileArea.
Full screen (T14): keys `fullScreen`/`keepPanelVisible` (ConfigStyle checkboxes); `main.qml fullRect` (containment screenGeometry or availableScreenRect) sets popup width, `Metrics.heightFor` returns its height for every style; height drag not saved then. Win10 tile groups wrap via TileArea Flow. Needs a user check (Plasma may clamp the popup to the panel side).
Canvas tabs (T15): key `canvasLayout` JSON (`Tiles.parseCanvas/canvasPlace/...`), user tabs after Pinned/Apps/Recent (`AppCanvas.user` = tab - 3), apps only (no folders/websites); drag from AppList or between groups (DragGhost), right-click tab/header/empty space; `canvasTab` now set only by "Always open on this tab"; `root.askName(current, fn)` reuses renameDialog. Needs a user check.
Filtered folders (T17): key `filteredFolders` JSON, ConfigMenu "Filtered folders" list/add (path ~ ok, include/exclude regex, case-insensitive, `Tiles.filterFile`); App canvas "Add filtered folder: <name>" (group `filtered: name`, live lookup, FolderListModel); Win7/Modern All Programs lists them as folders after the apps (AppList `showFilteredFolders`). Needs a user check.
Search history (T18): keys `searchHistory`/`searchHistoryEnabled`, written in SearchView.activate; SearchBox shows a popup when empty+focused (Win11/Pro/Launcher); ConfigSearch checkbox + Clear. Needs a user check.
Canvas group settings (T16): user-group header menu (colour, Icon tinting = `isMask`, Auto tint = `Kirigami.ImageColors`, rows/icon size/texture submenus, Launch entire group, Resort A-Z = `Tiles.canvasSort`), group fields via `Tiles.canvasSet`; sources "Add a folder as group" (`folder` url, FolderListModel, `Tiles.fileIcon`) and "Add Steam folder" (main.qml `listSteamGames` greps ~/.local/share/applications for steam://rungameid, read once). "Recent searches" group = `searches:true` + `Tiles.pushHistory` (T18). Needs a user check. Plasma keeps one popup size for all styles (user drags it).
Tile look (T19): keys `tileImage`/`tileImageOpacity` (Image inside Tile background, ConfigLook picker) and `greyIcons` (layer MultiEffect saturation -1 on Tile + AppList icons); per-tile hide caption already existed (`caption` prop). Needs a user check.
Fonts (T20): keys `headerFontFamily`/`headerFontSize`/`itemFontSize` (0 = menu size), `Metrics.headerFont/headerFontSize/itemFontSize`; headers = TileGroup names, AppList letters, Win11 section titles, XP user name; items = Tile captions, AppList rows, XP rows. Needs a user check.
Small toggles (T21): keys `railAlignBottom` (default true = old look; LeftRail only), `smallPlaces` (placeH in Win7/Modern, XP, Pro), `powerButtonIcon` (Win7 split button), `recentHideFolders` (Recommended.qml `rows`, folders found by icon name), `webFavicons` (default off; `Tiles.customFor(url,kind,favicons)`, new pins only). ConfigRail/ConfigMenu checkboxes. Needs a user check.
All Programs extras (T22): keys `autoExpand`/`desktopInTree`/`allAppsAsMenu`, AppList `treeExtras: true` (set in windows7.qml and xp.qml): hover timer opens folders, Desktop = synthetic filtered folder `~/Desktop`, categories open a `PlasmaExtras.Menu` (one level). Needs a user check.

Open animation (T23): key `animateMenu` (default true), `main.qml` openAnim (fade + 1 gridUnit slide of styleLoader) on `expanded`; ConfigLook checkbox. Needs a user check.

Classic search (T24): key `classicSearch` (default off), SearchView `compact` (16 px icons, 24 px rows, no description, no Best match card); ConfigSearch checkbox. Needs a user check.

Keys+menus polish (T27): Win7/XP All Programs button is a KeyNav pane (`kbStep` returns itself) in All Programs view, part of the left pane otherwise; Win11 KeyNav pane = home ColumnLayout (pinned + Recommended rows) / moreList; AppCanvas tabs + cells have kbMenu; "Hide from apps" on Win7/XP most-used rows and PinnedGrid app pins (Win11/Pro/Launcher); AppCanvas Pinned tab pins/shortcuts get "Rename" (`cell.pinId`, capOf). Needs a user check.

Layout polish (T28): full screen: `root.fillScreen` (Win10/Win11 stretch) / `root.narrowFull` (others keep size, centred on the panel side over a dim backdrop that closes on click; main.qml `frame`); Win10 tile folder row opens under the folder's own row (`Tiles.rowEnd`, TileGroup `folderShift`); `common/SearchHistory.qml` popup in SearchBox, Win7 field (above) and SearchView field (`suggest`: past searches starting with the typed text). Needs a user check.

## Next (in order)
T01-T25 all built (2026-10-14). Load check of all 8 styles: no QML errors. Seen on screen by me: XP (all colours, start button),
T03 filters, T05 folder. Everything else only lint + load check; the user has not tried T05-T25 yet -> ask for feedback first.
T27-T28 polish done; full screen fixed and seen on screen. Open: T26 full custom XP theme (user will say when);
taskbar part: docs/TASKBAR_PLAN.md jobs T29-T36 all built, seen on screen (T30-T35) and reviewed. Next: user feedback. Settings reset/restore: request runs once (`doneReset` guard).

## Testing tips
- See the menu: in the INSTALLED copy only, add
  `Timer { interval: 5000; running: true; onTriggered: root.expanded = true }` after `searchText`,
  `systemctl --user restart plasma-plasmashell.service`, wait 9 s, `spectacle -b -n -f -o x.png`, crop
  the bottom-left. Then `./install.sh` again to remove the timer. Errors: `journalctl --user --since "-15 s" | grep start12`.
- More than ~5 plasmashell restarts in a short time trip systemd's limit:
  `systemctl --user reset-failed plasma-plasmashell.service` then start it.
- Don't test while the user is actively using the PC; each restart flashes their panel.
- Never edit files with Python slice/replace on ambiguous anchors (it once wiped main.qml); use Edit.
- Plasma 6.7 kicker: RunnerModel `runners: []` = NO runners (main.qml spells out the default list); runner result rows have no runner id/matchId, so classify by `url`/`favoriteId` (SearchView `passes`).
- i18n (T25): `package/Messages.sh` extracts to `po/template.pot` and merges `po/es.po` (all 352 strings translated); `install.sh` compiles the .mo into `package/contents/locale/es/`. Re-run Messages.sh after adding strings.
- Plasma saves the popup size (applet [Configuration] popupWidth/Height) and ignores Layout.preferred*: full screen forces it via Layout.minimum*, leaving full screen caps it once via Layout.maximum* (`full.shrink`).
- T36: settings page `config/ConfigTaskbar.qml` ("Taskbar") holds xpTaskbarTheme, taskbarFollowsStyle, taskbarTheme/Color/Alpha/Radius/Line + buttons Edit panel (kglobalaccel "edit mode" shortcut) and Task Manager settings (evaluateScript); es.po retranslated.
- T30: `taskbarSearch`/`taskbarSearchWidth` (Taskbar page): QQC2.TextField in StartButton.qml right of the `face` item (button visuals anchor to `face`); typing sets root.searchText + expanded, the style then takes focus and keeps typing; press sets Plasmoid.status AcceptingInputStatus so the panel takes keyboard focus. Not run on screen.
- T32: "Pin to taskbar"/"Unpin from taskbar" on custom pins (PinnedGrid, Tile, AppCanvas, windows7, xp via `root.taskbarItem(id)`): main.qml `setTaskbarPin` writes ~/.local/share/applications/start12-pin-<md5 8>.desktop (`Tiles.pinDesktop`, NoDisplay) and edits the panel Task Manager `launchers` (evaluateScript); state in key `taskbarPins`. Not run on screen.
- T33: taskbar texture keys `taskbarImage` (PNG/JPEG path), `taskbarImageMode` tile|stretch|top|middle|bottom, `taskbarImageAlpha`, `taskbarImageTint` (Theme.highlightColor, `comp-op="multiply"`, QtSvg-only); xptheme.py `image=` puts a base64 `<image>` in the panel 9-slice center (tile = center sized to the image + `hint-tile-center`; align = 48:1 center with `preserveAspectRatio slice`); radius border band stays plain colour. Only with "Override the taskbar colour"; checked by rendering with PySide6 QSvgRenderer, not on screen.
- T34: `taskbarButtons` plasma|win10|win11|win7 + `taskbarFocusedSolid`; xptheme.py `buttons= accent= solid=` (replaces `sub=flat`) writes tasks.svg (plasma = none, fallback's used); indicators via frame(`under=`) on the bottom edge only (bottom panel). T35 presets carry their own buttons=. Checked by 9-slice rendering in PySide6.
- Automatic accent = the user's own accent read from kdeglobals (General AccentColor, else their saved scheme Selection) in `readBrightness()` -> `root.userAccent`; never Kirigami.Theme.highlightColor (it follows the scheme/style Start12 applied). Accent schemes set Selection = accent.
- T40: design mode `root.designMode` (Start button "Edit menu layout", Layout page button via `designRequest` evaluateScript; `hideOnWindowDeactivate: !designMode`, top bar Reset/Done) + `common/SplitHandle` + key `splits` (`root.splitFor/setSplit`, `Tiles.splitGet/Set/Reset`). Win10 list / App canvas grow the popup (min = max = opening width + implicitWidth gain); Win7/Modern/XP/Pro size the right column, implicitWidth keeps the default so the left side gives way. Not run on screen.
- Popup size: after a style/menu-size switch or leaving full screen, `full.shrink` pins min=max to the style implicit size for one opening, so every style opens at its own size (Plasma keeps one saved size). Design bar sits above the menu (frame moves down).
- 2026-10-14 end of session: repo public at https://github.com/Kalaminator/Start12 (MIT). taskbarFollowsStyle now default true
  (taskbar follows every menu style, not only XP; checked: win10/win11/win7 get their own start12-taskbar-*, modern/app/pro/launcher
  share the win11 one). 11 languages in po/. Next idea (not started): per-style Start buttons like the XP pill (Win7 orb, Win10/11 look).
