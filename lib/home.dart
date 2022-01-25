import 'dart:async';
import 'dart:ui';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/ffmpeg.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/prefs.dart';
import 'package:clipcutter/timeline.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _dragDropping = false;
  bool _init = false;

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

    setState(() => _init = true);

    try {
      ctrl.ready = false;
      await player.open(path, sctrl.add);
      ctrl.ready = true;

      if (ctx != null) {
        Navigator.pop(ctx!);
      }
      setState(() {
        ctrl.visible = Region(Duration.zero, player.duration!);
      });
    } catch (e) {
      setState(() {
        analysis = null;
        _init = false;
      });
    }
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

  void _handleKey(RawKeyEvent ev) {
    if (ev is! RawKeyDownEvent) return;

    switch (ev.logicalKey.keyLabel) {
      case ' ':
        if (!player.isPlaying && ctrl.clip != null) {
          ctrl.startTime = ctrl.clip!.start;
          player.playRegion(ctrl.clip!);
        } else {
          player.togglePlaying();
        }
        return;
      case 'R':
        if (ev.isControlPressed) _render();
        return;
      case 'O':
        if (ev.isControlPressed) _openFileDialog();
        return;
    }
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
        onKey: _handleKey,
        focusNode: FocusNode(),
        child: DropTarget(
          onDragDone: (details) {
            setState(() => _dragDropping = false);
            if (details.files.isNotEmpty) {
              var file = details.files.first;
              _manualLoad(file.path);
            }
          },
          onDragEntered: (details) {
            setState(() => _dragDropping = true);
          },
          onDragExited: (details) {
            setState(() => _dragDropping = false);
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: videoAspectRatio,
                          child: Opacity(
                            opacity: _init ? 1 : 0,
                            child: Video(
                              player: player.video,
                              showControls: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    if (analysis != null) Timeline(ctrl),
                  ],
                ),
              ),
              DropZone(_dragDropping || !_init, _dragDropping),
            ],
          ),
        ),
      ),
    );
  }
}

class DropZone extends StatelessWidget {
  final bool show;
  final bool dropping;

  const DropZone(this.show, this.dropping, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: dropping ? 4 : 0),
        duration: DropZoneCorner.transition,
        curve: DropZoneCorner.transitionCurve,
        builder: (ctx, value, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: value, sigmaY: value),
          child: child,
        ),
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: DropZoneCorner.transition,
          curve: DropZoneCorner.transitionCurve,
          child: Container(
            color: Colors.white70,
            child: Stack(
              children: [
                Center(
                  child: AnimatedScale(
                    duration: DropZoneCorner.transition,
                    curve: DropZoneCorner.transitionCurve,
                    scale: dropping ? 1.1 : 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Drag & Drop Videos Here',
                          style: Theme.of(context).textTheme.headline4,
                        ),
                        Text('(or press Ctrl+O)'),
                      ],
                    ),
                  ),
                ),
                DropZoneCorner(dropping, false, false),
                DropZoneCorner(dropping, false, true),
                DropZoneCorner(dropping, true, false),
                DropZoneCorner(dropping, true, true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DropZoneCorner extends StatelessWidget {
  static const padding = 16.0;
  static const length = 64.0;
  static const width = 12.0;
  static const transition = Duration(milliseconds: 400);
  static const transitionCurve = Curves.easeOutQuint;

  static final decoration = BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(8),
  );

  final bool top;
  final bool left;
  final bool show;

  const DropZoneCorner(this.show, this.top, this.left, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var pad = show ? padding : padding - 8;
    var l = show ? length : 40.0;

    return AnimatedPositioned(
      duration: transition,
      curve: transitionCurve,
      top: top ? pad : null,
      bottom: !top ? pad : null,
      left: left ? pad : null,
      right: !left ? pad : null,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: transition,
        curve: transitionCurve,
        child: Stack(
          alignment: Alignment(left ? -1 : 1, top ? -1 : 1),
          children: [
            AnimatedContainer(
              duration: transition,
              curve: transitionCurve,
              width: width,
              height: l,
              decoration: decoration,
            ),
            AnimatedContainer(
              duration: transition,
              curve: transitionCurve,
              width: l,
              height: width,
              decoration: decoration,
            ),
          ],
        ),
      ),
    );
  }
}
