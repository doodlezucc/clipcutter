import 'dart:async';

import 'package:dart_vlc/dart_vlc.dart' as v;
import 'package:libwinmedia/libwinmedia.dart' as a;

class MultiStreamPlayer {
  final v.Player video;
  final List<a.Player> audio;
  Duration? _seekTime;
  Timer? _timer;

  MultiStreamPlayer(this.video, this.audio);

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
    print('seek $time');
    video.seek(time);

    for (var a in audio) {
      a.seek(time);
    }
  }

  bool get isPlaying => video.playback.isPlaying;
}
