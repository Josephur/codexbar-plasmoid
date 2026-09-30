import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "code/catalog.js" as Catalog
import "code/providerOverrides.js" as ProviderOverrides

// Panel representation. Default: ONE merged critter icon showing the
// worst-case (lowest remaining) usage across all enabled providers.
// Optional: one icon per provider, like the separate macOS menu bar items.
// Icons flow along the panel axis (horizontal or vertical).
MouseArea {
    id: compactRoot

    required property var plasmoidRoot

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool separate: Plasmoid.configuration.separateIcons
    readonly property string configuredDisplayMode: Plasmoid.configuration.panelDisplayMode || ""
    readonly property string displayMode: configuredDisplayMode === "logos"
                                          || configuredDisplayMode === "logos-and-meters"
                                          ? configuredDisplayMode : "meters"
    readonly property bool showsLogos: displayMode === "logos"
                                               || displayMode === "logos-and-meters"
    readonly property bool showsMeters: displayMode === "meters"
                                                || displayMode === "logos-and-meters"
    // Providers following the global panel settings share the merged meter;
    // only providers whose overrides differ get an icon of their own.
    // Parsed once per change; the per-icon lookups below reuse it.
    readonly property var overrides: ProviderOverrides.parse(Plasmoid.configuration.providerOverrides || "")
    readonly property var panelLayout: ProviderOverrides.panelIconModel(
        overrides,
        plasmoidRoot.enabledProviders, {
            panelDisplayMode: configuredDisplayMode,
            showPercentInPanel: Plasmoid.configuration.showPercentInPanel,
            panelPercentSource: Plasmoid.configuration.panelPercentSource,
            percentStyle: Plasmoid.configuration.percentStyle,
            hideCritters: Plasmoid.configuration.hideCritters
        }, separate)
    readonly property var iconModel: panelLayout.icons
    // Providers aggregated by the "__merged__" icon.
    readonly property var mergedProviders: panelLayout.merged

    readonly property real iconSide: vertical
        ? Math.min(Math.round(width * 0.75), Kirigami.Units.iconSizes.medium)
        : Math.min(Math.round(height * 0.75), Kirigami.Units.iconSizes.medium)

    implicitWidth: grid.implicitWidth + (vertical ? 0 : Kirigami.Units.smallSpacing * 2)
    implicitHeight: grid.implicitHeight + (vertical ? Kirigami.Units.smallSpacing * 2 : 0)

    Layout.minimumWidth: vertical ? 0 : implicitWidth
    Layout.preferredWidth: vertical ? -1 : implicitWidth
    Layout.fillWidth: vertical
    Layout.minimumHeight: vertical ? implicitHeight : 0
    Layout.preferredHeight: vertical ? implicitHeight : -1
    Layout.fillHeight: !vertical

    hoverEnabled: true

    function remainingFor(pid, source) {
        if (pid !== "__merged__")
            return plasmoidRoot.remainingPercent(pid, source)
        var min = -1
        for (var i = 0; i < mergedProviders.length; i++) {
            var v = plasmoidRoot.remainingPercent(mergedProviders[i], source)
            if (v >= 0 && (min < 0 || v < min))
                min = v
        }
        return min
    }

    function staleFor(pid) {
        if (pid !== "__merged__")
            return plasmoidRoot.isStale(pid)
        for (var i = 0; i < mergedProviders.length; i++) {
            if (!plasmoidRoot.isStale(mergedProviders[i]))
                return false
        }
        return true
    }

    // Effective per-icon display: the provider's override wins, else global.
    // The merged fallback icon always uses the global settings.
    function effectiveDisplayMode(pid) {
        if (pid === "__merged__")
            return displayMode
        return ProviderOverrides.effectiveDisplayMode(
            compactRoot.overrides, pid, configuredDisplayMode)
    }

    function showsLogosFor(pid) {
        var mode = effectiveDisplayMode(pid)
        return mode === "logos" || mode === "logos-and-meters"
    }

    function showsMetersFor(pid) {
        var mode = effectiveDisplayMode(pid)
        return mode === "meters" || mode === "logos-and-meters"
    }

    function showPercentFor(pid) {
        if (pid === "__merged__")
            return Plasmoid.configuration.showPercentInPanel
        return ProviderOverrides.effectiveShowPercent(
            compactRoot.overrides, pid,
            Plasmoid.configuration.showPercentInPanel)
    }

    function percentSourceFor(pid) {
        if (pid === "__merged__")
            return Plasmoid.configuration.panelPercentSource
        return ProviderOverrides.effectivePercentSource(
            compactRoot.overrides, pid,
            Plasmoid.configuration.panelPercentSource)
    }

    function percentStyleFor(pid) {
        if (pid === "__merged__")
            return Plasmoid.configuration.percentStyle
        return ProviderOverrides.effectivePercentStyle(
            compactRoot.overrides, pid,
            Plasmoid.configuration.percentStyle)
    }

    function hideCrittersFor(pid) {
        if (pid === "__merged__")
            return Plasmoid.configuration.hideCritters
        return ProviderOverrides.effectiveHideCritters(
            compactRoot.overrides, pid,
            Plasmoid.configuration.hideCritters)
    }

    function providerAt(x, y) {
        var point = grid.mapFromItem(compactRoot, x, y)
        for (var i = 0; i < providerRepeater.count; i++) {
            var item = providerRepeater.itemAt(i)
            if (item
                    && point.x >= item.x && point.x < item.x + item.width
                    && point.y >= item.y && point.y < item.y + item.height)
                return iconModel[i]
        }
        return ""
    }

    onClicked: function (mouse) {
        // a provider's own icon opens its tab; the merged meter toggles the
        // popup on the last viewed tab
        var target = providerAt(mouse.x, mouse.y)
        if (target !== "" && target !== "__merged__") {
            var switchingTab = plasmoidRoot.expanded
                    && plasmoidRoot.currentTab !== target
            plasmoidRoot.currentTab = target
            if (switchingTab)
                return
        }
        plasmoidRoot.expanded = !plasmoidRoot.expanded
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        flow: compactRoot.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: compactRoot.vertical ? -1 : 1
        columns: compactRoot.vertical ? 1 : -1
        rowSpacing: Kirigami.Units.smallSpacing * 2
        columnSpacing: Kirigami.Units.smallSpacing * 2

        Repeater {
            id: providerRepeater
            model: compactRoot.iconModel

            RowLayout {
                id: providerItem
                required property string modelData
                readonly property string providerId: modelData
                spacing: Kirigami.Units.smallSpacing

                Item {
                    visible: compactRoot.showsLogosFor(providerItem.providerId) && providerItem.providerId !== "__merged__"
                    Layout.preferredWidth: compactRoot.iconSide
                    Layout.preferredHeight: compactRoot.iconSide
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: Kirigami.Units.smallSpacing
                        color: Catalog.logoBackgroundColor(providerItem.providerId)
                    }

                    ProviderIconImage {
                        anchors.fill: parent
                        iconFile: Catalog.meta(providerItem.providerId).icon
                        displayContext: ProviderIconImage.ContrastingContext
                    }
                }

                CritterIcon {
                    // Keep the standard merged meter as a visible, clickable
                    // fallback when a logo mode has no enabled providers.
                    visible: compactRoot.showsMetersFor(providerItem.providerId) || providerItem.providerId === "__merged__"
                    // merged icon: plain meter bars like the original CodexBar status item
                    providerId: providerItem.providerId === "__merged__" ? "" : providerItem.providerId
                    Layout.preferredWidth: compactRoot.iconSide
                    Layout.preferredHeight: compactRoot.iconSide
                    Layout.alignment: Qt.AlignVCenter
                    remainingPrimary: compactRoot.remainingFor(providerItem.providerId, "session")
                    remainingSecondary: compactRoot.remainingFor(providerItem.providerId, "weekly")
                    stale: compactRoot.staleFor(providerItem.providerId)
                    hideCritters: compactRoot.hideCrittersFor(providerItem.providerId)
                }

                PlasmaComponents3.Label {
                    // Logo modes label real providers only; do not present
                    // their empty fallback as a merged percentage value.
                    visible: compactRoot.showPercentFor(providerItem.providerId)
                             && (!compactRoot.showsLogosFor(providerItem.providerId) || providerItem.providerId !== "__merged__")
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: Math.max(9, Math.round(compactRoot.iconSide * 0.62))
                    text: {
                        var v = compactRoot.remainingFor(
                                    providerItem.providerId, compactRoot.percentSourceFor(providerItem.providerId))
                        if (v < 0)
                            return "–"
                        if (compactRoot.percentStyleFor(providerItem.providerId) === "used")
                            v = 100 - v
                        return Math.round(v) + "%"
                    }
                }
            }
        }
    }
}
