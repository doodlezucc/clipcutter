import 'dart:async';
import 'dart:math';

import 'package:clipcutter/controls.dart';
import 'package:clipcutter/main.dart';
import 'package:clipcutter/peaks.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
    _manualReload();
  }

  void _manualReload() async {
    await reloadVideo();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        autofocus: true,
        onKey: (ev) {
          if (ev.character == ' ') {
            player.togglePlaying();
          }
        },
        focusNode: FocusNode(),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(16),
          children: <Widget>[
            Video(
              player: player.video,
              height: 400,
              showControls: false,
            ),
            SizedBox(height: 8),
            if (analysis != null) Timeline(ctrl),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualReload,
        child: const Icon(Icons.add),
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
  final List<StreamSubscription> _subs = [];
  Duration _time = Duration.zero;
  Duration? _startTimestamp;
  Duration? _startTime;
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
    if (player.isPlaying) {
      _startTime ??= _time;
      _startTimestamp ??= timestamp;

      setState(() {
        var diff = timestamp - _startTimestamp!;
        _time = _startTime! + diff;
        SchedulerBinding.instance!.scheduleFrame();
      });
    }
  }

  void _onPlaybackChange(PlaybackState state) {
    setState(() {
      if (state.isCompleted) {
        _time = Duration.zero;
        _startTime = null;
        _startTimestamp = null;
        player.seek(Duration.zero);
        setState(() {
          print('restart');
          player.play();
        });
      }

      if (!state.isPlaying) {
        _startTime = null;
        _startTimestamp = null;
      }
    });
  }

  // remove padding (hardcoded)
  double get _width => MediaQuery.of(context).size.width - 32;

  double _durationToPixels(Duration dur) {
    if (player.duration == null) return 0;

    return _width * div(dur, player.duration!);
  }

  Duration _tapToDuration(double localX, {bool snap = true}) {
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
      _startTime = null;
      _startTimestamp = null;
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
        region.end = time;
      } else {
        var end = region.end;
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
