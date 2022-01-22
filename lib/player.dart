import 'dart:async';

import 'package:clipcutter/main.dart';
import 'package:dart_vlc/dart_vlc.dart' as v;
import 'package:libwinmedia/libwinmedia.dart' as a;

class MultiStreamPlayer {
  v.Player video = v.Player(id: 0);
  List<a.Player> audio = [];
  Duration? get duration => analysis?.duration;
  Duration? _seekTime;
  Timer? _timer;

  MultiStreamPlayer();

  /// Restart audio players to release locks on their media.
  void restartAudio() {
    for (var a in audio) {
      a.dispose();
    }

    audio = [
      a.Player(id: 1),
      a.Player(id: 2),
    ];
  }

  void play() {
    video.play();
    for (var a in audio) {
      a.play();
    }
  }

  void pause() {
    video.pause();
    for (var a in audio) {
      a.pause();
    }
  }

  void togglePlaying() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seek(Duration time) async {
    _seekTime = time;

    if (_timer == null) {
      _forceSeek(time);
      _timer = Timer(Duration(milliseconds: 100), () {
        _timer = null;
        if (_seekTime != time) {
          seek(_seekTime!);
        }
      });
    }
  }

  void _forceSeek(Duration time) {
    if (duration == null) return;

    video.seek(time);

    for (var a in audio) {
      a.seek(
          time * (a.state.duration.inMilliseconds / duration!.inMilliseconds));
    }
  }

  bool get isPlaying => video.playback.isPlaying;
}
