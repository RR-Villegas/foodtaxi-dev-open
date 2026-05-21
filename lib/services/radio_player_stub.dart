class WebRadioPlayer {
  double _volume = 0.5;

  bool get isPlaying => false;

  double get volume => _volume;

  void init({
    required String streamUrl,
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(String error) onError,
    double initialVolume = 0.5,
  }) {
    _volume = initialVolume.clamp(0.0, 1.0).toDouble();
  }

  void play() {
    throw UnsupportedError(
      'Radio playback is currently available on web only.',
    );
  }

  void pause() {}

  void stop() {}

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0).toDouble();
  }

  void dispose() {}
}