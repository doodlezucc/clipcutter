class TimelineController {
  Region? region;
}

class Region {
  Duration start;
  Duration length;

  Region(this.start, this.length);
}
