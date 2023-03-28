import 'package:flutter/material.dart';
import 'package:video_conference_demo/video-page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Video Conference Demo')),
        body: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: VideoCallPage(channelName: "jitsi-meet-wrapper-test-room")),
      ),
    );
  }
}
