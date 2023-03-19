import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';


/*
  Documentation: https://docs.agora.io/en/interactive-live-streaming/develop/authentication-workflow?platform=flutter
  Device requierments: x86_64
  Get token: https://agora-token-service-production-61a1.up.railway.app/rtc/CHANNEL_NAME/:role/:token_type/:uid/?expiry=EXPIRY_TIME
    - CHANNEL_NAME: Channel name
    - ROLE: 1 for Host/Broadcaster, 2 for Subscriber/Audience
    - UID: It can be set to 0, if you do not need to authenticate the user based on the user ID
    - EXPIRY_TIME: 300
  Testing: https://webdemo.agora.io/basicVideoCall/index.html
*/


const String appId = "ea7d40861fe2443abee5485ea0436416";

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int tokenRole = 1; // use 1 for Host/Broadcaster, 2 for Subscriber/Audience
  int tokenExpireTime = 300; // Expire time in Seconds.
  bool isTokenExpiring = false; // Set to true when the token is about to expire
  final channelTextController =
      TextEditingController(text: ''); // To access the TextField
  String channelName = "";
  String token = "";
  // The base URL to your token server.
  String serverUrl =
      "https://agora-token-service-production-61a1.up.railway.app"; // For example, "https://agora-token-service-production-92ff.up.railway.app"

  int uid = 0; // uid of the local user

  int? _remoteUid; // uid of the remote user
  bool _isJoined = false; // Indicates if the local user has joined the channel
  bool _isHost =
      true; // Indicates whether the user has joined as a host or audience
  late RtcEngine agoraEngine; // Agora engine instance

  late ChannelMediaOptions options;

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>(); // Global key to access the scaffold
  @override
  void initState() {
    super.initState();
    // Set up an instance of Agora engine
    Future.delayed(Duration.zero, () async {
      await setupVideoSDKEngine();
      //here is the async code, you can execute any async code here
    });
  }

  Future<void> setupVideoSDKEngine() async {
    // retrieve or request camera and microphone permissions
    await [Permission.microphone, Permission.camera].request();

    //create an instance of the Agora engine
    agoraEngine = createAgoraRtcEngine();
    await agoraEngine.initialize(const RtcEngineContext(appId: appId));

    await agoraEngine.enableVideo();

    // Register the event handler
    agoraEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage(
              "Local user uid:${connection.localUid} joined the channel");
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          showMessage("Remote user uid:$remoteUid joined the channel");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
          });
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          showMessage('Token expiring');
          isTokenExpiring = true;
          setState(() {
            // fetch a new token when the current token is about to expire
            fetchToken(uid, channelName, tokenRole);
          });
        },
      ),
    );
  }

  void join() async {
    // Set channel options

    // Set channel profile and client role
    if (_isHost) {
      options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await agoraEngine.startPreview();
    } else {
      options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
    }
    if (_isHost) {
      tokenRole = 1;
    } else {
      tokenRole = 2;
    }

    channelName = channelTextController.text;

    if (channelName.isEmpty) {
      showMessage("Enter a channel name");
      return;
    } else {
      showMessage("Fetching token ...");
    }

    await fetchToken(uid, channelName, tokenRole);
  }

  void leave() {
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
    agoraEngine.leaveChannel();
  }

  String getUrl() {
    return '$serverUrl/rtc/$channelName/${tokenRole.toString()}/uid/${uid.toString()}?expiry=${tokenExpireTime.toString()}';
  }

  Future<void> fetchToken(int uid, String channelName, int tokenRole) async {
    // Prepare the Url
    String url = getUrl();

    // Send the request
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // If the server returns an OK response, then parse the JSON.
      Map<String, dynamic> json = jsonDecode(response.body);
      String newToken = json['rtcToken'];
      debugPrint('Token Received: $newToken');
      // Use the token to join a channel or renew an expiring token
      setToken(newToken);
    } else {
      // If the server did not return an OK response,
      // then throw an exception.
      throw Exception(
          'Failed to fetch a token. Make sure that your server URL is valid');
    }
  }

  void setToken(String newToken) async {
    token = newToken;

    if (isTokenExpiring) {
      // Renew the token
      agoraEngine.renewToken(token);
      isTokenExpiring = false;
      showMessage("Token renewed");
    } else {
      // Join a channel.
      showMessage("Token received, joining a channel...");

      await agoraEngine.joinChannel(
          token: token, channelId: channelName, uid: uid, options: options);
    }
  }

  // Release the resources when you leave
  @override
  void dispose() async {
    await agoraEngine.leaveChannel();
    agoraEngine.release();
    super.dispose();
  }

  showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  // Build UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Interactive Live Streaming'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              TextField(
                controller: channelTextController,
                decoration: const InputDecoration(
                    hintText: 'Type the channel name here'),
              ),

              // Container for the local video
              Container(
                height: 240,
                decoration: BoxDecoration(border: Border.all()),
                child: Center(child: _videoPanel()),
              ),
              // Radio Buttons
              Row(children: <Widget>[
                Radio<bool>(
                  value: true,
                  groupValue: _isHost,
                  onChanged: (value) => _handleRadioValueChange(value),
                ),
                const Text('Host'),
                Radio<bool>(
                  value: false,
                  groupValue: _isHost,
                  onChanged: (value) => _handleRadioValueChange(value),
                ),
                const Text('Audience'),
              ]),
              // Button Row
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      child: const Text("Join"),
                      onPressed: () => {join()},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      child: const Text("Leave"),
                      onPressed: () => {leave()},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Server Info: ${getUrl()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text('Token: $token'),
              const SizedBox(height: 10),
              // Button Row ends
            ],
          )),
    );
  }

  Widget _videoPanel() {
    print('isJoined: $_isJoined, isHost: $_isHost, remoteUid: $_remoteUid');
    if (!_isJoined) {
      return const Text(
        'Join a channel',
        textAlign: TextAlign.center,
      );
    } else if (_isHost) {
      // Show local video preview
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: 0),
        ),
      );
    } else {
      // Show remote video
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: agoraEngine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: channelName),
          ),
        );
      } else {
        return const Text(
          'Waiting for a host to join',
          textAlign: TextAlign.center,
        );
      }
    }
  }

// Set the client role when a radio button is selected
  void _handleRadioValueChange(bool? value) async {
    setState(() {
      _isHost = (value == true);
    });
    if (_isJoined) leave();
  }
}
