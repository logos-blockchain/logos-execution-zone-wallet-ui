pragma Singleton

import QtQuick

QtObject {
    // Step heading, e.g. "How do you want to start?".
    readonly property int stepHeading: 18
    // Sub-hint under a field, smaller than secondaryText.
    readonly property int fieldHint: 11
}
