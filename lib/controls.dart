class TimelineController {
  Region? region;
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
