import 'dart:async';
import 'dart:math';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/ffmpeg.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/peaks.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  @override
  void initState() {
    super.initState();
    _manualLoad('test/dani.mp4', dialog: false);
  }

  void _manualLoad(String path, {bool dialog = true}) async {
    ctrl.region = null;
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
    setState(() {});
  }

  void _openFileDialog() async {
    var result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Video',
      type: FileType.video,
      allowCompression: false,
      lockParentWindow: true,
    );
    if (result != null) {
      _manualLoad(result.files.first.path!);
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
              if (!player.isPlaying && ctrl.region != null) {
                ctrl.startTime = ctrl.region!.start;
                player.playRegion(ctrl.region!);
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: videoAspectRatio,
                    child: Video(player: player.video, showControls: false),
                  ),
                ),
                SizedBox(height: 8),
                if (analysis != null) Timeline(ctrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Timeline extends StatefulWidget {
  final TimelineController controller;

  const Timeline(this.controller, {Key? key}) : super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  static const minRegionLength = Duration(milliseconds: 200);
  final List<StreamSubscription> _subs = [];
  Duration _time = Duration.zero;
  bool _dragRegionEnd = false;

  @override
  void initState() {
    super.initState();
    _subs.add(player.video.playbackStream.listen(_onPlaybackChange));
    _subs.add(frameStream.listen(_eachFrame));
  }

  @override
  void dispose() {
    for (var sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  void _eachFrame(Duration timestamp) {
    if (player.isPlaying && widget.controller.ready) {
      widget.controller.startTime ??= _time;
      widget.controller.startTimestamp ??= timestamp;

      setState(() {
        var diff = timestamp - widget.controller.startTimestamp!;
        _time = widget.controller.startTime! + diff;
        SchedulerBinding.instance!.scheduleFrame();
      });
    }
  }

  void _onPlaybackChange(PlaybackState state) {
    if (!widget.controller.ready) return;
    setState(() {
      if (!state.isPlaying || state.isCompleted) {
        widget.controller.startTime = null;
        widget.controller.startTimestamp = null;
      }

      if (state.isCompleted) {
        _time = Duration.zero;
        player.seek(Duration.zero);
        setState(() {
          player.play();
        });
      }
    });
  }

  // remove padding (hardcoded)
  double get _width => MediaQuery.of(context).size.width - 32;

  double _durationToPixels(Duration dur) {
    if (player.duration == null) return 0;

    return _width * div(dur, player.duration!);
  }

  Duration _tapToDuration(double localX, {bool snap = false}) {
    if (snap) {
      var cursorX = _durationToPixels(_time);
      if ((localX - cursorX).abs() < 20) {
        return _time;
      }
    }

    var frac = localX / _width;

    frac = min(max(frac, 0), 1);
    return player.duration! * frac;
  }

  void _seekTap(double localX) {
    if (player.duration == null) {
      return print('not seekable');
    }

    setState(() {
      var nTime = _tapToDuration(localX, snap: false);
      _time = nTime;
      widget.controller.startTime = null;
      widget.controller.startTimestamp = null;
      player.seek(nTime);
    });
  }

  void _regionTap(double localX, bool hold) {
    setState(() {
      var time = _tapToDuration(localX);

      Region? region = widget.controller.region;

      if (region == null) {
        region = widget.controller.region = Region(time, Duration());
        _dragRegionEnd = true;
      } else if (!hold) {
        var diffStart = (time - region.start).abs();
        var diffEnd = (time - region.end).abs();
        _dragRegionEnd = diffEnd < diffStart;
      }

      if (_dragRegionEnd) {
        var limit = region.start + minRegionLength;
        if (time < limit) time = limit;
        region.end = time;
      } else {
        var end = region.end;
        var limit = region.end - minRegionLength;
        if (time > limit) time = limit;
        region.start = time;
        region.end = end;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var streams = analysis?.audioStreams;

    return GestureDetector(
      onTapDown: (details) {
        var y = details.localPosition.dy;
        if (y < 105) {
          player.audio[0].muted = false;
          player.audio[1].muted = true;
        } else {
          player.audio[0].muted = true;
          player.audio[1].muted = false;
        }
        _seekTap(details.localPosition.dx);
      },
      onHorizontalDragUpdate: (details) {
        _seekTap(details.localPosition.dx);
      },
      onScaleUpdate: (details) {
        _regionTap(details.localFocalPoint.dx, true);
      },
      onScaleStart: (details) {
        _regionTap(details.localFocalPoint.dx, false);
      },
      onSecondaryTapDown: (details) {
        _regionTap(details.localPosition.dx, false);
      },
      child: Column(
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[900]!,
            ),
          ),
          SizedBox(height: 8),
          if (streams != null)
            ListView.separated(
              itemBuilder: (ctx, i) =>
                  AudioPeaks(streams[i], _time, widget.controller.region),
              separatorBuilder: (ctx, i) => SizedBox(height: 16),
              itemCount: streams.length,
              shrinkWrap: true,
            ),
        ],
      ),
    );
  }
}
