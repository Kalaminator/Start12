# Start12

A Start menu for **KDE Plasma 6** inspired by Stardock Start11: eight menu styles (Windows 10, 11, 7, XP,
Modern, App, Pro, Launcher), a matching taskbar, matching window title bars and colours, and a settings
window with everything in one place.

*Español más abajo.*

## Features

- **8 menu styles**: Windows 10 (live-tile groups, folders, pages), Windows 11 (pinned grid, folders,
  recommended), Windows 7 and Modern, Windows XP (Classic and Modern, Blue / Olive Green / Silver / custom
  colour, green "start" button), App (tabs and coloured groups), Pro, Launcher.
- Search with filter icons (apps, settings, documents, music, pictures, videos, files, web) and search history.
- Pin apps, websites, files and folders; hide apps; rename pins; keyboard navigation.
- **Taskbar**: a Plasma Style that follows the menu style (Windows 10/11/7/XP), colour, transparency,
  texture, button style, search box, pin to taskbar, auto-hide toggle.
- **Windows**: matching title bars (Aurorae) and colour schemes, accent colour on Start, taskbar and title bars
  (Windows-like *Colours* page with the 48 Windows accent colours).
- Design mode: drag the dividers between menu sections.
- Full-screen menu, backup / restore / reset of all settings.
- 11 languages: English, Spanish, French, German, Italian, Brazilian Portuguese, Russian, Arabic,
  Simplified Chinese, Japanese, Hindi (it follows your Plasma language).

Everything you change (taskbar style, title bars, colours) is undone when you switch it off: Start12 saves
your own Plasma Style, window decoration and colour scheme first.

## Requirements

- KDE Plasma 6 (tested on Plasma 6.7, Arch Linux, Wayland)
- `python3` (generates the taskbar styles, title bars and colour schemes)
- `qdbus6`, `kreadconfig6`, `kwriteconfig6`, `kpackagetool6` (part of Plasma / KDE Frameworks)
- Optional: `gettext` (rebuild translations), `nodejs` (developer tests)

## Install

```sh
git clone https://github.com/Kalaminator/Start12.git
cd Start12
./install.sh            # add --restart to reload Plasma right away
```

Then right-click your panel → *Add or Manage Widgets* → search **Start12** and drag it to the panel
(or replace your current launcher with it). Open its settings with right-click → *Configure Start12*,
or run `start12-settings`.

Update: `git pull && ./install.sh --restart`.
Remove: `kpackagetool6 -t Plasma/Applet -r org.start12.menu`.

## Images not included

Start11's own Start button images and menu/tab textures are copyrighted by Stardock and are **not** part of this
project. The *image* Start button mode and the textures work with any PNG: pick your own file in the settings,
or put PNG files in `package/contents/images/StartButtons/`, `MenuTextures/` or `TabTextures/` before
`./install.sh`. The default Start button is the KDE logo (`start-here-kde`); change it under Settings → Start Button.

## Project layout

- `package/` — the Plasma widget (`org.start12.menu`): `contents/ui/main.qml`, one file per style in
  `contents/ui/styles/`, shared parts in `contents/ui/common/`, settings pages in `contents/ui/config/`,
  pure logic in `contents/ui/code/tiles.js`, theme generator `contents/ui/code/xptheme.py`.
- `tests/test_tiles.js` — tests for the pure logic (`node tests/test_tiles.js`).
- `po/` — translations (`package/Messages.sh` extracts strings).
- `docs/` — design notes (`HANDOFF.md`), job list (`TODO.md`), Start11 feature research.

## License

[MIT](LICENSE): free to use, copy, modify, share and sell. Contributions welcome.

Start12 is an independent project, not affiliated with or endorsed by Stardock or Microsoft. Windows and
Start11 are trademarks of their owners.

---

# Start12 (español)

Un menú Inicio para **KDE Plasma 6** inspirado en Stardock Start11: ocho estilos de menú (Windows 10, 11, 7, XP,
Modern, App, Pro, Launcher), una barra de tareas a juego, barras de título y colores de ventana a juego, y una
ventana de configuración con todo en un sitio.

## Instalar

```sh
git clone https://github.com/Kalaminator/Start12.git
cd Start12
./install.sh            # añade --restart para recargar Plasma
```

Después: clic derecho en el panel → *Añadir o gestionar widgets* → busca **Start12** y arrástralo al panel.
La configuración se abre con clic derecho → *Configurar Start12*, o con `start12-settings`.

Necesitas Plasma 6, `python3` y las herramientas de KDE (`qdbus6`, `kreadconfig6`, `kpackagetool6`).

Todo lo que cambia (estilo de la barra, bordes de ventana, colores) se deshace al apagarlo: Start12 guarda antes
tu tema de Plasma, tus bordes y tus colores.

Las imágenes de Start11 (botones de inicio y texturas) son de Stardock y **no** se incluyen. Puedes usar cualquier
PNG tuyo desde la configuración. El botón de inicio usa el logo de KDE; lo puedes cambiar en Configuración → Botón de inicio.

## Licencia

[MIT](LICENSE): puedes usarlo, copiarlo, cambiarlo, compartirlo y venderlo libremente.

Start12 es un proyecto independiente, sin relación con Stardock ni Microsoft.
