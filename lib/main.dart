import 'dart:async';

import 'package:clipcutter/prefs.dart';
import 'package:dart_vlc/dart_vlc.dart' as v;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:libwinmedia/libwinmedia.dart' as a;

import 'home.dart';
import 'peaks.dart';
import 'player.dart';

final player = MultiStreamPlayer();
MediaAnalysis? analysis;

final _frameCtrl = StreamController<Duration>.broadcast(sync: true);
Stream<Duration> get frameStream => _frameCtrl.stream;

void main() {
  v.DartVLC.initialize();
  a.LWM.initialize();
  Prefs.load();
  runApp(const ClipCutterApp());
  SchedulerBinding.instance!
      .addPersistentFrameCallback((ts) => _frameCtrl.add(ts));
}

double div(Duration a, Duration b) {
  return a.inMilliseconds / b.inMilliseconds;
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
      debugShowCheckedModeBanner: false,
    );
  }
}
