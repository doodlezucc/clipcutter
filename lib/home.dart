import 'dart:async';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/ffmpeg.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/prefs.dart';
import 'package:clipcutter/timeline.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class LoadingDialog extends StatefulWidget {
  final String srcName;
  final Stream<String> stream;

  const LoadingDialog(this.srcName, this.stream, {Key? key}) : super(key: key);

  @override
  _LoadingDialogState createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog> {
  String message = 'Extracting streams...';

  @override
  void initState() {
    super.initState();
    widget.stream.listen((msg) {
      if (mounted) {
        setState(() {
          message = msg;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Loading "${widget.srcName}"'),
      content: Text(message),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ctrl = TimelineController();
  bool _showDrop = false;

  @override
  void initState() {
    super.initState();
    _manualLoad('test/dani.mp4', dialog: false);
  }

  void _manualLoad(String path, {bool dialog = true}) async {
    ctrl.clip = null;
    var sctrl = StreamController<String>();
    BuildContext? ctx;

    if (dialog) {
      showDialog(
          context: context,
          builder: (context) {
            ctx = context;
            return LoadingDialog(p.basename(path), sctrl.stream);
          });
    }

    ctrl.ready = false;
    await player.open(path, sctrl.add);
    ctrl.ready = true;

    if (ctx != null) {
      Navigator.pop(ctx!);
    }
    setState(() {
      ctrl.visible = Region(Duration.zero, player.duration!);
    });
  }

  void _openFileDialog() async {
    var result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Video',
      type: FileType.video,
      allowCompression: false,
      lockParentWindow: true,
      initialDirectory: Prefs.import,
    );
    if (result != null) {
      var path = result.files.first.path!;
      _manualLoad(path);
      Prefs.import = p.dirname(path);
      Prefs.save();
    }
  }

  void _render() async {
    var s = await FFmpeg.renderDialog(ctrl);
    if (s == null) return;
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: Text('Exported to $s'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text('OK'),
              )
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    double videoAspectRatio = 1920 / 1080;

    if (player.video.videoDimensions.width > 0) {
      videoAspectRatio = player.video.videoDimensions.width /
          player.video.videoDimensions.height;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Clipcutter'),
        centerTitle: true,
        leadingWidth: 80,
        toolbarHeight: 48,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _openFileDialog,
              icon: Icon(Icons.folder_open),
              tooltip: 'Open Video',
            ),
            IconButton(
              onPressed: _render,
              icon: Icon(Icons.movie_creation),
              tooltip: 'Export Clip',
            ),
          ],
        ),
      ),
      body: RawKeyboardListener(
        autofocus: true,
        onKey: (ev) {
          switch (ev.character) {
            case ' ':
              if (!player.isPlaying && ctrl.clip != null) {
                ctrl.startTime = ctrl.clip!.start;
                player.playRegion(ctrl.clip!);
              } else {
                player.togglePlaying();
              }
              return;
            case 'R':
              return _render();
          }
        },
        focusNode: FocusNode(),
        child: DropTarget(
          onDragDone: (details) {
            if (details.files.isNotEmpty) {
              var file = details.files.first;
              _manualLoad(file.path);
            }
          },
          onDragEntered: (details) {
            setState(() => _showDrop = true);
          },
          onDragExited: (details) {
            setState(() => _showDrop = false);
          },
          child: Stack(
            children: [
              if (_showDrop) DropZone(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: videoAspectRatio,
                          child:
                              Video(player: player.video, showControls: false),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    if (analysis != null) Timeline(ctrl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropZone extends StatelessWidget {
  const DropZone({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white54,
    );
  }
}
