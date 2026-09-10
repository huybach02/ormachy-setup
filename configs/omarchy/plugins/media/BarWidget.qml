import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "huybach02.media"

  readonly property var mediaService: bar?.shell?.serviceFor("huybach02.media") || bar?.shell?.firstPartyServiceFor("omarchy.media") || bar?.shell?.serviceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  function close() { popupOpen = false }
  readonly property real leftMargin: {
    var val = settings ? settings["leftMargin"] : undefined
    return (val !== undefined && val !== null) ? Number(val) : 36
  }

  visible: hasMedia
  implicitWidth: hasMedia ? (leftMargin + waveRow.implicitWidth + Style.space(14)) : 0
  implicitHeight: barSize

  property real wavePhase: 0.0
  readonly property var bellCurve: [
    0.35, 0.46, 0.58, 0.72, 0.85,
    0.95, 1.00, 1.00, 0.98, 0.95,
    0.95, 0.98, 1.00, 1.00, 0.95,
    0.85, 0.72, 0.58, 0.46, 0.35
  ]

  Timer {
    id: waveTimer
    interval: 33
    running: activePlayer && activePlayer.isPlaying
    repeat: true
    onTriggered: {
      root.wavePhase += 0.16
      var minH = Style.space(3.5)
      var maxSpan = Style.space(16)
      for (var i = 0; i < waveRepeater.count; i++) {
        var item = waveRepeater.itemAt(i)
        if (!item) continue
        var p = root.wavePhase
        var wave1 = Math.sin(p + i * 0.44)
        var wave2 = Math.sin(p * 1.55 - i * 0.30)
        var wave3 = Math.cos(p * 0.75 + i * 0.55)
        var val = (wave1 * 0.48 + wave2 * 0.34 + wave3 * 0.18 + 1.0) * 0.5
        var h = minH + val * maxSpan * root.bellCurve[i]
        item.waveHeight = Math.max(minH, h)
      }
    }
  }

  Item {
    id: waveItem
    x: root.leftMargin + Style.space(7)
    anchors.verticalCenter: parent.verticalCenter
    width: waveRow.implicitWidth
    height: Style.space(20)

    Rectangle {
      id: hoverPill
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      radius: Style.space(6)
      color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    Row {
      id: waveRow
      anchors.centerIn: parent
      height: Style.space(18)
      spacing: Style.space(3.0)

      Repeater {
        id: waveRepeater
        model: 20

        Item {
          id: barSlot
          required property int index

          width: Style.space(3.2)
          height: parent.height
          property alias waveHeight: barItem.waveHeight

          Rectangle {
            id: barItem
            anchors.bottom: parent.bottom
            width: parent.width
            radius: width / 2
            property real waveHeight: Style.space(4)
            height: (activePlayer && activePlayer.isPlaying) ? waveHeight : Style.space(3.5)

            // Smooth gradient across the 20 bars: Cyan (#0db9d7) -> Theme Accent Blue (#7aa2f7) -> Bright Purple (#bb9af7)
            readonly property color barColor: {
              var t = barSlot.index / 19.0
              if (t < 0.5) {
                var f = t * 2.0
                return Qt.rgba(
                  0.05 * (1 - f) + 0.48 * f,
                  0.73 * (1 - f) + 0.64 * f,
                  0.84 * (1 - f) + 0.97 * f,
                  1.0
                )
              } else {
                var f = (t - 0.5) * 2.0
                return Qt.rgba(
                  0.48 * (1 - f) + 0.73 * f,
                  0.64 * (1 - f) + 0.60 * f,
                  0.97 * (1 - f) + 0.97 * f,
                  1.0
                )
              }
            }

            color: (activePlayer && activePlayer.isPlaying) ? barColor : Qt.darker(root.bar.barForeground, 2.0)

            Behavior on height {
              enabled: !activePlayer || !activePlayer.isPlaying
              NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
            }
            Behavior on color {
              ColorAnimation { duration: 200 }
            }
          }
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    anchors.leftMargin: root.leftMargin
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false)
      } else if (mouse.button === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
      } else {
        if (root.mediaService) root.mediaService.runAction("playPause", false)
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false)
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false)
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          Image {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.activePlayer || !root.activePlayer.trackArtUrl
            text: "󰝚"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
