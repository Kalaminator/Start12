import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import QtQuick.Layouts

// W16: 0 px helper that islands.js puts in every panel of a Windows 12 split (fill mode). The KWin script
// win12islandreveal writes its "reveal" key when the pointer touches the bottom edge; NeedsAttention keeps an
// auto-hidden panel shown, so all the islands pop up and hide together.
PlasmoidItem {
    Plasmoid.status: Plasmoid.configuration.reveal ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    fullRepresentation: Item { Layout.preferredWidth: 0; Layout.preferredHeight: 0 }
}
