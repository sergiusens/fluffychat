import QtQuick 2.4
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"

Rectangle {
    id: message
    //property var event
    property var isStateEvent: event.type !== "m.room.message" && event.type !== "m.sticker"
    property var isMediaEvent: [ "m.file", "m.image", "m.video", "m.audio" ].indexOf( event.content.msgtype ) !== -1
    property var isImage: !isStateEvent && (event.content.msgtype === "m.image" || event.type === "m.sticker") && event.content.info !== undefined && event.content.info.thumbnail_url !== undefined
    property var sent: event.sender.toLowerCase() === matrix.matrixid.toLowerCase()
    property var isLeftSideEvent: !sent || isStateEvent
    property var sending: sent && event.status === msg_status.SENDING

    width: mainStackWidth
    height: (isStateEvent||isMediaEvent||isImage) ? messageBubble.height + units.gu(1) : messageLabel.height + units.gu(4.5)
    color: "transparent"


    function openContextMenu () {
        if ( !isStateEvent && !thumbnail.visible && !contextualActions.visible ) {
            contextualActions.contextEvent = event
            contextualActions.show()
        }
    }


    // When the width of the "window" changes (rotation for example) then the maxWidth
    // of the message label must be calculated new. There is currently no "maxwidth"
    // property in qml.
    onWidthChanged: {
        messageLabel.width = undefined
        var maxWidth = width - avatar.width - units.gu(5)
        if ( messageLabel.width > maxWidth ) messageLabel.width = maxWidth
        else messageLabel.width = undefined
    }


    Avatar {
        id: avatar
        mxc: opacity ? chatMembers[event.sender].avatar_url : ""
        name: chatMembers[event.sender].displayname
        anchors.left: isLeftSideEvent ? parent.left : undefined
        anchors.right: !isLeftSideEvent ? parent.right : undefined
        anchors.bottom: parent.bottom
        anchors.bottomMargin: units.gu(1)
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)
        opacity: (event.sameSender && !isStateEvent) ? 0 : 1
        width: isStateEvent ? units.gu(3) : units.gu(6)
        onClickFunction: function () {
            if ( !opacity ) return
            activeUser = event.sender
            usernames.showUserSettings ( event.sender )
        }
    }


    MouseArea {
        id: mouseArea
        width: messageBubble.width
        height: messageBubble.height
        anchors.left: isLeftSideEvent ? avatar.right : undefined
        anchors.right: !isLeftSideEvent ? avatar.left : undefined
        anchors.bottom: parent.bottom
        anchors.bottomMargin: units.gu(1)
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)

        onPressAndHold: openContextMenu ()
        Rectangle {
            id: messageBubble
            opacity: (sending || event.status === msg_status.ERROR) ? 0.66 : isStateEvent ? 0.75 : 1
            z: 2
            border.width: 0
            border.color: settings.darkmode ? UbuntuColors.slate : UbuntuColors.silk
            anchors.margins: units.gu(0.5)
            color: (!sent || isStateEvent) ? "#FFFFFF" : defaultMainColor
            radius: units.gu(2)
            height: contentColumn.height + ( isImage ? units.gu(1) : (isStateEvent ? units.gu(1.5) : units.gu(2)) )
            width: contentColumn.width + ( isImage ? 0 : units.gu(2) )

            Column {
                id: contentColumn
                anchors.bottom: parent.bottom
                anchors.bottomMargin: isStateEvent ? units.gu(0.75) : units.gu(1)


                /* ====================IMAGE OR STICKER====================
                * If the message is an image or a sticker, then show this, following:
                * http://yuml.me/diagram/plain/activity/(start)-><a>[Gif-Image && autload active]->(Show full MXC), <a>[else]-><b>[Thumbnail exists]->(Show thumbnail), <b>[Thumbnail is null]->(Show "Show Image"-Button)               */
                Rectangle {
                    id: image
                    color: "#00000000"
                    width: thumbnail.status === Image.Ready ? thumbnail.width : (showButton ? showImageButton.width : (showGif ? gif.width : height*(9/16)))
                    height: visible * (!showButton ? units.gu(30) : showImageButton.height)
                    visible: !isStateEvent && (event.content.msgtype === "m.image" || event.type === "m.sticker")
                    property var showGif: visible && settings.autoloadGifs && event.content.info && event.content.info.mimetype && event.content.info.mimetype === "image/gif"
                    property var showThumbnail: visible && !showGif && event.content.info && event.content.info.thumbnail_url
                    property var showButton: visible && !showGif && !showThumbnail

                    Image {
                        id: thumbnail
                        source: image.showThumbnail ? downloadPath + event.content.info.thumbnail_url.split("/")[3] : ""
                        property var onlyOneError: true
                        onStatusChanged: {
                            if ( status === Image.Error && onlyOneError ) {
                                thumbnail.source = media.getThumbnailLinkFromMxc ( event.content.info.thumbnail_url, Math.round (height), Math.round (height) )
                                onlyOneError = false
                            }
                        }
                        height: parent.height
                        width: Math.min ( height * ( sourceSize.width / sourceSize.height ), mainStackWidth - units.gu(3) - avatar.width)
                        fillMode: Image.PreserveAspectCrop
                        visible: image.showThumbnail && status === Image.Ready
                        cache: true
                    }

                    AnimatedImage {
                        id: gif
                        source: image.showGif ? media.getLinkFromMxc ( event.content.url ) : ""
                        height: parent.height
                        width: Math.min ( height * ( sourceSize.width / sourceSize.height ), mainStackWidth - units.gu(3) - avatar.width)
                        fillMode: Image.PreserveAspectCrop
                        visible: image.showGif && status === gif.Ready
                    }

                    ActivityIndicator {
                        visible: image.showThumbnail && thumbnail.status === Image.Loading || image.showGif && gif.status === Image.loading
                        anchors.centerIn: parent
                        width: units.gu(2)
                        height: width
                        running: visible
                    }

                    Icon {
                        visible: image.showThumbnail && thumbnail.status === Image.Error || image.showGif && gif.status === Image.Error
                        anchors.centerIn: parent
                        width: units.gu(6)
                        height: width
                        name: "sync-error"
                    }

                    Button {
                        id: showImageButton
                        text: i18n.tr("Show image")
                        onClicked: imageViewer.show ( event.content.url )
                        visible: image.showButton
                        height: visible ? units.gu(4) : 0
                        width: visible ? units.gu(26) : 0
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1)
                    }

                    MouseArea {
                        anchors.fill: thumbnail
                        onClicked: imageViewer.show ( event.content.url )
                        onPressAndHold: openContextMenu ()
                    }
                }


                /*  ====================AUDIO MESSAGE====================
                */
                Row {
                    id: audioPlayer
                    visible: event.content.msgtype === "m.audio"
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1)
                    spacing: units.gu(1)
                    width: visible ? undefined : 0
                    height: visible * units.gu(6)

                    Button {
                        id: playButton
                        anchors.verticalCenter: parent.verticalCenter
                        property var playing: false
                        color: "white"
                        iconName: playing ? "media-playback-pause" : "media-playback-start"
                        onClicked: {
                            if ( audio.source !== media.getLinkFromMxc ( event.content.url ) ) {
                                audio.source = media.getLinkFromMxc ( event.content.url )
                            }
                            if ( playing ) audio.pause ()
                            else audio.play ()
                            playing = !playing
                        }
                        width: units.gu(4)
                    }
                    Button {
                        id: stopButton
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        iconName: "media-playback-stop"
                        opacity: audio.source === media.getLinkFromMxc ( event.content.url ) && audio.position === 0 ? 0.75 : 1
                        onClicked: {
                            audio.stop ()
                            playButton.playing = false
                        }
                        width: units.gu(4)
                    }
                    Button {
                        id: downloadAudioButton
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        iconName: "document-save-as"
                        onClicked: {
                            downloadDialog.downloadButton = downloadAudioButton
                            downloadDialog.filename = event.content_body
                            downloadDialog.downloadUrl = media.getLinkFromMxc ( event.content.url )
                            downloadDialog.shareFunc = shareController.shareAudio
                            downloadDialog.current = PopupUtils.open(downloadDialog)
                        }
                        width: units.gu(4)
                    }
                }


                /*  ====================VIDEO MESSAGE====================
                */
                /*MouseArea {
                    width: videoLink.width
                    height: videoLink.height
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1)
                    onClicked: videoPlayer.show ( event.content.url)
                    Rectangle {
                        id: videoLink
                        visible: event.content.msgtype === "m.video"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#000000" }
                            GradientStop { position: 0.5; color: "#303030"}
                            GradientStop { position: 1.0; color: "#101010" }
                        }
                        width: visible * units.gu(32)
                        height: visible * units.gu(18)
                        radius: units.gu(0.5)
                        Icon {
                            name: "media-preview-start"
                            color: UbuntuColors.silk
                            anchors.centerIn: parent
                            width: units.gu(4)
                            height: width
                        }
                    }
                }*/


                /*  ====================FILE MESSAGE====================
                */
                Button {
                    id: downloadButton
                    text: i18n.tr("Download: ") + event.content.body
                    onClicked: {
                        downloadDialog.downloadButton = downloadAudioButton
                        downloadDialog.filename = event.content_body
                        downloadDialog.downloadUrl = media.getLinkFromMxc ( event.content.url )
                        downloadDialog.current = PopupUtils.open(downloadDialog)
                    }
                    visible: event.content.msgtype === "m.file" || event.content.msgtype === "m.video"
                    height: visible ? units.gu(4) : 0
                    width: visible ? units.gu(26) : 0
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(1)
                }


                /*  ====================TEXT MESSAGE====================
                * In this label, the body of the matrix message is displayed. This label
                * is main responsible for the width of the message bubble.
                */
                Label {
                    id: messageLabel
                    opacity: (event.type === "m.sticker" || isMediaEvent) ? 0 : 1
                    height: opacity ? undefined : 0
                    text: isStateEvent ? displayEvents.getDisplay ( event ) + " - " + stamp.getChatTime ( event.origin_server_ts ) :  event.content_body || event.content.body
                    color: (!sent || isStateEvent) ? "black" : "white"
                    linkColor: color
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    textSize: isStateEvent ? Label.XSmall :
                    (event.content.msgtype === "m.fluffychat.whisper" ? Label.XxSmall :
                    (event.content.msgtype === "m.fluffychat.roar" ? Label.XLarge : Label.Medium))

                    font.italic: event.content.msgtype === "m.emote"
                    anchors.left: parent.left
                    anchors.topMargin: isStateEvent ? units.gu(0.5) : units.gu(1)
                    anchors.leftMargin: units.gu(1)
                    anchors.bottomMargin: isStateEvent ? units.gu(0.5) : 0
                    onLinkActivated: {
                        if ( link.split("fluffychat://").length > 0 ) {
                            usernames.showUserSettings( link.split("fluffychat://")[1] )
                        }
                        else Qt.openUrlExternally(link)
                    }
                    // Intital calculation of the max width and display URL's and
                    // make sure, that the label text is not empty for the correct
                    // height calculation.
                    //onTextChanged: calcWidth ()
                    Component.onCompleted: {
                        if ( !event.content_body ) event.content_body = event.content.body
                        var maxWidth = message.width - avatar.width - units.gu(5)
                        if ( width > maxWidth ) width = maxWidth
                        if ( text === "" ) text = " "
                        if ( event.content.msgtype === "m.emote" ) text = chatMembers[event.sender].displayname + " " + text
                    }
                }


                Row {
                    id: metaLabelRow
                    anchors.left: sent ? undefined : parent.left
                    anchors.leftMargin: units.gu(1)
                    anchors.right: sent ? parent.right : undefined
                    anchors.rightMargin: isImage ? units.gu(1) : -units.gu(1)
                    spacing: units.gu(0.25)

                    // This label is for the meta-informations, which means it displays the
                    // display name of the sender of this message and the time.
                    Label {
                        id: metaLabel
                        text: {
                            // Show the senders displayname only on the first message of
                            // this sender and only if its not the user him-/herself.
                            (event.sender !== matrix.matrixid ?
                                ("<b><font color='" + usernames.stringToColor(chatMembers[event.sender].displayname) + "'>" + (chatMembers[event.sender].displayname) + "</font></b> ")
                                : "")
                                + stamp.getChatTime ( event.origin_server_ts )
                            }
                            color: messageLabel.color
                            opacity: 0.66
                            textSize: Label.XSmall
                            visible: !isStateEvent
                        }
                        // When the message is just sending, then this activity indicator is visible
                        ActivityIndicator {
                            id: activity
                            visible: sending
                            running: visible
                            height: metaLabel.height
                            width: height
                        }
                        // When the message is received, there should be an icon
                        Icon {
                            id: statusIcon
                            visible: !isStateEvent && sent && event.status !== msg_status.SENDING
                            name: event.status === msg_status.SEEN ? "contact" :
                            (event.status === msg_status.RECEIVED ? "tick" :
                            (event.status === msg_status.HISTORY ? "clock" : "edit-clear"))
                            height: metaLabel.height
                            color: "white"
                            width: height
                        }
                    }
                }
            }
        }


    }
