import 'package:agora_flutter_scalable/utils/app_id.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as rtc_local_view;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as rtc_remote_view;
import 'package:flutter/material.dart';

class VideoCallPage extends StatefulWidget {
  final String channelName;
  const VideoCallPage({
    Key? key,
    required this.channelName,
  }) : super(key: key);

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  static final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  late RtcEngine _engine;

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
  }

  Future<void> initialize() async {
    if (APP_ID.isEmpty) {
      setState(() {
        _infoStrings.add(
          'APP_ID missing, please provide your APP_ID in settings.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }
    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();
    await _engine.enableAudioVolumeIndication(200, 3, true);
    await _engine.joinChannel(token, widget.channelName, null, 0);
    await _engine.enableDualStreamMode(true);
    await _engine.setParameters("""
         { "che.video.lowBitRateStreamParameter": {
           "width":160,"height":120,"frameRate":5,"bitRate":45
         }}
       """);
  }

  /// Create agora sdk instance and initialize
  Future<void> _initAgoraRtcEngine() async {
    _engine = await RtcEngine.create(APP_ID);
    await _engine.enableVideo();
  }

  /// Add agora event handlers
  void _addAgoraEventHandlers() {
    _engine.setEventHandler(RtcEngineEventHandler(
      activeSpeaker: (uid) {
        final String info = "Active speaker: $uid";
        print(info);
      },
      error: (code) {
        setState(() {
          final info = 'onError: $code';
          _infoStrings.add(info);
        });
      },
      joinChannelSuccess: (channel, uid, elapsed) {
        setState(() {
          final info = 'onJoinChannel: $channel, uid: $uid';
          _infoStrings.add(info);
        });
      },
      leaveChannel: (stats) {
        setState(() {
          _infoStrings.add('onLeaveChannel');
          _users.clear();
        });
      },
      userJoined: (uid, elapsed) {
        setState(() {
          final info = 'userJoined: $uid';
          _infoStrings.add(info);
          _users.add(uid);
        });
        if (_users.length >= 5) {
          print("Fallback to Low quality video stream");
          _engine.setRemoteDefaultVideoStreamType(VideoStreamType.Low);
        }
      },
      userOffline: (uid, reason) {
        setState(() {
          final info = 'userOffline: $uid , reason: $reason';
          _infoStrings.add(info);
          _users.remove(uid);
        });
        if (_users.length <= 3) {
          print("Go back to High quality video stream");
          _engine.setRemoteDefaultVideoStreamType(VideoStreamType.High);
        }
      },
    ));
  }

  /// Toolbar layout
  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: _onToggleMute,
            child: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
          ),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            child: Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          RawMaterialButton(
            onPressed: _onSwitchCamera,
            child: Icon(
              Icons.switch_camera,
              color: Colors.blueAccent,
              size: 20.0,
            ),
            shape: CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agora Group Video Calling'),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          children: <Widget>[
            _viewRows(),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    final List<StatefulWidget> list = [];
    list.add(rtc_local_view.SurfaceView());
    _users.forEach(
      (int uid) => list.add(
        rtc_remote_view.SurfaceView(
          uid: uid,
        ),
      ),
    );
    return list;
  }

  /// Video view wrapper
  Widget _videoView(view) {
    return Expanded(child: Container(child: view));
  }

  /// Video view row wrapper
  Widget _expandedVideoRow(List<Widget> views) {
    final wrappedViews = views.map<Widget>(_videoView).toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Video layout wrapper
  Widget _viewRows() {
    final views = _getRenderViews();
    if (views.length == 1) {
      return Container(
        child: Column(
          children: <Widget>[_videoView(views[0])],
        ),
      );
    } else if (views.length == 2) {
      return Container(
          child: Column(
        children: <Widget>[
          _expandedVideoRow([views[0]]),
          _expandedVideoRow([views[1]])
        ],
      ));
    } else if (views.length > 2 && views.length % 2 == 0) {
      return Container(
        child: Column(
          children: [
            for (int i = 0; i < views.length; i = i + 2)
              _expandedVideoRow(
                views.sublist(i, i + 2),
              ),
          ],
        ),
      );
    } else if (views.length > 2 && views.length % 2 != 0) {
      return Container(
        child: Column(
          children: <Widget>[
            for (int i = 0; i < views.length; i = i + 2)
              i == (views.length - 1)
                  ? _expandedVideoRow(views.sublist(i, i + 1))
                  : _expandedVideoRow(views.sublist(i, i + 2)),
          ],
        ),
      );
    }
    return Container();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }
}
