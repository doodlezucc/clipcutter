import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/prefs.dart';
import 'package:clipcutter/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

class FFmpeg {
  static const extAudio = [
    'aac',
    'midi',
    'mp3',
    'ogg',
    'wav',
  ];
  static const extVideo = [
    'avi',
    'flv',
    'mkv',
    'mov',
    'mp4',
    'mpeg',
    'webm',
    'wmv',
  ];

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
    var source = player.video.current.media!.resource;
    var initialName = basenameWithoutExtension(source);

    var result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Clip',
      lockParentWindow: true,
      type: FileType.custom,
      fileName: initialName,
      allowedExtensions: [...extAudio, ...extVideo],
      initialDirectory: Prefs.export,
    );
    if (result != null) {
      var ext = extension(result);

      if (ext.isEmpty) {
        result += '.wav';
      } else {
        ext = ext.substring(1);
      }

      var includeVideo = extVideo.contains(ext);

      await render(timeline, result, includeVideo: includeVideo);
      Prefs.export = dirname(result);
      return result;
    }
  }

  static Future<void> render(
    TimelineController timeline,
    String output, {
    bool includeVideo = false,
  }) async {
    var region = timeline.clip;
    if (region == null) throw 'No region in timeline.';

    var streamIndices = <int>[
      if (includeVideo) 0,
    ];

    var allAudioStreams = true;
    for (var audio in player.audio) {
      if (!audio.muted) {
        streamIndices.add(audio.stream!.json['index']);
      } else {
        allAudioStreams = false;
      }
    }

    var useCodecCopy = allAudioStreams && includeVideo;
    var mapping = streamIndices.expand((index) {
      return [
        '-map',
        '0:$index',
        if (useCodecCopy) ...['-c', 'copy'],
      ];
    });

    var args = [
      '-ss',
      '${region.start}',
      '-to',
      '${region.end}',
      '-i',
      player.video.current.media!.resource,
      ...mapping,
      '-y',
      output,
    ];

    await collectLines(args, useFFProbe: false);
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
