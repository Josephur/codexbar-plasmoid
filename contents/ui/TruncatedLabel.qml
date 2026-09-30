import QtQuick
import org.kde.plasma.components as PlasmaComponents3

// Label that reveals elided text: usage sites keep their elide mode and
// width constraints; when the text does not fit, hovering shows the full
// string in a tooltip.
PlasmaComponents3.Label {
    id: root

    HoverHandler { id: hoverHandler }

    PlasmaComponents3.ToolTip {
        visible: hoverHandler.hovered && root.truncated
        text: root.text
    }
}
