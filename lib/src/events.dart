class StartCallAction {
  StartCallAction._new(Map<dynamic, dynamic> arguments)
      : callUUID = arguments['callUUID'],
        handle = arguments['handle'],
        name = arguments['name'];

  final String? callUUID;
  final String? handle;
  final String? name;
}

class AnswerCallAction {
  AnswerCallAction._new(Map<dynamic, dynamic> arguments) : callUUID = arguments['callUUID'];

  final String? callUUID;
}

class EndCallAction {
  EndCallAction._new(Map<dynamic, dynamic> arguments) : callUUID = arguments['callUUID'];
  final String? callUUID;
}

class DidActivateAudioSessionEvent {}

class DidDeactivateAudioSessionEvent {}

class DidDisplayIncomingCallEvent {
  DidDisplayIncomingCallEvent(Map<dynamic, dynamic> arguments)
      : callUUID = arguments['callUUID'],
        handle = arguments['handle'],
        localizedCallerName = arguments['localizedCallerName'],
        hasVideo = arguments['hasVideo'],
        fromPushKit = arguments['fromPushKit'];
  final String? callUUID;
  final String? handle;
  final String? localizedCallerName;
  final bool? hasVideo;
  final bool? fromPushKit;
}

class DidPerformSetMutedCallAction {
  DidPerformSetMutedCallAction._new(Map<dynamic, dynamic> arguments)
      : callUUID = arguments['callUUID'],
        muted = arguments['muted'];
  final String? callUUID;
  final bool? muted;
}

class DidToggleHoldAction {
  DidToggleHoldAction._new(Map<dynamic, dynamic> arguments)
      : callUUID = arguments['callUUID'],
        hold = arguments['hold'];
  final String? callUUID;
  final bool? hold;
}

class DidPerformDTMFAction {
  DidPerformDTMFAction._new(Map<dynamic, dynamic> arguments)
      : callUUID = arguments['callUUID'],
        digits = arguments['digits'];
  final String? callUUID;
  final String? digits;
}

class ProviderResetEvent {}

class CheckReachabilityEvent {}
