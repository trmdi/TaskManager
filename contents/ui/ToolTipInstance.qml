/*
*   Copyright 2013 by Sebastian Kügler <sebas@kde.org>
*   Copyright 2014 by Martin Gräßlin <mgraesslin@kde.org>
*   Copyright 2016 by Kai Uwe Broulik <kde@privat.broulik.de>
*   Copyright 2017 by Roman Gilg <subdiff@gmail.com>
*
*   This program is free software; you can redistribute it and/or modify
*   it under the terms of the GNU Library General Public License as
*   published by the Free Software Foundation; either version 2, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU Library General Public License for more details
*
*   You should have received a copy of the GNU Library General Public
*   License along with this program; if not, write to the
*   Free Software Foundation, Inc.,
*   51 Franklin Street, Fifth Floor, Boston, MA  2.010-1301, USA.
*/

import QtQuick 2.6
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0
import QtQml.Models 2.2

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kquickcontrolsaddons 2.0 as KQuickControlsAddons

import org.kde.taskmanager 0.1 as TaskManager

Column {
    property var submodelIndex: tasksModel.makeModelIndex(parentIndex, isGroup ? index : -1)
    property int flatIndex: isGroup && index != undefined ? index : 0

    spacing: units.smallSpacing

    property string mprisSourceName: mpris2Source.sourceNameForLauncherUrl(toolTipDelegate.launcherUrl, isGroup ? AppPid : pidParent)
    property var playerData: mprisSourceName != "" ? mpris2Source.data[mprisSourceName] : 0
    property bool hasPlayer: !!mprisSourceName && !!playerData
    property bool playing: hasPlayer && playerData.PlaybackStatus === "Playing"
    property bool canControl: hasPlayer && playerData.CanControl
    property bool canGoBack: hasPlayer && playerData.CanGoPrevious
    property bool canGoNext: hasPlayer && playerData.CanGoNext
    property bool canRaise: hasPlayer && playerData.CanRaise
    property var currentMetadata: hasPlayer ? playerData.Metadata : ({})

    readonly property string track: {
        var xesamTitle = currentMetadata["xesam:title"]
        if (xesamTitle) {
            return xesamTitle;
        }
        // if no track title is given, print out the file name
        var xesamUrl = currentMetadata["xesam:url"] ? currentMetadata["xesam:url"].toString() : ""
        if (!xesamUrl) {
            return "";
        }
        var lastSlashPos = xesamUrl.lastIndexOf('/')
        if (lastSlashPos < 0) {
            return "";
        }
        var lastUrlPart = xesamUrl.substring(lastSlashPos + 1)
        return decodeURIComponent(lastUrlPart);
    }
    readonly property string artist: currentMetadata["xesam:artist"] || ""
    readonly property string albumArt: currentMetadata["mpris:artUrl"] || ""

    //
    // launcher icon + text labels + close button
    RowLayout {
        id: header
        Layout.minimumWidth: childrenRect.width
        Layout.maximumWidth: Layout.minimumWidth

        Layout.minimumHeight: childrenRect.height
        Layout.maximumHeight: Layout.minimumHeight

        anchors.horizontalCenter: parent.horizontalCenter

        // launcher icon
        PlasmaCore.IconItem {
            source: icon
            animated: false
            usesPlasmaTheme: false
            visible: !isWin
        }
        // all textlabels
        Column {
            PlasmaExtras.Heading {
                level: 3
                width: isWin ? textWidth : undefined
                height: undefined
                maximumLineCount: 1
                elide: Text.ElideRight
                text: appName
                opacity: flatIndex == 0
                textFormat: Text.PlainText
                visible: text !== ""
            }
            // window title
            PlasmaExtras.Heading {
                level: 5
                width: isWin ? textWidth : undefined
                height: undefined
                maximumLineCount: 1
                elide: Text.ElideRight
                text: generateTitle()
                textFormat: Text.PlainText
                opacity: 0.75
            }
            // subtext
            PlasmaExtras.Heading {
                level: 6
                width: isWin ? textWidth : undefined
                height: undefined
                maximumLineCount: 1
                elide: Text.ElideRight
                text: isWin ? generateSubText() : ""
                textFormat: Text.PlainText
                opacity: 0.6
                visible: text !== ""
            }
        }
        // close button
        MouseArea {
            Layout.alignment: Qt.AlignRight | Qt.AlignTop

            height: units.iconSizes.smallMedium
            width: height

            visible: isWin

            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            onClicked: {
                backend.cancelHighlightWindows();
                tasksModel.requestClose(submodelIndex);
            }

            PlasmaCore.IconItem {
                anchors.fill: parent
                active: parent.containsMouse

                source: "window-close"
                animated: false
            }
        }
    }

    // thumbnail container
    Item {
        id: thumbnail
        width: header.width
        // similar to 0.5625 = 1 / (16:9) as most screens are
        // round necessary, otherwise shadow mask for players has gap!
        height: Math.round(0.5 * width)
        anchors.horizontalCenter: parent.horizontalCenter

        visible: isWin

        Item {
            id: thumbnailSourceItem
            anchors.fill: parent

            readonly property bool isMinimized: isGroup ? IsMinimized == true : isMinimizedParent
            // TODO: this causes XCB error message when being visible the first time
            property int winId: isWin && windows[flatIndex] != undefined ? windows[flatIndex] : 0

            PlasmaCore.WindowThumbnail {
                anchors.fill: parent

                visible: !albumArtImage.visible && !thumbnailSourceItem.isMinimized
                winId: thumbnailSourceItem.winId

                ToolTipWindowMouseArea {
                    anchors.fill: parent
                    rootTask: parentTask
                    modelIndex: submodelIndex
                    winId: thumbnailSourceItem.winId
                }
            }

            Image {
                id: albumArtImage
                // also Image.Loading to prevent loading thumbnails just because the album art takes a split second to load
                readonly property bool available: status === Image.Ready || status === Image.Loading

                anchors.fill: parent
                sourceSize: Qt.size(parent.width, parent.height)
                asynchronous: true
                source: albumArt
                fillMode: Image.PreserveAspectCrop
                visible: available

                ToolTipWindowMouseArea {
                    anchors.fill: parent
                    rootTask: parentTask
                    modelIndex: submodelIndex
                    winId: thumbnailSourceItem.winId
                }
            }

            // when minimized, we don't have a preview, so show the icon
            PlasmaCore.IconItem {
                anchors.fill: parent
                source: icon
                animated: false
                usesPlasmaTheme: false
                visible: thumbnailSourceItem.isMinimized && !albumArtImage.visible

                ToolTipWindowMouseArea {
                    anchors.fill: parent
                    rootTask: parentTask
                    modelIndex: submodelIndex
                    winId: thumbnailSourceItem.winId
                }
            }
        }


        Loader {
            anchors.fill: thumbnail
            sourceComponent: hasPlayer ? playerControlsComp : undefined
        }

        Component {
            id: playerControlsComp

            Item {
                anchors.fill: parent

                // TODO: When could this really be the case? A not-launcher-task always has a window!?
                // if there's no window associated with this task, we might still be able to raise the player
//                MouseArea {
//                    id: raisePlayerArea
//                    anchors.fill: parent

//                    visible: !isWin || !windows[0] && canRaise
//                    onClicked: mpris2Source.raise(mprisSourceName)
//                }

                Item {
                    id: playerControlsFrostedGlass
                    anchors.fill: parent
                    visible: false // OpacityMask would render it

                    Rectangle {
                        width: parent.width
                        height: parent.height - playerControlsRow.height
                        opacity: 0
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: playerControlsRow.height
                        color: theme.backgroundColor
                        opacity: 0.8
                    }
                }

                OpacityMask {
                    id: playerControlsOpacityMask
                    anchors.fill: parent
                    source: playerControlsFrostedGlass
                    maskSource: thumbnailSourceItem
                }

                // prevent accidental click-through when a control is disabled
                MouseArea {
                    anchors.fill: playerControlsRow
                }

                RowLayout {
                    id: playerControlsRow
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                    }
                    width: parent.width
                    spacing: 0
                    enabled: canControl

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaExtras.Heading {
                            Layout.fillWidth: true
                            level: 4
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            text: track || ""
                        }

                        PlasmaExtras.Heading {
                            Layout.fillWidth: true
                            level: 5
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            text: artist || ""
                        }
                    }

                    MouseArea {
                        height: units.iconSizes.smallMedium
                        width: height
                        enabled: canGoBack

                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onClicked: mpris2Source.goPrevious(mprisSourceName)

                        PlasmaCore.IconItem {
                            anchors.fill: parent
                            enabled: canGoBack
                            active: parent.containsMouse

                            source: LayoutMirroring.enabled ? "media-skip-forward" : "media-skip-backward"
                            animated: false
                        }
                    }

                    MouseArea {
                        height: units.iconSizes.medium
                        width: height

                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onClicked: mpris2Source.playPause(mprisSourceName)

                        PlasmaCore.IconItem {
                            anchors.fill: parent
                            active: parent.containsMouse

                            source: playing ? "media-playback-pause" : "media-playback-start"
                            animated: false
                        }
                    }

                    MouseArea {
                        height: units.iconSizes.smallMedium
                        width: height
                        enabled: canGoNext

                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onClicked: mpris2Source.goNext(mprisSourceName)

                        PlasmaCore.IconItem {
                            anchors.fill: parent
                            enabled: canGoNext
                            active: parent.containsMouse

                            source: LayoutMirroring.enabled ? "media-skip-backward" : "media-skip-forward"
                            animated: false
                        }
                    }
                }
            }
        }
    }

    function generateTitle() {
        if (!isWin) {
            return genericName != undefined ? genericName : "";
        }

        var text;
        if (isGroup) {
            if (model.display == undefined) {
                return "";
            }
            text = model.display.toString();
        } else {
            text = displayParent;
        }

        // KWin appends increasing integers in between pointy brackets to otherwise equal window titles.
        // In this case save <#number> as counter and delete it at the end of text.
        var counter = text.match(/<\d+>\W*$/);
        text = text.replace(/\s*<\d+>\W*$/, "");

        // Remove appName from the end of text.
        var appNameRegex = new RegExp(appName + "$", "i");
        text = text.replace(appNameRegex, "");
        text = text.replace(/\s*(?:-|—)*\s*$/, "");

        // Add counter back at the end.
        if (counter != null) {
            if (text == "") {
                text = counter;
            } else {
                text = text + " " + counter;
            }
        }

        // In case the window title had only redundant informations (i.e. appName), text is now empty.
        // Add a hyphen to indicate that and avoid empty space.
        if (text == "") {
            text = "—";
        }
        return text.toString();
    }

    function generateSubText() {
        if (activitiesParent == undefined) {
            return "";
        }

        var subTextEntries = [];

        var vd = isGroup ? VirtualDesktop : virtualDesktopParent;

        if (!plasmoid.configuration.showOnlyCurrentDesktop
            && virtualDesktopInfo.numberOfDesktops > 1
            && (isGroup ? IsOnAllVirtualDesktops : isOnAllVirtualDesktopsParent) !== true
            && vd != -1
            && vd != undefined
            && virtualDesktopInfo.desktopNames[vd - 1] != undefined) {
            subTextEntries.push(i18n("On %1", virtualDesktopInfo.desktopNames[vd - 1]));
        }

        var act = isGroup ? Activities : activitiesParent;
        if (act == undefined) {
            return subTextEntries.join("\n");
        }

        if (act.length == 0 && activityInfo.numberOfRunningActivities > 1) {
            subTextEntries.push(i18nc("Which virtual desktop a window is currently on",
                "Available on all activities"));
        } else if (act.length > 0) {
           var activityNames = [];

            for (var i = 0; i < act.length; i++) {
                var activity = act[i];
                var activityName = activityInfo.activityName(act[i]);
                if (activityName == "") {
                    continue;
                }
                if (plasmoid.configuration.showOnlyCurrentActivity) {
                    if (activity != activityInfo.currentActivity) {
                        activityNames.push(activityName);
                    }
                } else if (activity != activityInfo.currentActivity) {
                    activityNames.push(activityName);
                }
            }

            if (plasmoid.configuration.showOnlyCurrentActivity) {
                if (activityNames.length > 0) {
                    subTextEntries.push(i18nc("Activities a window is currently on (apart from the current one)",
                        "Also available on %1", activityNames.join(", ")));
                }
            } else if (activityNames.length > 0) {
                subTextEntries.push(i18nc("Which activities a window is currently on",
                    "Available on %1", activityNames.join(", ")));
            }
        }

        return subTextEntries.join("\n");
    }
}
