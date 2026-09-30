import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "code/catalog.js" as Catalog
import "code/providerSources.js" as ProviderSources
import "code/providerOverrides.js" as ProviderOverrides

KCM.SimpleKCM {
    id: page

    property string cfg_enabledProviders
    property string cfg_providerSources
    property string cfg_providerOverrides
    // Globals the override dialog's unticked rows follow; never assigned here.
    property string cfg_panelDisplayMode: "meters"
    property bool cfg_showPercentInPanel: false
    property string cfg_panelPercentSource: "session"
    property string cfg_percentStyle: "remaining"
    property bool cfg_hideCritters: false
    // View filter only: not a setting, so toggling it is no pending change.
    property bool showEnabledOnly: false

    readonly property var sourceLabels: [
        i18n("Auto"), i18n("Web"), i18n("CLI"), i18n("OAuth"), i18n("API")
    ]

    function enabledList() {
        return (cfg_enabledProviders || "").split(",")
            .map(function (s) { return s.trim() })
            .filter(function (s) { return s.length > 0 })
    }

    function setEnabled(id, on) {
        var list = enabledList()
        var idx = list.indexOf(id)
        if (on && idx < 0)
            list.push(id)
        if (!on && idx >= 0)
            list.splice(idx, 1)
        cfg_enabledProviders = list.join(",")
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Providers are probed with the codexbar CLI. Only enable providers you actually use — each one costs a probe per refresh. The source column picks the CodexBar data source (--source) for a provider; Auto lets the CLI decide. The gear button opens per-provider overrides for the panel settings; anything left unticked there follows the General page.")
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: search
                Layout.fillWidth: true
            }

            QQC2.CheckBox {
                text: i18n("Show enabled only")
                checked: page.showEnabledOnly
                onToggled: page.showEnabledOnly = checked
            }
        }

        Repeater {
            model: Catalog.orderedIds().filter(function (id) {
                if (page.showEnabledOnly && page.enabledList().indexOf(id) < 0)
                    return false
                var q = search.text.toLowerCase()
                if (q.length === 0)
                    return true
                return id.indexOf(q) >= 0 || Catalog.meta(id).name.toLowerCase().indexOf(q) >= 0
            })

            RowLayout {
                id: row
                required property string modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 2

                QQC2.CheckBox {
                    checked: page.enabledList().indexOf(row.modelData) >= 0
                    onToggled: page.setEnabled(row.modelData, checked)
                }

                ProviderIconImage {
                    iconFile: Catalog.meta(row.modelData).icon
                    displayContext: ProviderIconImage.ContrastingContext
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small

                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: 4
                        color: Catalog.logoBackgroundColor(row.modelData)
                    }
                }

                QQC2.Label {
                    text: Catalog.meta(row.modelData).name
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    text: row.modelData
                    opacity: 0.5
                    font: Kirigami.Theme.smallFont
                }

                QQC2.ComboBox {
                    id: sourceCombo
                    enabled: page.enabledList().indexOf(row.modelData) >= 0
                    model: page.sourceLabels
                    Accessible.name: i18n("Data source for %1", Catalog.meta(row.modelData).name)
                    currentIndex: {
                        page.cfg_providerSources
                        return Math.max(0, ProviderSources.SOURCES.indexOf(
                            ProviderSources.sourceFor(page.cfg_providerSources, row.modelData)))
                    }
                    onActivated: page.cfg_providerSources = ProviderSources.withSource(
                        page.cfg_providerSources, row.modelData,
                        ProviderSources.SOURCES[currentIndex])
                }

                QQC2.ToolButton {
                    enabled: page.enabledList().indexOf(row.modelData) >= 0
                    icon.name: "settings-configure"
                    highlighted: ProviderOverrides.hasOverride(page.cfg_providerOverrides, row.modelData)
                    Accessible.name: i18n("Provider settings for %1", Catalog.meta(row.modelData).name)
                    QQC2.ToolTip.text: i18n("Per-provider panel settings for %1", Catalog.meta(row.modelData).name)
                    QQC2.ToolTip.visible: hovered
                    onClicked: settingsDialog.openFor(row.modelData)
                }

            }
        }

        // Searching while filtered hides disabled matches; point that out.
        QQC2.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: page.showEnabledOnly && search.text.length > 0
            text: i18n("Can't find what you're looking for? Only enabled providers are shown. <a href=\"#\">Show all providers</a>")
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            onLinkActivated: page.showEnabledOnly = false

            HoverHandler {
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }

    ProviderOverridesDialog {
        id: settingsDialog
        // Center on the window rather than on the scrolled provider list.
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(page.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 36)
        overrides: page.cfg_providerOverrides
        globals: ({
            panelDisplayMode: page.cfg_panelDisplayMode,
            showPercentInPanel: page.cfg_showPercentInPanel,
            panelPercentSource: page.cfg_panelPercentSource,
            percentStyle: page.cfg_percentStyle,
            hideCritters: page.cfg_hideCritters
        })
        // Staged like every other edit; the page Apply/OK commits it.
        onStaged: function (overrides) { page.cfg_providerOverrides = overrides }
    }
}
