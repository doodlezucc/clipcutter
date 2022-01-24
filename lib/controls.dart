class TimelineController {
  Duration? startTimestamp;
  Duration? startTime;
  Region? region;
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
