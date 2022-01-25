import 'dart:async';
import 'dart:math';

import 'package:clipcutter/peaks.dart';
import 'package:dart_vlc/dart_vlc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'controls.dart';
import 'main.dart';

class Timeline extends StatefulWidget {
  final TimelineController controller;

  const Timeline(this.controller, {Key? key}) : super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  static const minVisibleLength = Duration(seconds: 1);
  int _dragRegionType = 0;

  // remove padding (hardcoded)
  double get _width => MediaQuery.of(context).size.width - 32;

  double _durationToPixels(Duration dur) {
    if (player.duration == null) return 0;

    return _width * div(dur, player.duration!);
  }

  Duration _tapToDuration(double localX) {
    var frac = localX / _width;

    frac = min(max(frac, 0), 1);
    return player.duration! * frac;
  }

  void _visibleRegion(double localX, [double? delta]) {
    Region region = widget.controller.visible;

    if (delta == null) {
      var startX = _durationToPixels(region.start);
      var endX = _durationToPixels(region.end);
      if ((startX - localX).abs() < 40) {
        _dragRegionType = -1;
      } else if ((endX - localX).abs() < 40) {
        _dragRegionType = 1;
      } else {
        _dragRegionType = 0;
      }
    }

    if (_dragRegionType == 0) {
      localX -= _durationToPixels(region.length) / 2;
    }
    var time = _tapToDuration(localX);

    if (_dragRegionType > 0) {
      var limit = region.start + minVisibleLength;
      if (time < limit) time = limit;
      region.end = time;
    } else if (_dragRegionType < 0) {
      var end = region.end;
      var limit = region.end - minVisibleLength;
      if (time > limit) time = limit;
      region.start = time;
      region.end = end;
    } else {
      var limitEnd = player.duration! - region.length;
      if (time > limitEnd) time = limitEnd;
      region.start = time;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var region = widget.controller.visible;

    return Column(
      children: [
        GestureDetector(
          onHorizontalDragDown: (details) {
            _visibleRegion(details.localPosition.dx);
          },
          onHorizontalDragUpdate: (details) {
            _visibleRegion(details.localPosition.dx, details.primaryDelta!);
          },
          child: Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[900]!,
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              margin: EdgeInsets.only(
                left: _durationToPixels(region.start),
                right: _durationToPixels(player.duration! - region.end),
              ),
              color: Colors.blue,
            ),
          ),
        ),
        SizedBox(height: 8),
        StreamsWidget(widget.controller),
      ],
    );
  }
}

class StreamsWidget extends StatefulWidget {
  final TimelineController controller;

  const StreamsWidget(this.controller, {Key? key}) : super(key: key);

  @override
  _StreamsWidgetState createState() => _StreamsWidgetState();
}

class _StreamsWidgetState extends State<StreamsWidget> {
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

    return _width *
        div(dur - widget.controller.visible.start,
            widget.controller.visible.length);
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
    return widget.controller.visible.start +
        widget.controller.visible.length * frac;
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

      Region? region = widget.controller.clip;

      if (region == null) {
        region = widget.controller.clip = Region(time, Duration());
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
        if (y < 104) {
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
      child: ListView.separated(
        itemBuilder: (ctx, i) => AudioPeaks(
          streams![i],
          _time,
          widget.controller,
        ),
        separatorBuilder: (ctx, i) => SizedBox(height: 8),
        itemCount: streams?.length ?? 0,
        shrinkWrap: true,
      ),
    );
  }
}
