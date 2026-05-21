import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebRadioPlayer {
  web.HTMLAudioElement? _audio;

  String? _streamUrl;

  void Function()? _onPlay;
  void Function()? _onPause;
  void Function(String error)? _onError;

  double _volume = 0.8;

  bool get isPlaying {
    final audio = _audio;
    return audio != null && audio.paused == false;
  }

  double get volume => _volume;

  void init({
    required String streamUrl,
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(String error) onError,
    double initialVolume = 0.8,
  }) {
    _streamUrl = streamUrl;
    _onPlay = onPlay;
    _onPause = onPause;
    _onError = onError;
    _volume = initialVolume.clamp(0.0, 1.0);
  }

  web.HTMLAudioElement _createAudio() {
    final streamUrl = _streamUrl;

    if (streamUrl == null || streamUrl.isEmpty) {
      throw StateError('Radio stream URL is not set.');
    }

    final audio = web.HTMLAudioElement()
      ..src = streamUrl
      ..crossOrigin = 'anonymous'
      ..preload = 'none'
      ..controls = false
      ..volume = _volume;

    audio.addEventListener(
      'play',
      (() {
        _onPlay?.call();
      }).toJS,
    );

    audio.addEventListener(
      'pause',
      (() {
        _onPause?.call();
      }).toJS,
    );

    audio.addEventListener(
      'ended',
      (() {
        _onPause?.call();
      }).toJS,
    );

    audio.addEventListener(
      'error',
      (() {
        _onError?.call('Radio stream could not be loaded.');
      }).toJS,
    );

    return audio;
  }

  void play() {
    stop();

    final audio = _createAudio();
    _audio = audio;

    audio.load();
    audio.play();
  }

  void pause() {
    final audio = _audio;
    if (audio == null) return;

    audio.pause();
  }

  void stop() {
    final audio = _audio;
    if (audio == null) return;

    audio.pause();
    audio.removeAttribute('src');
    audio.load();

    _audio = null;
  }

  void setVolume(double value) {
    _volume = value.clamp(0.0, 1.0);

    final audio = _audio;
    if (audio != null) {
      audio.volume = _volume;
    }
  }

  void dispose() {
    stop();
  }
}