import 'dart:async';
import 'dart:io';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/peaks.dart';
import 'package:dart_vlc/dart_vlc.dart' as v;
import 'package:libwinmedia/libwinmedia.dart' as a;
import 'package:path/path.dart';

class MultiStreamPlayer {
  v.Player video = v.Player(id: 0);
  List<AudioPlayer> audio = [];
  Duration? get duration => analysis?.duration;
  Duration? _seekTime;
  Timer? _timer;

  Future<void> open(String path, void Function(String) onProgress) async {
    restartAudio();

    var file = File(path);
    var source = v.Media.file(file);
    video.setVolume(0);
    video.open(source, autoStart: false);
    video.play();

    print('analyzing');
    analysis = await MediaAnalysis.analyze(file, onProgress);

    video.pause();
    video.seek(Duration.zero);

    var streams = analysis!.audioStreams;

    for (var i = 0; i < streams.length; i++) {
      var stream = streams[i];
      player.audio[i].openStream(stream);
    }
    print('analyzed ${streams.length} audio streams');
  }

  /// Restart audio players to release locks on their media.
  void restartAudio() {
    for (var a in audio) {
      a.dispose();
    }

    audio = [
      AudioPlayer(id: 1),
      AudioPlayer(id: 2),
    ];
  }

  void play() {
    video.play();
    for (var a in audio) {
      a.play();
    }
  }

  Future<void> playRegion(Region region) async {
    _forceSeek(region.start);
    play();
    await Future.delayed(region.length);
    pause();
    video.playbackController.add(v.PlaybackState()..isPlaying = false);
    _forceSeek(region.start);
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

class AudioPlayer extends a.Player {
  AudioStream? _stream;
  AudioStream? get stream => _stream;

  double _bufferedVolume = 0;
  bool _muted = false;
  bool get muted => _muted;

  set muted(bool muted) {
    if (muted && !_muted) {
      _bufferedVolume = volume;
      volume = 0;
    } else if (!muted && _muted) {
      volume = _bufferedVolume;
    }
    _muted = muted;
  }

  AudioPlayer({required int id}) : super(id: id);

  void openStream(AudioStream stream) {
    _stream = stream;

    var uri = 'file://' + absolute(stream.tmpFile.path);
    open([a.Media(uri: uri)]);
  }
}
