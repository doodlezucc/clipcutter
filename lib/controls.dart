import 'package:clipcutter/peaks.dart';
import 'package:flutter/material.dart';

class TimelineController extends ChangeNotifier {
  Duration? startTimestamp;
  Duration? startTime;
  Region? clip;
  Region visible = Region(Duration.zero, Duration(seconds: 1));
  bool ready = false;

  void toggleMuteStream(AudioStream stream) {
    if (stream.aPlayer != null) {
      stream.aPlayer!.muted = !stream.aPlayer!.muted;
    }
    notifyListeners();
  }
}

class Region {
  Duration start;
  Duration length;

  Duration get end => start + length;
  set end(Duration end) {
    length = end - start;
  }

  Region(this.start, this.length);
}
