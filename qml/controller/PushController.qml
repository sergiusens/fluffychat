import QtQuick 2.0
import Ubuntu.Components 1.3
import Ubuntu.PushNotifications 0.1
import Qt.labs.settings 1.0

PushClient {
    id: pushClient

    property var errorReport: null

    function pusherror ( reason ) {
        console.warn("PUSHERROR",reason)
        if ( reason === "bad auth" ) {
            errorReport = i18n.tr("Please login to Ubuntu One to receive push notifications!")
        }
        else errorReport = reason
    }

    function newNotification ( message ) {
        if ( message == "" ) return
        var message = JSON.parse ( message )
        var room = message.room_name || message.sender_display_name || message.sender
        if ( room === activeChatDisplayName ) pushclient.clearPersistent ( room )
    }

    Component.onCompleted: {
        notificationsChanged.connect(newNotification)
        error.connect(pusherror)
    }

    function setPusher ( intent, callback, error_callback ) {
        if ( intent && errorReport !== null ) {
            if ( error_callback ) error_callback ( {errcode: "NO_UBUNTUONE", error: errorReport} )
        }
        else {
            var data = {
                "app_display_name": "FluffyChat",
                "app_id": appId,
                "append": true,
                "data": {
                    "url": "https://janian.de:7000"
                },
                "device_display_name": "UbuntuPhone",
                "lang": "en",
                "kind": intent ? "http" : null,
                "profile_tag": "xxyyzz",
                "pushkey": pushtoken
            }
            matrix.post ( "/client/r0/pushers/set", data, callback, error_callback )
        }
    }

    appId: "fluffychat.christianpauly_fluffychat"

}