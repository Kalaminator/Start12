# Windows 12 style plan (2026-10-16)

Concept-art "Windows 12" menu + floating split taskbar. References (session images dir
`/tmp/claude-1000/-home-kalaminator-Documents-Start12/0d01216d-ed9e-4a5b-96d0-b8512fb89c1f/images/`):
- `12.png` light menu: left rail (hamburger, power), A-Z list with round letter chips, right "Pinned" panel = icon grid
  with 2x2 live widgets (Weather, Outlook calendar, folder "Creativity"), page dots; one floating translucent bar.
- `18.png` dark menu: Pinned grid + "Recent" file rows left, "All Apps" with search + Most Used + A-Z right, user footer
  (picture, name, folder/settings/power buttons).
- `20.png` light: big round picture + "Good Afternoon, <name>!" + email, search, A-Z on the LEFT; right: folder chips
  (Documents/Pictures/Music), clock + date, "Pinned" card (+ "All apps" pill), "Your last activities" card (2 columns,
  "See more"). Taskbar split: left island Start/search/apps, right island weather + tray + clock.
- `13.png` / `15.png` / `17.png` taskbar only: three floating islands (left weather, centre Start + tasks, right tray + clock)
  or two (centre, right).

Rules as in docs/TASKBAR_PLAN.md: one agent per task, `./install.sh`, check on screen, errors via `journalctl`, new keys in
`config/main.xml` with a `<label>`, es strings via Messages.sh + po/es.po. Context cap ~100k tokens / ~40 tool calls per
agent: commit at a safe point, write a 3-line handoff (done / left / next), stop. **Only ONE task at a time may run
`./install.sh --restart` or touch the user's real panel** (marked [restart] below); the others are code-only or run in the
nested session (HANDOFF "Testing tips": nested kwin_wayland + plasmashell with isolated XDG dirs).

## Design (what reuses what)

Menu = `ui/styles/windows12.qml`, ONE layout with two columns that can swap sides (new key `win12ListSide`):
- **List column** (18.png right / 20.png left): optional greeting header (`win12Greeting`: round Avatar 64 px, "Good
  morning/afternoon/evening, <name>!" from the hour, email line hidden when unknown), `common/SearchBox`, "Most used"
  (first 5 of the usage model, like windows7.qml most-used), `win10/AppList` with round letter chips (12.png) = AppList
  section headers styled as `m.px(36)` circles (new AppList prop `chipHeaders: true`, default false so Win10/11 keep theirs).
- **Cards column** (12.png / 20.png right): header row = folder chips (Documents, Pictures, Music = `Places` items filtered
  by id, key `win12Chips`) + clock/date (`widgets/Clock.qml` logic, text only); "Pinned" card = `common/PinnedGrid`
  (pages + dots already there, `fixedCols/fixedRows` from `pinnedCols/pinnedRows`) with an "All apps" `SmallButton` pill
  that swaps the list column to the full A-Z (same `view` idea as windows11.qml); "Recent" / "Your last activities" card =
  `common/Recommended` in 2 columns (prop `columns: 2`, `showRecommended` key) + "See more" (`view = "more"`).
- Footer (18.png): `common/Places` bottom bar: Avatar + name left, `bottomItems` + power right (windows11.qml does this).
- Colours: `Metrics` (colorMode light/dark/custom), `MenuBackground` (menuOpacity, cornerRadius, textures). Cards =
  `Qt.alpha(m.text, 0.06)` panels with radius `m.px(12)`; light default = 12.png (white 55% + blur), dark = 18.png.
- Positions: Left/Center/Right via existing `menuPosition` (T42, `root.mirrorMenu` flips the frame). The references
  are two positions of ONE style: `20.png` = Left (greeting header, list left, cards right), `18.png` (= `22.png`) =
  Center (cards left: Pinned + Recent; list right: search, Most Used, A-Z with a letter rail; no greeting). So
  `win12ListSide` = 0 automatic (Left -> list left + greeting on, Center/Right -> list right + greeting off), 1 list left,
  2 list right; `win12Greeting` = 0 automatic / 1 on / 2 off. The side is applied AFTER mirroring (set `LayoutMirroring`
  off on the two-column RowLayout and order the columns from the resolved side) so "list left" is screen left in every
  position. The 18.png letter rail = AppList's existing jump grid reached from a thin vertical "A B C" strip at the
  list's outer edge (prop `letterRail: true`, optional, do last).
- Split: `common/SplitHandle` between the columns, split key `"win12"` (`root.splitFor/setSplit`).
- Keyboard: `common/KeyNav` panes = [list, cards, footer]; items `kbNav: true` + `KeyFrame {}` like windows11.qml.
- Window look: `windowDecoration()` maps windows12 -> `start12-win11-light|dark` (one line in main.qml; the 11 deco is
  already rounded glass). Taskbar preset below. Icons/Colours/Look/Layout pages apply unchanged (list in W1).

Taskbar = native Plasma features driven by scripts (precedent: `main.qml syncCenterPanel`, `evaluateScript` via
`Tiles.QDBUS`), look = generated Plasma Style (`xptheme.py --taskbar`, applied by `syncDesktopTheme`):
- Floating + translucent: scripting `panel.floating = true`, `panel.opacityMode = "translucent"` (names confirmed in
  `/usr/bin/plasmashell`: floating, opacityMode, lengthMode, alignment, offset, hiding, minimumLength, maximumLength,
  addWidget, remove). Blur = KWin Blur on the panel's `translucent/` prefix mask: already written by `taskbar()`; turn the
  effect on through the existing `wantBlur`/`savedBlur` path (T41).
- Roundness: existing `taskbarRadius` (xptheme clamps 2..24; raise the clamp to 40 so a 46 px panel can be a full pill;
  the UI maps the slider end to "round" = thickness / 2). Colour/opacity: existing "Override the taskbar colour"
  (`taskbarTheme=custom`, `taskbarColor`, `taskbarAlpha`, `taskbarLine`, `taskbarImage*`, `taskbarButtons`).
- Breeze's `panel-background.svgz` has no `floating-*` prefix, so Plasma pads a floating panel by 8 px (Panel.qml
  `fixedBottomFloatingPadding`); our svg replaces the whole file, so the `shadow-*` group disappears -> floating bar
  without shadow (acceptable; W3 may copy a soft `shadow-*` 9-slice from `frame()` later).
- Islands: Plasma has one Plasma Style for all panels (no per-panel colour), but each panel has its own floating,
  length (`lengthMode = "fit"`), alignment and opacity -> islands are extra panels, same generated style.

## Tasks

### W0 Spike: panel scripting in the nested session (S, no restart, parallel-safe)
Files: none in the repo (scratch script under `/tmp/claude-1000/.../scratchpad/`); result = a note in this file (W0 section).
Do: in the nested kwin_wayland + plasmashell (HANDOFF recipe, isolated XDG dirs) run `evaluateScript` checks:
1. `p.floating = true/false`, `p.opacityMode = "translucent"`, `p.lengthMode = "fit"`, `p.alignment = "center"` on the
   existing panel: do they apply live and land in `plasmashellrc [PlasmaViews][Panel N]` (floating=1) /
   appletsrc (panel `General` group)? Read them back (`p.floating`) for the restore path.
2. `const q = new Panel(); q.location = "bottom"; q.floating = true; q.lengthMode = "fit"; q.alignment = "right";
   q.height = p.height; q.addWidget("org.kde.plasma.digitalclock")` -> a second floating island next to the first?
   Do two bottom panels overlap or stack (Plasma stacks same-edge panels unless `lengthMode = fit` + different
   alignment; note the real behaviour and `q.offset`).
3. **Move an existing widget**: `q.addWidget(w)` where `w` is a Widget object from `p.widgets()` (the scripting
   `Containment.addWidget` accepts a Widget to move it). Check the tray keeps its config ([Applets][id] group moves).
   If it does NOT, fallback = `addWidget(type)` + copy every config group (`configGroups.slice()` pattern from
   `migrateConfig`) + `old.remove()`; note which one works.
4. `q.remove()` and `p.floating = saved` restore cleanly; the moved widget back with the same call.
Verify: notes with the exact working calls. Risk: the nested session has no blur; that is fine here.

**W0 result (2026-10-16, nested kwin_wayland --socket s12nest + plasmashell, fresh HOME/XDG dirs, default panel id 2 with kickoff, pager, icontasks, marginsseparator, systemtray id 7, digitalclock, showdesktop):**
- Recipe gotchas: the nested kwin needs the OUTER `WAYLAND_DISPLAY=/run/user/1000/wayland-0` (absolute) while `XDG_RUNTIME_DIR` is a new SHORT dir (`/tmp/s12w0r`; the socket path must be < 108 bytes, the scratchpad is too long). `evaluateScript` returns nothing unless the script `print(...)`s; call `qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "<js>"`, then wait ~4 s before the next read. spectacle crashes nested; kwin-script `print` did not reach the log, so on-screen overlap was NOT seen (see 2).
- 1. `p.floating = true`, `p.lengthMode = "fit"`, `p.alignment = "center"` apply live and read back (`p.length` stays 552). `p.opacityMode` is NOT in the 6.8 API: the assignment is silently a plain JS property (reads back what you set, real value `undefined`) - drop opacity from the plan. Persistence: plasmashellrc `[PlasmaViews][Panel 2]` (floating, alignment, panelLengthMode) was NOT updated within 4 s (still floating=0, alignment=1, panelLengthMode=0); it is flushed lazily, so for restore read the saved values back from `p.floating/p.lengthMode/p.alignment` and store them in our own key (like `start12Fill`), do not rely on the rc.
- 2. `const q = new Panel(); q.location="bottom"; q.floating=true; q.lengthMode="fit"; q.alignment="right"; q.height=p.height; q.addWidget("org.kde.plasma.digitalclock")` works: new panel id 39, widget 40, own `[Containments][39]` + `[General] AppletOrder=40`, height 46 as asked, length fits the content (120 vs main 402-552). Both panels stay on the same bottom edge with independent length/alignment (`q.offset` is settable, reads back 200). Not verified on screen whether centre-fit + right-fit panels overlap or push each other: W5 must check this first with a screenshot of the real or nested session (fallback in W5 stays valid).
- 3. MOVE WORKS with the Widget object: `q.addWidget(w)` with `w` from `p.widgets()` returns the widget with the SAME id (7) and type, it leaves the old panel (`p.widgetIds` loses 7) and appears in `q.widgetIds`; the tray's `[Containments][..][Applets][7]...` groups followed it (config kept, a custom `[General] s12test` key survived). No copy fallback needed. Moved widget lands at the END of the new panel (idx after existing ones) and, when moved back, at index 0 of the old one (`systemtray idx=0` instead of 2): after moving back set `w.index = n` per widget in the saved order, one move per script pass (HANDOFF: several index sets in one script land out of order).
- 4. `q.remove()` works (panel gone from `panels()`); `p.floating=false; p.lengthMode="fill"; p.alignment="left"` restore live. Moved-back tray kept id 7. Round trip done: panel read back fl=false lm=fill al=left, 7 widgets, only the order differed (fix with `index`).
- Risks for W5: opacityMode unavailable; order must be restored via `index`; verify side-by-side placement on screen first.

### W1 Menu style windows12.qml (L) [restart]
Files: new `ui/styles/windows12.qml`; `main.qml` `builtStyles` + `windowDecoration()` (windows12 -> win11 light/dark)
+ `taskbarPresets.windows12` (see W3 values, can land here as a string); `config/ConfigStyle.qml` `built` + the style
row ("Windows 12 style", "Concept-art menu: app list beside pinned cards and widgets."); `config/StylePreview.qml`
branch; `config/main.xml` keys in a new `<group name="Win12">`: `win12ListSide` Int 0 automatic / 1 list left / 2 list right
(default 0), `win12Greeting` Int 0 automatic / 1 on / 2 off (default 0), `win12Chips` Bool (true), `win12Clock` Bool
(true); `config/ConfigMenu.qml` group visible for windows12: list side combo (Automatic: Left = list left, Centre/Right =
list right), greeting combo, chips/clock checkboxes (next to the existing windows11 options: showSearchBox,
showRecommended, pinnedCols/Rows, openAllApps - all reused); `win10/AppList.qml` props `chipHeaders` (12.png chips) and
`letterRail` (18.png strip, optional); `common/Recommended.qml` prop `columns`; Messages.sh + es.po.
Build in this order: columns + swap + footer -> cards -> greeting/chips/clock -> KeyNav -> letter rail -> preview. Keep
windows11.qml open as the template (implicitWidth/Height via `m.heightFor`, `full.shrink` sizing rules in HANDOFF).
Verify on screen: light and dark (Colours page mode); menuPosition Left = 20.png (greeting, list left), Center = 18.png
(Pinned + Recent left, list right, footer), Right mirrored; forcing list side 1/2 overrides the position in all three;
search typing swaps to SearchView and Esc returns, All apps pill, Recommended rows open files,
Tab/arrows walk list -> cards -> footer, no QML errors in journalctl. Reuse check: Look (opacity, radius, texture,
font), Layout (pinnedCols/Rows, menuSize), Left side (railItems -> footer buttons), Colours, Icons pages all act.
Risk: popup width = list + cards; cap with `menuSize` like windows11 (Small = 2 pinned cols). Widgets inside the
Pinned grid are W2, not here (plain pins only).
Status (2026-10-16): done, seen on the real panel: Left light (20.png), Centre dark (18.png), Right mirrored with list
forced left, Right auto + search (SearchView in the list column, own field hidden); no QML errors. Chips/clock row only
in the list-left layout; AppList `mostUsed` prop (always on here). Skipped: `letterRail`, email line (KUser has none),
taskbarPreset (falls back to windows11, W3). Not checked live: keyboard Tab/arrows, Esc, All apps pill, More view, design-mode split.

### W2 Live widgets in the Pinned card (M) [restart]
Files: `common/PinnedGrid.qml` (render `widget|<kind>|<n>` ids as 2x2 cells with a Loader on `widgets/<Kind>.qml`,
props `metrics/size="large"/active`, click no-op, "Remove widget" menu); `main.qml` `pinNew`/`widgetItems` reuse so the
empty-space menu gets "Add widget" for grid styles (`Tiles.addWidget` already makes the ids; `pinnedGrid` list stores them);
tiles.js pack: 2x2 placement in a paged grid (`Tiles` helper + `tests/test_tiles.js` case).
Verify: 12.png look (Weather 2x2 beside 1x1 icons, page dots still right), drag reorder around a 2x2 cell, Win11/Pro/
Launcher grids unaffected when no widget ids. Risk: paging math with mixed cell sizes; keep widgets page-local.

### W3 Taskbar look preset + floating + blur (M) [restart, touches the real panel]
Files: `main.qml` `taskbarPresets.windows12` = `"colour=" + (win10AccentStart ? accentHex : winDark ? "202028" : "f7f7fb")
+ " alpha=" + (win10Transparency ? (winDark ? 0.6 : 0.55) : 1) + " radius=" + win12Radius + " line=0 buttons=win11"`;
new key `taskbarFloating` Bool (Taskbar page, default true for windows12 preset only) + `taskbarRound` Int (0..100 % of
half the thickness, default 100 for windows12; custom override keeps `taskbarRadius`); `xptheme.py taskbar()` radius clamp
2..40; `syncCenterPanel`-style script `syncFloating()` in main.qml: on windows12 (or `taskbarFloating`) saves the panel's
`floating`/`opacityMode` into the panel's `General` keys `start12SavedFloating`/`start12SavedOpacity` (only if not yet
saved, like `start12Fill`), sets floating + translucent; off/leaving the style = put them back and clear the keys. Blur:
extend `wantBlur` with `|| taskbarFloating && alpha < 1` so KWin blur turns on (and `savedBlur` restores it).
Verify on screen: bar floats with rounded translucent blurred body (12.png), light/dark follow the Colours page, slider
from square to pill, custom colour/opacity from "Override the taskbar colour" still win, switching to Windows 10 style
restores a docked opaque panel and the user's Plasma Style, reset (Settings reset) restores too.
Risks: this edits the user's real panel (`plasmashellrc` floating) - keep the idempotent flock loop pattern of
`syncCenterPanel`; `AdaptiveTransparency enabled=false` in our theme rc means Plasma never turns the bar opaque when a
window touches it (wanted); the shadow goes missing (see Design); panel thickness is the user's (46 px) - do not change it.

**W3 result (2026-10-16, real panel):** done as `main.qml panelWant` + `syncPanelLook()` (one evaluateScript under the panel flock; generic per property, user value in the panel's `start12Saved_<prop>` General key). Floating: Windows 12 = `taskbarFloating` (default on); every other style with our taskbar theme (XP, Win7/10/11 presets, custom) = floating off (Show Desktop no longer lifts the bar); no theme = user's value back. Auto-hide: new key `taskbarHiding` 0 off (user's own) / 1 `dodgewindows` / 2 `autohide` (6.8 names verified by read-back), combo on the Taskbar page (es.po). Corners: `taskbarRound` (default 30 %, like 12.png; 100 = pill), radius from the applet's thickness + 4; xptheme clamp 40, frame grows to fit, side margins `r - 10`. Blur: `wantBlur || win12Taskbar && win10Transparency`. Seen on screen: floating light translucent pill, dark square-ish, accent (user has accent taskbar on) red; restore to user's floating=1 when our theme goes off. Plasma 6.8 cannot keep a floating panel floating over maximized windows (panelview de-floats; no API/option) except in auto-hide/dodge modes. W4: floating switch + corner slider still to add.

### W4 Settings UI: Windows 12 taskbar group (S, no restart needed for PySide6 render; [restart] to see live)
Files: `config/ConfigTaskbar.qml` group "Windows 12 taskbar" visible for windows12 or `taskbarFloating`: floating switch,
corner slider (`taskbarRound`, labels Square ... Round), layout combo `taskbarLayout` String `single | split-left |
split-right` (new key, default single; labels "One bar", "Widgets left, tray right (13.png)", "Start left, tray right
(20.png)"), help text "Islands are extra Plasma panels; Edit panel to move widgets"; `main.xml` labels; es.po.
Verify: page renders (PySide6 render or the real dialog), keys write, combo disabled until W5 lands (or hidden).

### W5 Split islands (L) [restart, touches the real panel] - after W0 and W3
Files: `main.qml` `syncIslands()` script (same shape as `syncCenterPanel`: idempotent, marked panels/widgets,
`start12Island` key on the island panels, `start12Layout` on the main panel with the saved order + which widget ids moved):
- `split-left` (13.png): island L = new panel left, fit, floating, holds `org.kde.plasma.weather` (a fresh one; the
  user can configure it) ; main panel = centre island (`lengthMode = "fit"`, `alignment = "center"`, Start + tasks);
  island R = new panel right, fit, floating, receives the MOVED tray + clock + show-desktop (W0 call) in their old order.
- `split-right` (20.png): main panel = left island (fit, left) with Start + search + tasks; island R = weather (fresh,
  only if `win12Chips`... no: key `islandWeather` Bool) + moved tray + clock.
- `single`: move widgets back to the main panel in `start12Layout` order (`Widget.index`), `remove()` islands, restore
  lengthMode/alignment. Leaving the style or resetting settings runs the same `single` path.
Verify on screen: both splits and back to single twice (no duplicates, tray config kept: hidden icons list, clock
format), plasmashell restart keeps the layout (script is a no-op when already right), reset puts everything back; a
second monitor's panel is left alone (match panel by `Plasmoid.screen` + `widgetIds.indexOf(Plasmoid.id)`).
Risks: this is the only task that can lose the user's panel setup - take the appletsrc/plasmashellrc backup first
(`cp ... .bak-start12`, HANDOFF), never `remove()` a widget before its copy exists; island panels inherit the global
Plasma Style so they look the same (wanted); Plasma may stack same-edge panels instead of placing them side by side ->
W0 decides (fallback: islands only for Left/Right alignment with `lengthMode = fit`, main panel centre).

**W5 result (2026-10-16, real panel):** done as `ui/code/islands.js` (run by `main.qml syncIslands()`: sed puts the widget id in, shell loop up to 40 passes 1 s apart under the panel flock, idempotent, gated in the script on menuStyle=windows12 + taskbarFollowsStyle, so XP/other styles always get `single`). Panel key `start12Layout` = {mode, lm, al, order, moved, L, R}; islands marked `start12Island`; a switch between the two splits keeps the first saved values. Facts: a centred fit panel and a right fit panel on the same edge sit side by side (no overlap, no stacking); a widget moved into a just-made EMPTY panel stays unplaced (index -1, "Add Widgets" shown) -> the script moves it out and in again; a move lands at index 0 of the target, so order is fixed with `index`, one move/index per pass. Islands copy floating/hiding from the keys (not from the panel: syncPanelLook may not have run yet). Seen on screen: split-left (13.png), split-right (20.png), plasmashell restart in split-right = no-op, single and leaving the style restore order 29;4;5;6;7;21;22 + fill/center exactly, extra panels gone. Limits: a live-moved tray shows only some icons until the next plasmashell start (config kept); the weather island is a fresh widget each time (its config goes with the island); centerTaskbar spacers + split not tested; second monitor not tested (islands go to the panel's edge, `new Panel()` screen = Plasma's choice).

### W6 Docs + strings + preview polish (S, no restart)
Files: `docs/HANDOFF.md` (Style status entry for windows12, keys, scripts, restore path), `docs/FEATURES.md`,
`po/es.po` for all new strings, `config/StylePreview.qml` thumbnail. Verify: `./install.sh` test step passes, Messages.sh
leaves no untranslated msgstr.

Order: W0 and W1 in parallel (W0 nested, W1 is the [restart] slot) -> W3 -> W4 -> W2 and W5 (W5 holds the [restart]
slot, W2 waits or works code-only with PySide6/qmlscene checks) -> W6. W4 can be written while W3 runs (no restart).

### W7 Always-floating island + pop-up animation (2026-10-16, real panel)
- Plasma 6.8 `Panel.qml`: a floating panel with any non-normal visibility (`autohide`, `dodgewindows`, `windowsgobelow`) never de-floats (floatingnessTarget = 1); normal visibility docks when a window touches it. Picked `autohide`: windows maximize to the full screen, the bar shows as the island (8 px margins measured) only when the edge is touched. Windows 12 + `taskbarFloating` now means `autohide` when `taskbarHiding` = 0 (main.qml `panelWant`, islands.js); the user's own value is saved/restored by `syncPanelLook` as before; other styles unchanged.
- Gotcha: that rule is only re-evaluated when `floating` (or a touch/opacity trigger) changes, so a live hiding change keeps the old dock/float state; `syncPanelLook` toggles `floating` off/on when it changed `hiding`. At plasmashell start it is right on its own.
- Animation: plasmashell asks KWin's built-in `slidingpopups` slide for every panel; that stays. A small KWin JS effect `extras/start12-panelpop` (installed by setup.sh with kpackagetool6, id `start12panelpop`) adds to it on `EffectWindow.windowHiddenChanged` of docks: 1 fade, 2 zoom (default), 3 rise. `animate({keepAlive: true})` keeps the hidden panel painted, so the hide animates too (seen at 3 s test duration). Key `taskbarPopAnim` (0 = Plasma slide only), combo on the Taskbar page Windows 12 group; main.qml `syncPanelPop()` writes kwinrc `[Effect-start12panelpop] Animation` + `Plugins/start12panelpopEnabled` and (re)loads the effect; leaving the style deletes the key and unloads it.
- Not seen: the live XP -> Windows 12 switch with the new nudge (restart path seen); the effect also animates any other dock (Windows 12 only); the "Auto-hide: Off" label now means auto-hide for the floating Windows 12 bar.

### W8 Glass by default (2026-10-16, real panel, seen on screen)
- Taskbar: Windows 12 preset alpha 0.4 with the accent taskbar (was 0.55/0.6 = looked solid red); "Override the taskbar colour" still sets any opacity.
- Start menu: `Metrics.bgAlpha` x0.75 for the windows12 menu (88 % -> 66 %); the popup already gets KWin blur (MenuBackground hides only the frame SVG, the dialog blur region stays). Seen: blurred, nothing sharp shows through.
- Title bars: KWin blurs behind Aurorae via the T41 `mask-*` pieces (seen in T41 and now). `main.qml windowOpacity` = 80 when the window look is Windows 12, `windowOpacity` is 100 and "Transparency effects" is on, so the T41 glass deco `start12-win11-<light|dark>[-accent-hex]-g80b1rdt0` is made (no separate win12 deco needed); Transparency off or any other windowOpacity = the user's.
- Taskbar page: auto-hide combo shows "Off (the floating bar still auto-hides)" + a hint for the floating Windows 12 bar (es.po).

## Task B: a lighter tray strip in the XP taskbar

How the Plasma 6.8 tray draws: there is NO package dir (`/usr/share/plasma/plasmoids/org.kde.plasma.systemtray` does not
exist). The applet is C++ `/usr/lib/qt6/plugins/plasma/applets/org.kde.plasma.systemtray.so` with its QML in a qrc
(`:/qt/qml/plasma/applet/org/kde/plasma/systemtray/`), and its items come from the compiled QML module
`/usr/lib/qt6/qml/org/kde/plasma/private/systemtray/libsystemtrayplugin.so` (AbstractItem, CompactApplet, ExpanderArrow,
HiddenItemsView... per its qmldir). It draws no background of its own; the Breeze `panel-background.svgz` has no
systray element either (checked: only panel/shadow/mask pieces), so no theme can tint just the tray.

Options:
1. **Draw it ourselves from the Start12 widget** (recommended). The widget already reparents an item into the panel
   window (`main.qml` ~1133: `popupAnchor.parent = btn.Window.contentItem`). Same trick: a `common/TrayBackground.qml`
   (gradient Rectangle or `KSvg.FrameSvgItem` from a new `start12-xp-*/widgets/traybg.svg` written by `xptheme.py` per
   colour scheme) parented into the panel's containment item with `z: -1`, positioned over the tray applet's geometry
   (walk the containment children for the item whose `applet.pluginName === "org.kde.plasma.systemtray"`, bind x/width;
   optionally extend over the clock to match XP's strip and draw the left divider line). Shown only while `xpTheme !==
   ""`, destroyed otherwise. No KDE code changed, ships in the store, survives Arch updates (if the lookup fails nothing
   is drawn). Risks: finding the item is by duck typing (test on 6.8; re-check after updates), vertical panels need the
   same for y/height, the bar sits behind applets but above the panel background only if parented inside the
   containment (not the window root). ~1 QML file + ~20 lines in main.qml + a few in xptheme.py.
2. User-level override of the tray package (`~/.local/share/plasma/plasmoids/org.kde.plasma.systemtray/`): KPackage
   looks in the data dirs before the qrc, so a copied upstream `main.qml` + a background item would probably load, but
   it must mirror the exact plasma-workspace version (it imports the private compiled module whose API moves every
   release), it changes the tray for every theme/panel, and a store package cannot install it. Fragile; no.
3. Patch plasma-workspace: needs a rebuilt package on every Arch update, cannot ship via the KDE store, and reviewers
   would not take a tray background hook upstream without a theme element design. No.
A separate "tray panel" with its own look is not possible: the Plasma Style is global, only opacity differs per panel.

Recommendation: option 1, as a small task "X1 XP tray strip" after W0 (it can reuse W0's nested session for the item
lookup check), colours from `xptheme.py LUNA` (XP: tray strip = lighter blue `#0f8ef0`-ish gradient with a 1 px
`#1958b7` divider, olive/silver equivalents from the same tables).
