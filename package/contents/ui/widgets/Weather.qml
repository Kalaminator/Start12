import QtQuick
import org.kde.kirigami as Kirigami

// Open-Meteo (no key). Tile props: loc = city typed in "Set location…", wx = cached result
// {q, place, lat, lon, t, unit, temp, code, days:[{date,code,max,min}]}. Refreshed every 30 min while the menu is open.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active
    property var tdata: ({})
    property var save: function (key, value) {}

    readonly property string loc: tdata.loc || ""
    // i18n is not reachable inside the XMLHttpRequest callbacks, so these texts are made here.
    readonly property string unavailable: i18n("Weather unavailable")
    readonly property string notFound: i18n("Location not found")
    readonly property var wx: tdata.wx && tdata.wx.q === loc ? tdata.wx : null
    readonly property bool fahrenheit: Qt.locale().measurementSystem === Locale.ImperialUSSystem
    readonly property bool tiny: size === "small"
    readonly property bool big: ["large", "wideLargeH", "wideLargeV", "hugeH", "hugeV"].includes(size)
    readonly property real u: Math.min(width, height)
    // Big tiles also hold the forecast row, so the top part shrinks to leave room for it.
    readonly property real k: big ? 0.75 : 1
    property string status: ""

    function icon(c) {
        return c === 0 ? "weather-clear" : c <= 2 ? "weather-few-clouds" : c === 3 ? "weather-overcast"
            : c === 45 || c === 48 ? "weather-fog" : c >= 51 && c <= 57 ? "weather-showers-scattered"
            : (c >= 61 && c <= 67) || (c >= 80 && c <= 82) ? "weather-showers"
            : (c >= 71 && c <= 77) || c === 85 || c === 86 ? "weather-snow" : c >= 95 ? "weather-storm" : "weather-clouds";
    }
    function deg(v) { return Math.round(v) + "°"; }
    function get(url, ok) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== 4) return;
            try { if (x.status === 200) { ok(JSON.parse(x.responseText)); return; } } catch (e) {}
            w.status = w.unavailable;
        };
        x.open("GET", url);
        x.send();
    }
    function refresh() {
        if (!loc) return;
        if (wx && Date.now() - wx.t < 1800000 && wx.unit === (fahrenheit ? "F" : "C")) return;
        const q = loc;
        const forecast = (place, lat, lon) => get("https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=4&timezone=auto"
            + (fahrenheit ? "&temperature_unit=fahrenheit" : ""), r => {
                w.status = "";
                w.save("wx", { q: q, place: place, lat: lat, lon: lon, t: Date.now(), unit: fahrenheit ? "F" : "C",
                    temp: r.current.temperature_2m, code: r.current.weather_code,
                    days: r.daily.time.map((d, i) => ({ date: d, code: r.daily.weather_code[i], max: r.daily.temperature_2m_max[i], min: r.daily.temperature_2m_min[i] })) });
            });
        if (tdata.wx && tdata.wx.q === q) forecast(tdata.wx.place, tdata.wx.lat, tdata.wx.lon);
        else get("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(q) + "&language=" + Qt.locale().name.split("_")[0], g => {
            if (g.results && g.results.length) forecast(g.results[0].name, g.results[0].latitude, g.results[0].longitude);
            else w.status = w.notFound;
        });
    }
    onActiveChanged: if (active) refresh()
    onLocChanged: if (active) refresh()
    Component.onCompleted: if (active) refresh()
    Timer { interval: 1800000; repeat: true; running: w.active; onTriggered: w.refresh() }

    component Lbl: Text {
        color: w.metrics.text
        font.family: w.metrics.font
        elide: Text.ElideRight
    }

    Lbl {
        visible: !w.loc || !w.wx
        anchors.centerIn: parent
        width: parent.width - w.metrics.px(12)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        maximumLineCount: 4
        opacity: 0.85
        text: !w.loc ? i18n("Right-click to set location") : (w.status || i18n("Loading…"))
        font.pixelSize: Math.max(8, Math.round(w.u * 0.12))
    }

    Item {
        visible: !!w.loc && !!w.wx
        anchors.fill: parent
        anchors.margins: w.metrics.px(6)
        Row {
            id: head
            anchors.top: parent.top
            anchors.horizontalCenter: w.tiny ? parent.horizontalCenter : undefined
            spacing: w.metrics.px(6)
            Kirigami.Icon {
                width: Math.round(w.u * (w.tiny ? 0.34 : 0.3 * w.k)); height: width
                source: w.wx ? w.icon(w.wx.code) : ""
            }
            Lbl {
                anchors.verticalCenter: parent.verticalCenter
                text: w.wx ? w.deg(w.wx.temp) : ""
                font.bold: true
                font.pixelSize: Math.max(10, Math.round(w.u * (w.tiny ? 0.28 : 0.26 * w.k)))
            }
        }
        Column {
            visible: !w.tiny
            anchors.top: head.bottom
            width: parent.width
            Lbl {
                width: parent.width
                text: w.wx ? w.wx.place : ""
                font.pixelSize: Math.max(8, Math.round(w.u * 0.12 * w.k))
            }
            Lbl {
                width: parent.width
                opacity: 0.8
                text: w.wx && w.wx.days.length ? w.deg(w.wx.days[0].max) + " / " + w.deg(w.wx.days[0].min) : ""
                font.pixelSize: Math.max(8, Math.round(w.u * 0.11 * w.k))
            }
        }
        Row {
            visible: w.big && !!w.wx
            anchors.bottom: parent.bottom
            width: parent.width
            Repeater {
                model: w.wx ? w.wx.days.slice(1, 4) : []
                delegate: Column {
                    id: day
                    required property var modelData
                    width: parent.width / 3
                    Lbl {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(new Date(day.modelData.date + "T12:00:00").getDay(), Locale.ShortFormat)
                        font.pixelSize: Math.max(8, Math.round(w.u * 0.09))
                    }
                    Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; width: Math.round(w.u * 0.16); height: width; source: w.icon(day.modelData.code) }
                    Lbl {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: w.deg(day.modelData.max) + " / " + w.deg(day.modelData.min)
                        font.pixelSize: Math.max(8, Math.round(w.u * 0.08))
                    }
                }
            }
        }
    }
}
