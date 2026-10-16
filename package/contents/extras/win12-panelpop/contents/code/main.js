"use strict";
// Win12 W7: animates panels (docks) when an auto-hidden panel shows or hides. KWin's own slide
// (slidingpopups, Plasma asks for it on every panel) still runs; this adds to it.
// kwinrc [Effect-win12panelpop] Animation: 1 fade, 2 zoom ("pop"), 3 rise (fade in from below).
var mode = 1;
function loadConfig() { mode = effect.readConfig("Animation", 1); }

function run(w, show) {
    if (!w.dock || mode < 1 || effects.hasActiveFullScreenEffect) return;
    if (w.s12Anim) { cancel(w.s12Anim); delete w.s12Anim; }
    const a = (type, from, to) => ({ type: type, from: show ? from : to, to: show ? to : from });
    const list = [a(Effect.Opacity, 0, 1)];
    if (mode === 2) list.push(a(Effect.Scale, { value1: 0.8, value2: 0.8 }, { value1: 1, value2: 1 }));
    if (mode === 3) list.push(a(Effect.Translation, { value1: 0, value2: w.height }, { value1: 0, value2: 0 }));
    w.s12Anim = animate({ window: w, duration: animationTime(show ? 220 : 160),
        curve: show ? QEasingCurve.OutCubic : QEasingCurve.InCubic, keepAlive: true, animations: list });
}
function watch(w) { if (w.dock) w.windowHiddenChanged.connect(() => run(w, w.visible)); }

loadConfig();
effect.configChanged.connect(loadConfig);
effects.windowAdded.connect(watch);
effects.stackingOrder.forEach(watch);
