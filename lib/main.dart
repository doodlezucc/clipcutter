import 'dart:async';
import 'dart:io';

import 'package:clipcutter/peaks.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'home.dart';

final player = Player(id: 0);
var file = File('test/dani.mp4');
MediaAnalysis? analysis;

final _frameCtrl = StreamController<Duration>.broadcast(sync: true);
Stream<Duration> get frameStream => _frameCtrl.stream;

void main() {
  DartVLC.initialize();
  runApp(const ClipCutterApp());
  SchedulerBinding.instance!
      .addPersistentFrameCallback((ts) => _frameCtrl.add(ts));
}

Future<void> reloadVideo() async {
  var source = Media.file(file);
  player.setVolume(0);
  player.open(source, autoStart: false);

  print('analyzing');
  analysis = await MediaAnalysis.analyze(file);
  print(analysis!.audioStreams.length);
  print('done');
}

class ClipCutterApp extends StatelessWidget {
  const ClipCutterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clip Cutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(title: 'Clip Cutter'),
    );
  }
}
