import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:r34_video/player/player_args.dart';
import 'package:r34_video/util/log_util.dart';

/// 播放内核封装。
///
/// 把 `media_kit` 的 `Player` / `VideoController` 和「清晰度切换、失败重试、
/// 播放进度」这些页面真正关心的事收在一起，UI 层不直接碰内核。
/// 之后要换内核（比如换成 ExoPlayer 的 video_player），只需要改这一个文件。
class R34PlayerController extends ChangeNotifier {
  R34PlayerController({
    required this.args,
    String? preferredLabel,
    bool autoPlay = true,
    Duration? initialPosition,
    double initialVolume = 100,
  })  : _autoPlay = autoPlay,
        _resumeAt = initialPosition,
        _initialVolume = initialVolume,
        _currentIndex = args.initialIndex(preferredLabel) {
    _player = Player(
      configuration: const PlayerConfiguration(
        // 直播/点播都关掉，避免 mkv 里残留字幕轨道干扰。
        title: 'Rule34 Explorer',
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(_player);
    _attachStreams();
  }

  final PlayerArgs args;
  final bool _autoPlay;

  /// 需要续播的起点；null 表示从头播。
  final Duration? _resumeAt;

  /// 记住的起始音量（0-100），打开视频后应用到内核。
  final double _initialVolume;

  late final Player _player;
  late final VideoController _videoController;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  int _currentIndex = 0;
  bool _initialized = false;
  bool _buffering = true;
  bool _playing = false;
  bool _controlsVisible = true;
  bool _disposed = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  Duration _bufferStart = Duration.zero;
  int _width = 0;
  int _height = 0;
  double _volume = 100;
  double _rate = 1.0;
  String? _error;

  /// 音量变化回调（页面上用来持久化记忆音量）。
  void Function(double volume)? onVolumeChanged;

  Timer? _hideTimer;

  Player get player => _player;

  VideoController get videoController => _videoController;

  StreamResolution? get current => _currentIndex >= 0 && _currentIndex < args.resolutions.length
      ? args.resolutions[_currentIndex]
      : null;

  int get currentIndex => _currentIndex;

  bool get initialized => _initialized;

  bool get buffering => _buffering;

  bool get playing => _playing;

  bool get controlsVisible => _controlsVisible;

  Duration get position => _position;

  Duration get duration => _duration;

  /// 已缓冲到的位置。
  Duration get buffer => _buffer;

  /// 视频真实宽高比；未拿到元数据前按 16:9 兜底。
  double get aspectRatio {
    if (_width > 0 && _height > 0) {
      return _width / _height;
    }
    return 16 / 9;
  }

  /// 竖屏（高大于宽）视频；元数据未知时按非竖屏处理。
  bool get isPortrait => _width > 0 && _height > 0 && _height > _width;

  double get volume => _volume;

  double get rate => _rate;

  String? get error => _error;

  double get progress => _progressOf(_position);

  /// 当前 demuxer 缓存窗口的起点/终点占全片时长的比例（0~1）。
  ///
  /// 缓存是滑动窗口：seek 之后旧缓存会被丢弃，起点会跳到新位置附近，
  /// 所以不能简单地把「终点」当成「从头累计下载了多少」。
  double get bufferedStartProgress => _progressOf(_bufferStart);

  double get bufferedProgress => _progressOf(_buffer);

  double _progressOf(Duration value) {
    if (_duration.inMilliseconds <= 0) {
      return 0;
    }
    return (value.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 当前清晰度 URL 对应的 HTTP 头。
  ///
  /// rule34video 的 `get_file` 会 302 到 CDN，`remote_control.php` 只认带上
  /// `Referer` / `User-Agent` 的请求，否则会 403。这里是能播起来的关键。
  Map<String, String> get httpHeaders => const {
        'Referer': 'https://rule34video.com/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0.0',
      };

  Future<void> initialize() async {
    if (args.resolutions.isEmpty) {
      _error = '没有解析到可播放的地址';
      _buffering = false;
      _safeNotify();
      return;
    }
    // 先应用记住的音量再打开，避免从默认 100 跳到记忆值。
    unawaited(setVolume(_initialVolume));
    await _openIndex(_currentIndex, autoPlay: _autoPlay);
  }

  void _attachStreams() {
    _subscriptions.addAll([
      _player.stream.playing.listen((value) {
        _playing = value;
        _safeNotify();
      }),
      _player.stream.buffering.listen((value) {
        _buffering = value;
        _safeNotify();
      }),
      _player.stream.position.listen((value) {
        _position = value;
        _safeNotify();
      }),
      _player.stream.duration.listen((value) {
        _duration = value;
        _safeNotify();
      }),
      _player.stream.buffer.listen((value) {
        // 终点突然回退说明 demuxer cache 被 flush（内部 seek），缓存窗口跟着挪到新位置。
        if (value < _buffer) {
          _bufferStart = _position;
        }
        _buffer = value;
        _safeNotify();
      }),
      _player.stream.width.listen((value) {
        // 元数据未就绪时为 null，保留上一次的已知值。
        if (value != null) {
          _width = value;
          _safeNotify();
        }
      }),
      _player.stream.height.listen((value) {
        if (value != null) {
          _height = value;
          _safeNotify();
        }
      }),
      _player.stream.volume.listen((value) {
        _volume = value;
        _safeNotify();
      }),
      _player.stream.rate.listen((value) {
        _rate = value;
        _safeNotify();
      }),
      _player.stream.error.listen((value) {
        LogUtil.info('player error: $value');
        _error = value;
        _buffering = false;
        _safeNotify();
      }),
    ]);
  }

  Future<void> _openIndex(int index, {bool autoPlay = true}) async {
    final resolution = args.resolutions[index];
    _currentIndex = index;
    _error = null;
    _buffering = true;
    _position = Duration.zero;
    _duration = Duration.zero;
    _buffer = Duration.zero;
    _bufferStart = Duration.zero;
    _safeNotify();

    try {
      await _player.open(
        Media(resolution.url, httpHeaders: httpHeaders),
        play: autoPlay,
      );
      if (!_disposed) {
        _initialized = true;
        // 续播：打开后把进度定位到上次的位置。
        final resume = _resumeAt;
        if (resume != null && resume > Duration.zero) {
          unawaited(_player.seek(resume));
        }
        _safeNotify();
      }
    } catch (e, st) {
      LogUtil.error('player open failed: $e\n$st');
      _error = '播放失败：$e';
      _buffering = false;
      _safeNotify();
    }
  }

  Future<void> switchResolution(int index) async {
    if (index == _currentIndex ||
        index < 0 ||
        index >= args.resolutions.length) {
      return;
    }
    await _openIndex(index, autoPlay: true);
  }

  Future<void> retry() => _openIndex(_currentIndex, autoPlay: true);

  Future<void> playOrPause() => _player.playOrPause();

  /// 跳转到指定位置。
  ///
  /// seek 之后旧缓存会被丢弃，缓存窗口从新位置重新开始，所以这里同步挪动起点。
  Future<void> seek(Duration position) {
    _bufferStart = position;
    _safeNotify();
    return _player.seek(position);
  }

  Future<void> seekToFraction(double fraction) {
    if (_duration.inMilliseconds <= 0) {
      return Future.value();
    }
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    return seek(target);
  }

  Future<void> setVolume(double value) async {
    await _player.setVolume(value.clamp(0, 100));
    onVolumeChanged?.call(value.clamp(0, 100));
  }

  Future<void> setRate(double value) => _player.setRate(value);

  /// 快进/快退 [seconds] 秒。
  Future<void> skip(int seconds) {
    final target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) {
      return seek(Duration.zero);
    }
    if (_duration > Duration.zero && target > _duration) {
      return seek(_duration);
    }
    return seek(target);
  }

  // ---- 控件显隐 ----

  void setControlsVisible(bool visible) {
    if (_controlsVisible == visible) {
      return;
    }
    _controlsVisible = visible;
    if (visible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
    _safeNotify();
  }

  void toggleControls() => setControlsVisible(!_controlsVisible);

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (_playing && !_disposed) {
        setControlsVisible(false);
      }
    });
  }

  /// 触摸屏幕时调用：隐藏中则显示，显示中则重新计时。
  void pokeControls() {
    if (_controlsVisible) {
      _scheduleHide();
    } else {
      setControlsVisible(true);
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
