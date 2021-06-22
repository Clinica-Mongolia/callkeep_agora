// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:example/main.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:callkeep/callkeep.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

final FlutterCallkeep callkeep = FlutterCallkeep();

class PushNotificationsManager {
  factory PushNotificationsManager() => _instance;
  PushNotificationsManager._();

  static final PushNotificationsManager _instance = PushNotificationsManager._();

  static String? orderId;
  static bool _isAnswered = false;
  static String? pushToken;
  static String? apnsToken;

  bool _initialized = false;

  Future<void> init(BuildContext context) async {
    // _initialized = false; // For development reasons
    if (!_initialized) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      var initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/notif_icon');
      var initializationSettingsIOs = IOSInitializationSettings();
      var initSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOs);

      flutterLocalNotificationsPlugin.initialize(initSettings, onSelectNotification: (value) async {
        print('CLICKED_LOCAL_NOTIFICATION: $value');
        return true;
      });
      // Default notification details for platforms
      // Only for the local notification
      var platform = NotificationDetails(
        android: AndroidNotificationDetails(
          'id',
          'channel ',
          'description',
          fullScreenIntent: true,
          enableLights: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: IOSNotificationDetails(),
      );

      if (Platform.isAndroid) _createNotificationChannel('callkeep.fusion.example', 'Callkeep', 'Callkeep notification description');

      // Initialize callkeep
      await callkeep.setup(<String, dynamic>{
        'ios': {'appName': 'Callkeep Agora'},
        'android': {'imageName': '@mipmap/notif_icon'},
      }, context);

      // The default event handlers for callkeep
      callkeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
      callkeep.on(CallKeepPerformAnswerCallAction(), answerCall);
      callkeep.on(CallKeepDidPerformDTMFAction(), didPerformDTMFAction);
      callkeep.on(CallKeepDidReceiveStartCallAction(), didReceiveStartCallAction);
      callkeep.on(CallKeepDidToggleHoldAction(), didToggleHoldCallAction);
      callkeep.on(CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
      callkeep.on(CallKeepPerformEndCallAction(), endCall);
      callkeep.on(CallKeepPushKitToken(), onPushKitToken);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        var title;
        var body;
        try {
          // notification data null means that's calling notification. And we need to show calls
          bool isCallNotification = message.notification == null || message.notification?.title == null || message.notification?.body == null;
          var payload = message.data;

          // Data for join call
          var token = payload['token'] as String?;
          var appId = payload['appId'] as String?;
          var orderId = payload['orderId'] as String?;
          var uuid = payload['uuid'] as String?;
          var callerName = payload['caller_name'] as String?;
          if (token != null && appId != null && orderId != null) {
            // User waiting for others
            print('Open call screen worked');
            // User join from a random screen
            // First of all, close all screens. Actually, only for user's waiting screen.
            MyApp.navigatorKey.currentState!.popUntil((route) => route.isFirst);
            MyApp.navigatorKey.currentState!.pushNamed(
              'AgoraCallPage', // TODO implement to use
              arguments: {
                'agora': AgoraModel(
                  token: token,
                  callId: int.parse(orderId),
                  appId: appId,
                  uid: 'UserId',
                ),
              },
            );
          } else if (isCallNotification) {
            if (uuid != null && callerName == null) {
              // On IOS, it only rings. When user open app, got an error that user can't join call
              if (Platform.isAndroid) {
                await callkeep.endCall(uuid);
                // await callkeep.endCall(uuid);
              }
              print("End call $uuid, isAndroid ${Platform.isAndroid}");
            } else {
              var callerId = payload['caller_id'] as String;
              var hasVideo = true;
              final callUUID = uuid ?? Uuid().v4();
              await callkeep.askForPermissionsIfNeeded(context);
              await callkeep.displayIncomingCall(callUUID, callerId, callerName!, hasVideo, 'handler', HandleType.generic);
              print("Display Incoming call $callUUID");
            }
          } else {
            title = message.notification!.title;
            body = message.notification!.body;
            payload = message.data;
            await flutterLocalNotificationsPlugin.show(0, title, body, platform, payload: payload.toString());
          }
        } catch (e) {
          print("Error occurred $e");
        }
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        String? orderId;
        try {
          orderId = message.data['orderId'];
          MyApp.navigatorKey.currentState!.pushNamed(
            'AgoraCallPage', // TODO implement to use
            arguments: <String, dynamic>{'uid': int.tryParse(orderId!)},
          );
        } catch (e) {
          print("Error occurred $e");
        }
      });

      if (!Platform.isAndroid) {
        NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          await _saveDeviceToken();
        }
      } else {
        await _saveDeviceToken();
      }

      _initialized = true;

      if (Platform.isAndroid) {
        await callkeep.setupWithImage('@mipmap/app_icon');
        // You can use your custom styled dialog.
        await callkeep.askForPermissionsIfNeeded(
          context,
          showDlg: (ctx) => showCustomDialog(
            context: ctx,
            title: 'Please allow permission',
          ).then(
            (value) => value!,
          ),
        );
      }
    }
  }

  // Your custom dialog here
  Future<bool?> showCustomDialog({
    required BuildContext context,
    required String title,
    String caption = '',
    bool dismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: dismissible,
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => Future.value(dismissible),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(title),
                Text(caption),
                Divider(),
                TextButton(
                  onPressed: () {},
                  child: Text(caption),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Push notification token. You should save this token for the user.
  ///
  /// Then you can send call notification to the user
  Future<void> _saveDeviceToken() async {
    pushToken = (await FirebaseMessaging.instance.getToken())!;
  }

  /// Notification channel used to find your app from device. It registers to the device
  Future<void> _createNotificationChannel(String id, String name, String description) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var androidNotificationChannel = AndroidNotificationChannel(id, name, description);
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidNotificationChannel);
  }

  /// Top level function for handling background messages
  static Future<dynamic> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    try {
      print("backgroundMessage: message =>${message.toString()}");

      // Initialize the Firebase app
      await Firebase.initializeApp();

      // Data for show call android:debuggable="true"
      var payload = message.data;
      var callerId = payload['caller_id'] as String?;
      var callerName = payload['caller_name'] as String?;
      var uuid = payload['uuid'] as String?;
      var hasVideo = true;

      final callUUID = uuid ?? Uuid().v4();

      // Need to set listeners. The app may not have an instance to handle actions.
      // The main problem is when the program is closed.
      callkeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
      callkeep.on(CallKeepPerformAnswerCallAction(), answerCall);
      callkeep.on(CallKeepDidPerformDTMFAction(), didPerformDTMFAction);
      callkeep.on(CallKeepDidReceiveStartCallAction(), didReceiveStartCallAction);
      callkeep.on(CallKeepDidToggleHoldAction(), didToggleHoldCallAction);
      callkeep.on(CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
      callkeep.on(CallKeepPerformEndCallAction(), endCall);
      callkeep.on(CallKeepPushKitToken(), onPushKitToken);

      // You will need to stop call. Otherwise, it'll not stop.
      // Or you can assign parameters when sending to separate what to do.
      if (callerName == null) {
        await callkeep.rejectCall(uuid!);
      }
      // Otherwise, we'll show them incoming call
      else {
        // Set icon for calling screen.
        await callkeep.setupWithImage('@mipmap/app_icon');
        await callkeep.displayIncomingCall(
          callUUID,
          callerId!,
          callerName,
          hasVideo,
          'handler',
          HandleType.generic,
        );
      }
    } catch (e) {
      print('Error occurred: $e');
    }

    // If user receive it
    // final notificationAction = NotificationData(int.tryParse(callUUID));
    // _onNotificationData.sink.add(notificationAction);
    return null;
  }

  /// The method called before display the incoming call
  static void didDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) async {
    orderId = event.payload!['orderId'].toString();
  }

  /// The method called when user answer the call
  static void answerCall(CallKeepPerformAnswerCallAction event) async {
    _isAnswered = true;
    // In this case, we should end the call and open app.
    //
    callkeep.endCall(event.callUUID!);
    // Open up the app from background
    callkeep.backToForeground();
    MyApp.navigatorKey.currentState!.pushNamed(
      'AgoraCallPage', // TODO implement to use
      arguments: <String, dynamic>{
        // You should use the uid to join the Agora call
        'uid': int.tryParse(Platform.isIOS ? orderId! : event.callUUID!),
      },
    );
  }

  static String? checkActiveCall() => orderId;

  static void endCall(CallKeepPerformEndCallAction event) {
    if (!_isAnswered) endingCall(event);

    _isAnswered = false;
  }

  static void endingCall(CallKeepPerformEndCallAction event) async {
    // TODO: implement end call action
  }

  /// We will receive push kit token on only iOS.
  ///
  /// Save the token to use further actions.
  static void onPushKitToken(CallKeepPushKitToken event) => apnsToken = event.token;

  static void didPerformDTMFAction(CallKeepDidPerformDTMFAction event) {}

  static void didReceiveStartCallAction(CallKeepDidReceiveStartCallAction event) {}

  static void didToggleHoldCallAction(CallKeepDidToggleHoldAction event) {}

  static void didPerformSetMutedCallAction(CallKeepDidPerformSetMutedCallAction event) {}
}

/// This class used to sink from background message to the listener.
///
/// Listener must be registered on a page.
class NotificationData {
  NotificationData(this.callId, this.appId, this.uid, this.token);

  /// This is the ID you generate on the backend. (OrderId, PaymentId, etc.)
  final int callId;
  // Below 3 properties for join Agora call.
  final String appId;
  final String uid;
  final String token;
}

/// Agora
class AgoraModel {
  AgoraModel({
    this.appId,
    this.uid,
    this.token,
    this.callId,
  }) : createdAt = DateTime.now().toString();

  factory AgoraModel.fromJson(Map<String, dynamic> json) => AgoraModel(
        appId: json['appId'] ?? '',
        uid: json['uid'] ?? '',
        token: json['token'] ?? '',
        callId: json['callId'] ?? 0,
      );

  /// This is the ID you generate on the backend. (OrderId, PaymentId, etc.)
  int? callId;
  // Below 3 properties for join Agora call.
  String? appId;
  String? uid;
  String? token;

  /// When the agora call starts.
  String createdAt;

  /// To json map and use, fromJson to pass the data
  /// through the navigator using string type.
  Map<String, dynamic> toJson() => {
        'appId': appId,
        'uid': uid,
        'token': token,
        'callId': callId,
        'createdAt': createdAt,
      };
}
