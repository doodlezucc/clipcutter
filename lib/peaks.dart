import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

class AudioStream {
  final Map json;
  final List<double> rms;

  AudioStream(this.json, this.rms);
}

class MediaAnalysis {
  final List<AudioStream> audioStreams;

  MediaAnalysis(this.audioStreams);

  static Future<MediaAnalysis> analyze(File file) async {
    var path = file.path;

    var json = await _collectJson(['-show_streams', path]);
    Iterable streams = json['streams'];

    var audioStreams = <AudioStream>[];

    for (var stream in streams) {
      var isAudio = stream['codec_type'] == 'audio';
      if (isAudio) {
        int index = stream['index'];
        print('Analyzing stream $index');
        var rms = await analyzeAudio(file, stream: index);
        audioStreams.add(AudioStream(stream, rms));
      }
    }

    return MediaAnalysis(audioStreams);
  }

  static Future<List<double>> analyzeAudio(File file, {int stream = 0}) async {
    var path = file.path;
    var rmsLines = await _collectLines([
      '-f',
      'lavfi',
      '-i',
      'amovie=$path:si=$stream,astats=metadata=1:reset=1',
      '-show_entries',
      'frame_tags=lavfi.astats.Overall.RMS_level',
      '-of',
      'csv=p=0',
    ]);

    var rms = rmsLines.map((line) => double.parse(line)).toList();
    return rms;
  }

  static Future<List<String>> _collectLines(List<String> arguments) async {
    var completer = Completer<List<String>>();
    var ffprobe = await Process.start('ffprobe', [
      '-v',
      'error',
      ...arguments,
    ]);
    var lines = <String>[];
    ffprobe.stdout.listen((data) {
      var ls = utf8.decode(data).trim().split('\n');
      lines.addAll(ls);
    });
    ffprobe.stderr.listen((data) {
      stderr.add(data);
      completer.completeError(Error());
    });

    ffprobe.exitCode.then((value) => completer.complete(lines));

    return completer.future;
  }

  static Future<Map> _collectJson(List<String> arguments) async {
    var completer = Completer<Map>();
    var ffprobe = await Process.start('ffprobe', [
      '-v',
      'error',
      '-of',
      'json=c=1',
      ...arguments,
    ]);
    var output = '';
    ffprobe.stdout.listen((data) {
      output += utf8.decode(data);
    });
    ffprobe.stderr.listen((data) {
      stderr.add(data);
      completer.completeError(Error());
    });

    ffprobe.exitCode.then((value) => completer.complete(jsonDecode(output)));

    return completer.future;
  }
}

class AudioPeaks extends StatefulWidget {
  final AudioStream stream;
  final double position;

  const AudioPeaks(this.stream, this.position, {Key? key}) : super(key: key);

  @override
  _AudioPeaksState createState() => _AudioPeaksState();
}

class _AudioPeaksState extends State<AudioPeaks> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
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
    var pnt = Paint()
      ..color = Colors.grey[900]!
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    var rms = peaks.stream.rms;

    var x = peaks.position * size.width;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), pnt);

    if (rms.isEmpty) {
      return canvas.drawLine(
          Offset(0, size.height / 2), Offset(size.width, size.height / 2), pnt);
    }
    // var points = <Offset>[];

    var min = -96.0;
    var max = -0.0;
    for (var i = 0; i < rms.length; i++) {
      // var v = stream.rms[i];
      // if (v > max) max = v;
      // if (v < min) min = v;
    }

    for (var x = 0.0; x < size.width; x += 2) {
      var v = rms[rms.length * x ~/ size.width];
      var y = 0.5 * pow((v - min) / (max - min), 3);

      canvas.drawLine(Offset(x, size.height * (0.5 + y)),
          Offset(x, size.height * (0.5 - y)), pnt);
    }

    // canvas.drawPoints(PointMode.polygon, points, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
