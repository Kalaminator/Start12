import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Mounted real drives (internal + external) with a usage bar. df gives sizes, lsblk tells removable ones.
// Refreshed when the menu opens and every 10 s while it is open.
Item {
    id: w
    required property QtObject metrics
    required property string size
    required property bool active

    property var drives: []   // [{name, target, total, free, removable}]
    readonly property bool tiny: size === "small"
    readonly property real rowH: metrics.px(40)
    readonly property int rows: Math.max(1, Math.floor(height / rowH))

    readonly property string cmd: "df -B1 --output=source,fstype,size,avail,target 2>/dev/null; echo '---'; lsblk -J -o NAME,RM,HOTPLUG,LABEL,MOUNTPOINTS 2>/dev/null"
    P5Support.DataSource {
        id: src
        engine: "executable"
        connectedSources: []
        onNewData: (name, data) => {
            disconnectSource(name);
            w.drives = w.parse(String(data.stdout));
        }
    }
    Timer {
        interval: 10000; repeat: true; running: w.active; triggeredOnStart: true
        onTriggered: src.connectSource(w.cmd)
    }

    function parse(out) {
        const parts = out.split("\n---\n");
        const info = {};   // mountpoint -> {label, removable}
        try {
            const walk = (n, rm) => {
                rm = rm || n.rm === true || n.rm === "1" || n.hotplug === true || n.hotplug === "1";
                (n.mountpoints || []).forEach(m => { if (m) info[m] = { label: n.label || "", removable: rm }; });
                (n.children || []).forEach(c => walk(c, rm));
            };
            JSON.parse(parts[1] || "{}").blockdevices.forEach(d => walk(d, false));
        } catch (e) {}
        const seen = {}, list = [];
        parts[0].split("\n").slice(1).forEach(l => {
            const f = l.trim().split(/\s+/);
            if (f.length < 5) return;
            const target = f.slice(4).join(" ");
            const total = Number(f[2]);
            if (!f[0].startsWith("/dev/") || f[0].startsWith("/dev/loop") || seen[f[0]]
                || /^(tmpfs|overlay|squashfs|devtmpfs|efivarfs)$/.test(f[1])
                || /^\/(boot|efi|snap)(\/|$)/.test(target) || !(total >= 1e9)) return;
            seen[f[0]] = true;   // btrfs subvolumes share one source
            const i = info[target] || {};
            list.push({ name: i.label || target, target: target, total: total, free: Number(f[3]), removable: !!i.removable });
        });
        return list;
    }

    function human(b) {
        const loc = Qt.locale();
        return b >= 1e12 ? i18n("%1 TB", Number(b / 1099511627776).toLocaleString(loc, "f", 1))
                         : i18n("%1 GB", Number(b / 1073741824).toLocaleString(loc, "f", b >= 1e11 ? 0 : 1));
    }
    function click(x, y) {
        const d = drives[Math.floor(y / rowH)];
        if (!tiny && d) Qt.openUrlExternally("file://" + d.target);
    }

    // Small: first drive's free percentage only.
    Column {
        visible: w.tiny
        anchors.centerIn: parent
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(w.width, w.height) * 0.4; height: width
            source: w.drives.length && w.drives[0].removable ? "drive-removable-media" : "drive-harddisk"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: w.drives.length > 0
            text: w.drives.length ? Math.round(w.drives[0].free / w.drives[0].total * 100) + "%" : ""
            color: w.metrics.text
            font.family: w.metrics.font
            font.bold: true
            font.pixelSize: Math.max(8, Math.round(Math.min(w.width, w.height) * 0.28))
        }
    }

    Column {
        visible: !w.tiny
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: w.tiny ? [] : w.drives.slice(0, w.rows)
            delegate: Item {
                id: row
                required property var modelData
                width: w.width
                height: w.rowH
                Kirigami.Icon {
                    id: ic
                    // anchors, not x: the mirrored menu (Right) flips anchors, and the text column hangs off them
                    anchors.left: parent.left
                    anchors.leftMargin: w.metrics.px(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: w.metrics.px(24); height: width
                    source: row.modelData.removable ? "drive-removable-media" : "drive-harddisk"
                }
                Column {
                    anchors.left: ic.right
                    anchors.leftMargin: w.metrics.px(6)
                    anchors.right: parent.right
                    anchors.rightMargin: w.metrics.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: w.metrics.px(2)
                    Text {
                        width: parent.width
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: w.metrics.text
                        font.family: w.metrics.font
                        font.pixelSize: Math.round(w.metrics.px(12))
                    }
                    Rectangle {
                        width: parent.width
                        height: Math.max(2, w.metrics.px(4))
                        radius: height / 2
                        color: Qt.alpha(w.metrics.text, 0.2)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, 1 - row.modelData.free / row.modelData.total))
                            height: parent.height
                            radius: height / 2
                            color: w.metrics.text   // not accent: tiles are often accent coloured
                        }
                    }
                    Text {
                        width: parent.width
                        // Narrow tiles drop the total so the free space is not cut off.
                        text: w.width < w.metrics.px(150) ? i18n("%1 free", w.human(row.modelData.free))
                            : i18n("%1 free of %2", w.human(row.modelData.free), w.human(row.modelData.total))
                        elide: Text.ElideRight
                        color: w.metrics.text
                        opacity: 0.8
                        font.family: w.metrics.font
                        font.pixelSize: Math.round(w.metrics.px(10))
                    }
                }
            }
        }
    }
}
