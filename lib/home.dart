import 'dart:async';
import 'dart:math';

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
            if (analysis != null) Timeline(),
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
  const Timeline({Key? key}) : super(key: key);

  @override
  _TimelineState createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  final List<StreamSubscription> _subs = [];
  Duration _time = Duration.zero;
  Duration? _startTimestamp;
  Duration? _startTime;

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

  void _seekTap(double localX) {
    if (player.duration == null) {
      return print('not seekable');
    }

    // remove padding (hardcoded)
    var frac = localX / (MediaQuery.of(context).size.width - 32);
    frac = min(max(frac, 0), 1);
    setState(() {
      var nTime = player.duration! * frac;
      _time = nTime;
      _startTime = null;
      _startTimestamp = null;
      player.seek(nTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    var streams = analysis?.audioStreams;
    var progress = 0.0;

    if (player.duration != null) {
      progress = _time.inMilliseconds / player.duration!.inMilliseconds;
    }

    return GestureDetector(
      onTapDown: (details) {
        _seekTap(details.localPosition.dx);
      },
      onPanUpdate: (details) {
        _seekTap(details.localPosition.dx);
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
              itemBuilder: (ctx, i) => AudioPeaks(streams[i], progress),
              separatorBuilder: (ctx, i) => SizedBox(height: 16),
              itemCount: streams.length,
              shrinkWrap: true,
            ),
        ],
      ),
    );
  }
}
