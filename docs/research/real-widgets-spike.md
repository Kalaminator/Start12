# Spike: hosting real Plasma widgets as tiles (Plasma 6.7, Wayland)

Date: 2026-10-15. Read-only research + one throwaway experiment (`plasmawindowed`, own config file,
backed up and restored; nothing in plasmashell or the panel was touched). Verdict: **feasible, pure QML,
no C++**.

## How Plasma does it today

- Plasma 6 system tray and the "Grouping Plasmoid" (kdeplasma-addons) are no longer "applet + hidden
  internal containment". Each is a `Plasma::Containment` subclass with
  `"X-Plasma-ContainmentType": "CustomEmbedded"` in `metadata.json`, placed **directly inside the panel
  as a normal applet**. Their C++ is now only legacy config migration (`migrateFromContainer`) plus,
  for the tray, SNI handling. The hosting mechanism itself is all in libplasma:
  - `PluginLoader::loadApplet` creates a `Containment` object whenever the package metadata has
    `X-Plasma-ContainmentType` (pluginloader.cpp:89).
  - `Applet::isContainment()` is true for `CustomEmbedded` even when nested
    (applet.cpp:936 `return qobject_cast<Corona*>(parent()) || type == CustomEmbedded`).
  - `Applet::containment()` of a CustomEmbedded containment returns its *parent* (the panel), so
    `Plasmoid.containment`, `.corona` etc. keep working as before (applet.cpp:739).
  - `Containment::addApplet` on the panel restores a nested containment "even if new, to have the
    same behavior of Corona::addContainment" and calls `init()` on it (containment.cpp:437-445).
  - Child applets persist under the host's own applet group:
    `[Containments][<panel>][Applets][<win12>][Applets][<child>]` via `saveContents`/`restoreContents`
    recursion; `configNeedsSaving` is chained up to the corona. No extra bookkeeping needed.
- The QML root of a containment must be `ContainmentItem` (extends `PlasmoidItem`; compact/full
  representation, `Plasmoid.*`, `Plasmoid.configuration`, config dialogs are unchanged).
  `ContainmentItem` exposes (plasmoidplugin.qmltypes, `org.kde.plasma.plasmoid`):
  - `Containment.applets` (attached, list of `Plasma::Applet`), `Containment.onAppletAdded(applet)`,
    `Containment.onAppletRemoved(applet)`
  - `itemFor(applet)` -> the live `AppletQuickItem` (a `PlasmoidItem`) to reparent anywhere
  - `processMimeData(mimeData, x, y)` -> for `text/x-plasmoidservicename` it queues `createApplet`
    (containmentitem.cpp:395-404)
  - `createApplet(plugin, args, geom)` exists but is a **private slot**, not callable from QML
    (verified: `typeof root.createApplet === "undefined"`); `Containment::createApplet` is not
    Q_INVOKABLE either.
- The desktop/panel/folder-view containments and the grouping plasmoid's `qml/main.qml` are the
  reference consumers: grouping does exactly `const item = root.itemFor(applet); item.parent = container;
  item.anchors.fill = container; item.visible = true` in `Containment.onAppletAdded`.
- Alternatives considered and rejected: a real top-level containment via
  `corona.createContainment` (not reachable from QML; ShellCorona only exposes `evaluateScript`,
  `addPanel`, `toggleWidgetExplorer` as slots), desktop scripting (`evaluateScript` can only make
  panels/desktops), `org.kde.plasma.private.containmentlayoutmanager.AppletsLayout` (works, but it is
  the free-form desktop layout; our tile packer already does layout).

## Experiment (proof)

Throwaway package `org.win12.spike`: `metadata.json` with `"X-Plasma-ContainmentType": "CustomEmbedded"`,
`main.qml` root `ContainmentItem`, run with `plasmawindowed org.win12.spike` (Wayland session).
Log (run 1):

```
SPIKE isContainment true containmentType 129 parent containment org.kde.desktopcontainment restored applets 0 immutability 1
SPIKE typeof createApplet undefined itemFor function processMimeData function mimeData.setData function
SPIKE mime formats [text/x-plasmoidservicename]
SPIKE processMimeData called
SPIKE appletAdded org.kde.plasma.analogclock
SPIKE itemFor org.kde.plasma.analogclock id 5 item PlasmoidItem_QML_101(...)
SPIKE applet org.kde.plasma.analogclock id 5 ... 200x200 visible true parent QQuickRow(...)
```

Run 2 (same config): `restored applets 2`, both `org.kde.plasma.analogclock id 5` -> persistence works,
but the child was restored **twice** (two Applet objects, same id). libplasma's panel path restores a
nested containment exactly once (`addApplet` -> `restore` -> `restoreContents`), so this is probably
`plasmawindowed` re-adding; it must be re-checked in a real panel and guarded anyway (see risks).

## Approach for Win12 (chosen)

1. `package/metadata.json`: add `"X-Plasma-ContainmentType": "CustomEmbedded"`.
2. `package/contents/ui/main.qml`: `PlasmoidItem {` -> `ContainmentItem {` (same import). Everything
   else stays; `Plasmoid.isContainment` becomes true (not used by our code).
3. New tile kind `widget|<appletId>` next to `custom|...` in `tileGroups` JSON (`tiles.js` already treats
   ids opaquely). The tile body is the applet's item:

```qml
// main.qml (root is ContainmentItem { id: root })
import org.kde.draganddrop as DnD
DnD.DragArea { id: mimeSrc; width: 1; height: 1; enabled: false }   // only used as a QMimeData factory

property var widgetItems: ({})                                     // appletId -> AppletQuickItem
function hostWidget(applet) {
    if (widgetItems[applet.id]) return;                            // ponytail: dedupe double restore
    const it = root.itemFor(applet);
    if (!it) return;
    it.preferredRepresentation = it.fullRepresentation;            // show the widget, not its panel icon
    widgetItems[applet.id] = it; widgetItemsChanged();
}
function addWidget(pluginId, groupIndex) {
    mimeSrc.mimeData.setData("text/x-plasmoidservicename", pluginId);
    root.processMimeData(mimeSrc.mimeData, 0, 0);                  // async: Containment.onAppletAdded fires
    pendingGroup = groupIndex;
}
Containment.onAppletAdded: applet => { hostWidget(applet); if (pendingGroup >= 0) Tiles.place("widget|" + applet.id, pendingGroup); }
Containment.onAppletRemoved: applet => { delete widgetItems[applet.id]; Tiles.remove("widget|" + applet.id); }
Component.onCompleted: for (const a of Containment.applets) hostWidget(a)

// Tile.qml, when tileId starts with "widget|"
Item {
    id: slot; anchors.fill: parent
    property Item w: root.widgetItems[appletId]
    onWChanged: if (w) { w.parent = slot; w.anchors.fill = slot; w.visible = true }
}
// context menu: w.plasmoid.internalAction("configure").trigger(), w.plasmoid.internalAction("remove").trigger(),
// plus w.plasmoid.contextualActions. Remove -> appletRemoved -> tile removed.
```

4. Widget picker: `import org.kde.plasma.private.shell` gives `WidgetExplorer { containment: Plasmoid }`
   with `widgetsModel`/`filterModel` (the same model as the shell sidebar, includes compiled-in
   applets) and `addApplet(pluginName)` (calls `containment->createApplet`, so it can replace the mime
   trick). It is a "private" module of plasma-workspace, so treat it as optional and keep the mime path
   as the fallback. Users can also drag from the real widget sidebar onto a `DnD.DropArea` that calls
   `root.processMimeData(event.mimeData, x, y)` (grouping does this).

## Risks and mitigations

- **Double restore** (seen in plasmawindowed): dedupe by `applet.id` in QML; verify in a real panel
  (`./install.sh --restart`, then relogin) that `Containment.applets.length` equals the config groups.
- **Config persistence**: automatic (nested `[Applets]` group in `plasma-org.kde.plasma.desktop-appletsrc`).
  Our own `tileGroups` must reference `widget|<id>`; on restore, drop tiles whose id is gone
  (`Containment.applets` is the truth). Removing the Win12 applet removes its children with it.
- **Popup sizing**: hosted items size to the tile; set `preferredRepresentation = fullRepresentation`
  so a 1x1 tile does not fall back to the panel icon. Respect
  `item.fullRepresentationItem.Layout.minimumWidth/Height` when offering tile sizes (hide 1x1 for
  widgets that need more). Keep tile metrics; do not use `AppletsLayout`.
- **Applet stays alive when popup hidden**: yes. `PlasmoidItem` keeps `fullRepresentationItem` after
  first expansion and the hosted items are its children, so clocks tick and weather polls while
  collapsed (same cost as the grouping plasmoid). Optionally set `visible=false` on collapse to skip
  rendering; it does not stop timers.
- **Hosted applet popups** (digital clock calendar, system monitor details): they open as separate
  `PlasmaQuick.Dialog` windows parented to our popup; our `hideOnWindowDeactivate` would close the menu.
  Mirror the tray: while any hosted `item.expanded` is true set `root.hideOnWindowDeactivate = false`.
- **ContainmentItem input handling**: it owns right-click (containment context menu / actions plugin)
  and wheel on *unhandled* areas; our MouseAreas already accept all buttons on the menu, but check the
  empty-space right-click menus (`TileArea`/`PinnedGrid`) still show ours, not Plasma's.
- **Immutability**: `createApplet` returns null when widgets are locked (`Plasmoid.immutability !==
  Mutable`) unless the args carry `org.kde.plasma:force-create` (only C++ can pass args; the mime path
  cannot). Show "unlock widgets" hint in that case.
- **Store packaging**: unchanged, still a plain `.plasmoid` (one metadata key). Folder View ships the
  same key and is installable/listed normally. `kpackagetool6 -t Plasma/Applet` works (verified for the
  spike). Existing users: the key change is picked up on the next plasmashell start; existing
  config is untouched.
- **Wayland**: no special handling; the items render in our popup's `QQuickWindow` (verified in a
  Wayland session). Applets that spawn their own popups use xdg-popup via PlasmaQuick like everywhere.
- **API surface**: `ContainmentItem.itemFor/processMimeData`, `Containment.*` attached signals and
  `X-Plasma-ContainmentType=CustomEmbedded` are what the tray and grouping plasmoid use, so they are as
  stable as Plasma 6 itself. `org.kde.plasma.private.shell.WidgetExplorer` is the only private piece.

## Effort

- Metadata + root swap + hosting a widget tile with remove/configure: ~0.5 day.
- Widget picker (WidgetExplorer model, fallback mime path, drop from sidebar) + tile-size hints +
  popup/hideOnWindowDeactivate handling: ~1 day.
- Real-panel verification of restore/dedupe, immutability and right-click behaviour: ~0.5 day.
Total ~2 days, no C++, no build step.

## Follow-up (2026-10-15): why the real panel showed the menu inline, and the fix

Branch `worktree-agent-a72aa12b7388f2724` (ContainmentItem root + `CustomEmbedded`) lost the Start
button in the real panel: the full representation rendered inline, no popup. plasmawindowed could not
show it because there the form factor is Planar, where master also prefers the full representation.

**Root cause** (libplasma 6.7, `src/plasmaquick/appletquickitem.cpp`):

- `AppletQuickItemPrivate::appletShouldBeExpanded()` starts with `if (applet->isContainment()) return
  true;`. `switchWidth/Height`, `preferredRepresentation` and the form factor are only consulted in the
  `else` branch, so a containment never gets a compact representation and never a popup.
- `AppletQuickItem::isExpanded()` is `applet->isContainment() || !fullRepresentation || expanded`:
  `expanded` reads true forever (verified: `isExpanded true` before, during and after our own popup),
  `onExpandedChanged` is useless.
- `Applet::isContainment()` (`applet.cpp:936`) is `parent is Corona || type == CustomEmbedded`, and
  `ContainmentPrivate::createApplet` (`containment_p.cpp:172`) returns null when `!isContainment()`.
  So the same flag that makes hosting work (createApplet, restoreContents, UiReady) is the one that
  forces the full representation. There is no metadata key, property, Layout hint or `X-Plasma-*`
  flag that separates the two; a nested non-`CustomEmbedded` type (e.g. `"Custom"`) would give the
  compact/popup path back but then `createApplet` returns null, so option (a) is dead.
- Option (b) (plain `PlasmoidItem` owning a second internal containment, the Plasma 5 tray pattern)
  needs `Corona::createContainment`/`Containment::addApplet`, neither reachable from QML
  (`createApplet` is a private slot, desktop scripting only makes panels/desktops, `WidgetExplorer.addApplet`
  adds to the containment it is given, i.e. a sibling in the panel). Dead without C++.

**Chosen fix: the Plasma 6 system tray pattern (option c), no C++.** The tray is a `CustomEmbedded`
`ContainmentItem` with no `compactRepresentation`/`fullRepresentation` at all: its panel content is
its own child item and its popup is its own `PlasmaCore.AppletPopup` (`applets/systemtray/qml/main.qml`
lines 270-345). For Win12:

1. Root stays `ContainmentItem` (`CustomEmbedded`), all the branch's applet hosting stays.
2. Delete `compactRepresentation`/`fullRepresentation`/`preferredRepresentation`. `StartButton {}`
   becomes a direct child (`anchors.fill: root`); copy its Layout hints onto root
   (`Layout.minimumWidth/Height`, `preferredWidth/Height`), since with no `fullRepresentation` libplasma
   uses the root item itself as the representation and the panel reads root's Layout attached.
3. The old `fullRepresentation: Item { ... }` becomes `mainItem:` of
   `PlasmaCore.AppletPopup { id: popup; visualParent: root; appletInterface: root; popupDirection:
   <switch on Plasmoid.location, as the tray>; floating: Plasmoid.location === PlasmaCore.Types.Floating;
   removeBorderStrategy: <as the tray>; hideOnWindowDeactivate: !designMode; visible: root.menuOpen;
   backgroundHints: <as the tray> }`. `appletInterface: root` gives the saved popup size and the
   user's edge resize for free (AppletPopup, libplasma `appletpopup.cpp`), and it honours the
   mainItem's `Layout.minimum/preferred/maximum*`, so the full-screen and design-mode sizing code keeps
   working unchanged.
4. `property bool menuOpen: false` replaces every `root.expanded` read/write (main.qml `close()`,
   `onActivated`, `onExpandedChanged` -> `onMenuOpenChanged`; `StartButton.qml`; `win10/Tile.qml`
   `active`). Mirror plasma-desktop `CompactApplet.qml` 160-230: `Timer { id: expandedSync; interval:
   100; onTriggered: root.menuOpen = popup.visible }`, and in `popup.onVisibleChanged`: closed ->
   `expandedSync.restart(); Plasmoid.status = oldStatus`; open -> `oldStatus = Plasmoid.status;
   Plasmoid.status = PlasmaCore.Types.RequiresAttentionStatus; popup.requestActivate()` (keeps
   auto-hide panels open while the menu is up). Meta key still works: `ShellCorona::activateLauncherMenu`
   emits `activated` on the panel applet with `X-Plasma-Provides launchermenu`, so `onActivated:
   menuOpen = !menuOpen`.
5. Planar form factor (desktop widget / plasmawindowed): show the menu `Item` inline instead of the
   button + popup (a `Loader`/`parent` switch on `Plasmoid.formFactor === PlasmaCore.Types.Planar`),
   which is what `preferredRepresentation` did on master.
6. Hosted applet popups (digital clock calendar) open as windows parented to our popup; keep the
   earlier plan: while any `item.expanded` is true set `popup.hideOnWindowDeactivate = false`.

Proof (throwaway `org.win12.spike2`, plasmawindowed, isolated `XDG_CONFIG_HOME/DATA_HOME/CACHE_HOME`,
`QT_LOGGING_TO_CONSOLE=1` is needed to see `console.log` when stderr is not a tty):

```
t1 before open  isExpanded true  menuOpen false popup.visible false status 0 applets 4
t2 open         isExpanded true  menuOpen true  popup.visible true  status 4 applets 4
appletAdded org.kde.plasma.analogclock id 7 item PlasmoidItem_QML_104   (processMimeData, item reparented into the popup's mainItem)
t3 with clock   isExpanded true  menuOpen true  popup.visible true  status 4 applets 5
t4 closed       isExpanded true  menuOpen false popup.visible false status 0 applets 5
```

No QML errors or warnings. `status 4` = RequiresAttentionStatus while open. `Qt.quit()` does not end
plasmawindowed; run it under `timeout`.

**Verifying in a real panel without touching the user's session**: run a nested Plasma on its own
D-Bus and its own config/data dirs, so the real plasmashell, panel and `plasma-org.kde.plasma.desktop-appletsrc`
are never involved (standard KDE dev setup; not run in this research session):

```
T=/tmp/win12-nested; mkdir -p $T/config $T/cache $T/data/plasma/plasmoids
cp -r package $T/data/plasma/plasmoids/org.win12.menu        # the copy under test
dbus-run-session -- env XDG_CONFIG_HOME=$T/config XDG_DATA_HOME=$T/data XDG_CACHE_HOME=$T/cache \
  QT_LOGGING_TO_CONSOLE=1 kwin_wayland --width 1600 --height 900 --xwayland --exit-with-session=plasmashell
# in a second shell on the SAME nested bus (the dbus-run-session child env), add it to the nested panel:
#   qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript 'panels()[0].addWidget("org.win12.menu")'
# (or run plasmashell inside a wrapper script that does kwin_wayland ... & then the qdbus call after a sleep)
```

Check there: Start button visible in the nested panel (not the menu inline), click/Meta opens the popup
above the panel, hosted clock tile inside, right-click on the button gives the usual applet menu,
restart of the nested plasmashell restores one tile per widget. Only after that: `./install.sh --restart`
on the user's session, by the user.
