import 'dart:async';
import 'dart:io';

import 'package:dart_vlc/dart_vlc.dart' as v;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:libwinmedia/libwinmedia.dart' as a;
import 'package:path/path.dart';

import 'home.dart';
import 'peaks.dart';
import 'player.dart';

final player = MultiStreamPlayer();
var file = File('test/dani.mp4');
MediaAnalysis? analysis;

final _frameCtrl = StreamController<Duration>.broadcast(sync: true);
Stream<Duration> get frameStream => _frameCtrl.stream;

void main() {
  v.DartVLC.initialize();
  a.LWM.initialize();
  runApp(const ClipCutterApp());
  SchedulerBinding.instance!
      .addPersistentFrameCallback((ts) => _frameCtrl.add(ts));
}

Future<void> reloadVideo() async {
  player.restartAudio();
  var source = v.Media.file(file);
  player.video.setVolume(0);
  player.video.open(source, autoStart: false);

  print('analyzing');
  analysis = await MediaAnalysis.analyze(file);
  var streams = analysis!.audioStreams;

  for (var i = 0; i < streams.length; i++) {
    var stream = streams[i];

    var uri = 'file://' + absolute(stream.tmpFile.path);
    player.audio[i].open([a.Media(uri: uri)]);
  }
  print('analyzed ${streams.length} audio streams');
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
