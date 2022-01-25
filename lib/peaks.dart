import 'dart:io';
import 'dart:math';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/ffmpeg.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/player.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class AudioStream {
  final File tmpFile;
  final Map json;
  final List<double> rms;

  AudioStream(this.json, this.rms, this.tmpFile);

  Future<void> dispose() async {
    await tmpFile.delete();
  }
}

class MediaAnalysis {
  final Duration duration;
  final List<AudioStream> audioStreams;

  MediaAnalysis(this.duration, this.audioStreams);

  static Future<MediaAnalysis> analyze(
      File file, void Function(String) onProgress) async {
    var path = file.path;

    try {
      var json = await FFmpeg.collectJson(['-show_streams', path]);
      Iterable streams = json['streams'];

      var files = await extractStreams(file, streams);
      var audioStreams = <AudioStream>[];

      for (var stream in streams) {
        var isAudio = stream['codec_type'] == 'audio';
        if (isAudio) {
          int index = stream['index'];
          onProgress('Analyzing audio stream $index...');

          var audio = files[index];
          var rms = await analyzeAudio(audio);
          audioStreams.add(AudioStream(stream, rms, audio));
        }
      }

      var sec = double.parse(streams.first['duration']);
      var duration = Duration(milliseconds: (sec * 1000).toInt());
      return MediaAnalysis(duration, audioStreams);
    } on Exception catch (e) {
      onProgress(e.toString());
      rethrow;
    }
  }

  static Future<List<File>> extractStreams(File input, Iterable streams) async {
    var dir = Directory('tmp');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    var maps = [];
    var files = <File>[];

    for (var i = 0; i < streams.length; i++) {
      var stream = streams.elementAt(i);
      var file = File('tmp/stream$i.' + stream['codec_name']);
      files.add(file);

      if (stream['codec_type'] == 'audio') {
        maps.addAll(['-map', '0:$i', '-c', 'copy', file.path]);
      }
    }

    await FFmpeg.collectLines([
      '-y',
      '-i',
      input.path,
      ...maps,
    ], useFFProbe: false);

    return files;
  }

  static Future<List<double>> analyzeAudio(File file) async {
    var path = file.path;

    var astatsArgs = [
      'metadata=1',
      'reset=1',
      'measure_overall=RMS_level',
      'measure_perchannel=none',
    ];
    var astatsString = astatsArgs.join(':');

    var rmsLines = await FFmpeg.collectLines([
      '-f',
      'lavfi',
      '-i',
      'amovie=$path,astats=$astatsString',
      '-show_entries',
      'frame_tags=lavfi.astats.Overall.RMS_level',
      '-of',
      'csv=p=0',
    ]);

    var rms = rmsLines.map((line) {
      if (line == '-inf') {
        return -96.0;
      }
      return double.parse(line);
    }).toList();
    return rms;
  }
}

class AudioPeaks extends StatefulWidget {
  final AudioStream stream;
  final Duration time;
  final TimelineController ctrl;

  const AudioPeaks(this.stream, this.time, this.ctrl, {Key? key})
      : super(key: key);

  @override
  _AudioPeaksState createState() => _AudioPeaksState();
}

class _AudioPeaksState extends State<AudioPeaks> {
  AudioPlayer? get aPlayer =>
      player.audio.firstWhereOrNull((a) => a.stream == widget.stream);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 100,
      decoration: BoxDecoration(
        color: (aPlayer?.muted ?? true) ? Colors.grey[400] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      child: CustomPaint(
        foregroundPainter: PeakPainter(widget),
      ),
    );
  }
}

class PeakPainter extends CustomPainter {
  final AudioPeaks peaks;

  PeakPainter(this.peaks);

  @override
  void paint(Canvas canvas, Size size) {
    var reg = peaks.ctrl.clip;
    var visible = peaks.ctrl.visible;
    var pnt = Paint()
      ..color = Colors.grey[900]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    var rms = peaks.stream.rms;
    var duration = player.duration;
    var progress = 0.0;

    if (duration != null) {
      progress = div(peaks.time - visible.start, visible.length);

      if (reg != null) {
        var x = div(reg.start - visible.start, visible.length);
        var w = div(reg.length, visible.length);
        paintRegion(x, w, canvas, size);
      }
    }

    var x = progress * size.width;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), pnt);

    if (rms.isEmpty) {
      return canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), pnt);
    }

    var min = -96.0;
    var max = -0.0;

    for (var x = 0.0; x < size.width; x += 4) {
      var i = rms.length *
          div(visible.start + visible.length * (x / size.width), duration!);
      var mix = i % 1.0;

      var v = rms[i.floor()];
      if (i + 1 < rms.length) {
        var v2 = rms[i.floor() + 1];
        v = v + mix * (v2 - v);
      }
      var y = 0.5 * pow((v - min) / (max - min), 3);

      canvas.drawLine(Offset(x, size.height * (0.5 + y)),
          Offset(x, size.height * (0.5 - y)), pnt);
    }
  }

  void paintRegion(double start, double length, Canvas canvas, Size size) {
    var pnt = Paint()..color = Colors.blue[300]!.withAlpha(150);
    canvas.drawRect(
        Rect.fromLTWH(start * size.width, 0, length * size.width, size.height),
        pnt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
