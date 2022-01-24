import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

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

    ffprobe.exitCode.then((value) {
      if (!completer.isCompleted) completer.complete(jsonDecode(output));
    });

    return completer.future;
  }

  static Future<String?> renderDialog(TimelineController timeline) async {
    var result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Clip',
      lockParentWindow: true,
      type: FileType.audio,
    );
    if (result != null) {
      await render(timeline, result);
      return result;
    }
  }

  static Future<void> render(TimelineController timeline, String output) async {
    var region = timeline.clip;
    if (region == null) return print('No region in timeline.');

    if (extension(output).isEmpty) {
      output += '.wav';
    }

    var stream = player.audio.firstWhere((a) => !a.muted).stream!;
    int streamIndex = stream.json['index'];

    var input = absolute(player.video.current.media!.resource);

    var args = [
      '-ss',
      '${region.start}',
      '-to',
      '${region.end}',
      '-i',
      input,
      '-map',
      '0:$streamIndex',
      '-y',
      output,
    ];

    await collectLines(args, useFFProbe: false);
  }
}
