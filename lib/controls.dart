class TimelineController {
  Duration? startTimestamp;
  Duration? startTime;
  Region? clip;
  Region visible = Region(Duration.zero, Duration(seconds: 1));
  bool ready = false;
}

class Region {
  Duration start;
  Duration length;

  Duration get end => start + length;
  set end(Duration end) {
    length = end - start;
  }

  Region(this.start, this.length);
}
