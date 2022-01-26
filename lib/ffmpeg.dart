import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/prefs.dart';
import 'package:clipcutter/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

class FFmpeg {
  static Future<List<String>> collectLines(
    List<String> arguments, {
    bool useFFProbe = true,
  }) async {
    Prefs.resetCWD();
    var completer = Completer<List<String>>();
    var process = await Process.start(useFFProbe ? 'ffprobe' : 'ffmpeg', [
      '-v',
      'error',
      ...arguments,
    ]);
    var lines = <String>[];
    process.stdout.listen((data) {
      var ls = utf8
          .decode(data)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
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
    Prefs.resetCWD();
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
      initialDirectory: Prefs.export,
    );
    if (result != null) {
      result = await render(timeline, result);
      Prefs.export = dirname(result);
      return result;
    }
  }

  static Future<String> render(
      TimelineController timeline, String output) async {
    var region = timeline.clip;
    if (region == null) throw 'No region in timeline.';

    if (extension(output).isEmpty) {
      output += '.wav';
    }

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

    await collectLines(args, useFFProbe: false);
    return output;
  }
}

Future<ProcessResult> openFile(String path) async {
  Prefs.resetCWD();
  return Process.run('start', [path], runInShell: true);
}

Future<ProcessResult> openExplorer(String select) async {
  Prefs.resetCWD();
  select = canonicalize(select);
  return Process.run('explorer /select,"$select"', []);
}
