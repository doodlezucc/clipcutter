import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/main.dart';

class FFmpeg {
  static Future<List<String>> collectLines(
    List<String> arguments, {
    bool useFFProbe = true,
  }) async {
    var completer = Completer<List<String>>();
    var process = await Process.start(useFFProbe ? 'ffprobe' : 'ffmpeg', [
      '-v',
      'error',
      ...arguments,
    ]);
    var lines = <String>[];
    process.stdout.listen((data) {
      var ls = utf8.decode(data).trim().split('\n');
      lines.addAll(ls);
    });
    process.stderr.listen((data) {
      completer.completeError(utf8.decode(data).trim());
    });

    process.exitCode.then((value) {
      if (!completer.isCompleted) completer.complete(lines);
    });

    return completer.future;
  }

  static Future<Map> collectJson(List<String> arguments) async {
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

  static Future<void> render(TimelineController timeline, String output) async {
    var region = timeline.region;
    if (region == null) return print('No region in timeline.');

    var stream = player.audio.firstWhere((a) => !a.muted).stream!;
    int streamIndex = stream.json['index'];

    var args = [
      '-ss',
      '${region.start}',
      '-to',
      '${region.end}',
      '-i',
      player.video.current.media!.resource,
      '-map',
      '0:$streamIndex',
      '-y',
      output,
    ];

    var lines = await collectLines(args, useFFProbe: false);
    print(lines.join('\n'));
  }
}