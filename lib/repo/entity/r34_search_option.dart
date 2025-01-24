enum VideoDuration {
  all,
  lessThanOneMin,
  oneMinToFiveMin,
  moreThanFiveMin,
}

class R34SearchOption {
  VideoDuration duration;

  R34SearchOption({this.duration = VideoDuration.all});
}
