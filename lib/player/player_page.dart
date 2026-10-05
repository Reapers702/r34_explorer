import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/player/player_args.dart';
import 'package:r34_video/player/r34_player_controller.dart';
import 'package:r34_video/page/component/common/app_select_tile.dart';
import 'package:r34_video/provider/settings_provider.dart';
import 'package:r34_video/repo/playback_progress_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:url_launcher/url_launcher.dart';

/// 应用内播放页。
///
/// 之前点播放是拼 `Intent` 丢给外部 App，现在整套播放（解析、切清晰度、
/// 进度、倍速、亮度外的常用操作）都在 App 内完成。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  R34PlayerController? _controller;
  PlayerArgs? _args;
  bool _fullscreen = false;
  bool _initStarted = false;
  String? _detailUrl;
  Timer? _progressTimer;

  /// 当前应用窗口亮度（0~1），由左半屏竖直滑动调节。
  double _brightness = 1.0;

  /// 手势锁定的主轴：横向调进度、竖向按左右半屏调音量/亮度。
  Axis? _dragAxis;

  /// 手势起始触点（局部坐标），用来判断主轴方向。
  Offset? _dragOrigin;

  /// 竖向拖动作用在右半屏（音量）还是左半屏（亮度）。
  bool _dragIsVolume = false;

  double _dragStartBrightness = 1.0;
  double _dragStartVolume = 100;
  double _dragStartProgress = 0;

  /// 横向拖动时的进度预览（0~1），松手前不真正 seek。
  double? _seekPreview;

  /// 手势浮层内容与自动隐藏定时器。
  ({IconData icon, String text})? _hud;
  Timer? _hudTimer;

  /// 判定手势主轴的最小平移距离，避免轻微抖动误触发。
  static const double _dragSlop = 8;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || _initStarted) {
      return;
    }

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is! PlayerArgs) {
      return;
    }
    _args = rawArgs;
    _detailUrl = rawArgs.detailUrl;
    _initStarted = true;
    _initController(rawArgs);
  }

  Future<void> _initController(PlayerArgs rawArgs) async {
    final settings = context.read<SettingsProvider>();
    unawaited(_readInitialBrightness());

    // 先读上次进度再建控制器，这样「续播起点」能在打开时一次性传入。
    final resume = rawArgs.detailUrl == null
        ? null
        : await PlaybackProgressRepo.getResume(rawArgs.detailUrl!);
    if (!mounted) {
      return;
    }

    _controller = R34PlayerController(
      args: rawArgs,
      preferredLabel: settings.settingsModel.preferredQuality,
      autoPlay: settings.settingsModel.autoPlay,
      initialPosition: resume,
      initialVolume: settings.settingsModel.volume,
    );
    _controller!.onVolumeChanged = (volume) {
      if (mounted) {
        context.read<SettingsProvider>().volume = volume;
      }
    };
    await _controller!.initialize();
    if (!mounted) {
      return;
    }
    setState(() {});
    _startProgressSaver();
  }

  /// 周期性 + 退出时保存播放位置，供下次续播。
  void _startProgressSaver() {
    const saveInterval = Duration(seconds: 15);
    _progressTimer = Timer.periodic(saveInterval, (_) => _saveProgress());
  }

  Future<void> _saveProgress() async {
    final url = _detailUrl;
    final controller = _controller;
    if (url == null || url.isEmpty || controller == null) {
      return;
    }
    await PlaybackProgressRepo.save(
      url,
      controller.position,
      controller.duration,
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _hudTimer?.cancel();
    _saveProgress();
    // 退出页面还原窗口亮度，避免影响其他页面。
    unawaited(_resetBrightness());
    if (_fullscreen) {
      unawaited(_leaveFullscreenSystemUi());
    }
    _controller?.dispose();
    super.dispose();
  }

  /// 读取当前应用窗口亮度作为手势起点；不支持时保持默认 1.0。
  Future<void> _readInitialBrightness() async {
    try {
      final value = await ScreenBrightness.instance.application;
      if (mounted) {
        setState(() => _brightness = value.clamp(0.0, 1.0));
      }
    } catch (_) {
      // 部分平台/模拟器不支持窗口亮度，忽略即可。
    }
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {
      // 忽略不支持窗口亮度时的异常。
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      // 忽略不支持窗口亮度时的异常。
    }
  }

  // ---- 系统 UI / 全屏 ----

  /// 进入全屏：转横屏 + 沉浸式全屏。
  Future<void> _enterFullscreenSystemUi() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 退出全屏：转回竖屏 + 边到边。
  Future<void> _leaveFullscreenSystemUi() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// 呼起系统下载：把当前清晰度的直链交给系统下载器/浏览器保存。
  Future<void> _callSystemDownload(R34PlayerController controller) async {
    final current = controller.current;
    if (current == null) {
      _toast('当前没有可下载的地址');
      return;
    }
    final url = current.url;
    final ok = await launchUrl(Uri.parse(url));
    if (!ok && mounted) {
      _toast('无法呼起系统下载：$url');
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _toggleFullscreen() {
    final controller = _controller;
    // 竖屏视频本身已铺满高度，横过来反而更小，直接提示。
    if (!_fullscreen && controller != null && controller.isPortrait) {
      _toast('竖屏视频，无需全屏');
      return;
    }
    setState(() {
      _fullscreen = !_fullscreen;
    });
    if (_fullscreen) {
      unawaited(_enterFullscreenSystemUi());
    } else {
      unawaited(_leaveFullscreenSystemUi());
    }
    controller?.pokeControls();
  }

  // ---- 交互 ----

  Future<void> _openResolutionPicker() async {
    final controller = _controller;
    if (controller == null || controller.args.resolutions.isEmpty) {
      return;
    }
    controller.setControlsVisible(true);

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        final current = controller.currentIndex;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  '选择清晰度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.args.resolutions.length,
                  itemBuilder: (context, index) {
                    final resolution = controller.args.resolutions[index];
                    return AppSelectTile<int>(
                      value: index,
                      selectedValue: current,
                      title: resolution.label,
                      subtitle: resolution.source.desc,
                      onSelected: (value) =>
                          Navigator.of(sheetContext).pop(value),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await controller.switchResolution(selected);
    }
  }

  Future<void> _openSpeedPicker() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.setControlsVisible(true);

    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  '播放速度',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...speeds.map(
                (speed) => AppSelectTile<double>(
                  value: speed,
                  selectedValue: controller.rate,
                  title: '${speed}x',
                  onSelected: (value) =>
                      Navigator.of(sheetContext).pop(value),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      await controller.setRate(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: AppColors.playerBackground,
      body: controller == null
          ? _initStarted
              ? const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Center(
                  child: Text(
                    '播放参数缺失',
                    style: TextStyle(color: AppColors.onDark),
                  ),
                )
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _buildPlayerBody(controller),
            ),
    );
  }

  Widget _buildPlayerBody(R34PlayerController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_fullscreen)
          SafeArea(
            bottom: false,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.aspectRatio,
                child: _buildVideoSurface(controller),
              ),
            ),
          )
        else
          _buildVideoSurface(controller),
        _buildTouchLayer(controller),
        _buildGestureHud(),
      ],
    );
  }

  /// 视频画面本身；非全屏时外层再套一层按真实宽高比的 `AspectRatio`。
  Widget _buildVideoSurface(R34PlayerController controller) {
    return ColoredBox(
      color: AppColors.playerBackground,
      child: Video(
        controller: controller.videoController,
        controls: NoVideoControls,
        fit: BoxFit.contain,
      ),
    );
  }

  /// 手势浮层：滑动时在屏幕中央显示亮度 / 音量 / 进度反馈。
  Widget _buildGestureHud() {
    final hud = _hud;
    if (hud == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hud.icon, color: AppColors.onDark, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    hud.text,
                    style: const TextStyle(
                      color: AppColors.onDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 整屏的手势层：单击显隐控件，双击播放/暂停，连点两侧快进退。
  /// 左半屏竖直滑动调亮度，右半屏竖直滑动调音量，横向滑动调进度。
  ///
  /// 控件作为手势层的子节点，因此按钮、进度条上的点按/拖动由它们自己消费，
  /// 其余空白区域仍归手势层——控件显示时也能正常滑动。
  Widget _buildTouchLayer(R34PlayerController controller) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.toggleControls,
        onDoubleTap: controller.playOrPause,
        onDoubleTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width * 0.3) {
            controller.skip(-10);
          } else if (details.localPosition.dx > width * 0.7) {
            controller.skip(10);
          }
        },
        onPanStart: (details) => _onDragStart(details.localPosition),
        onPanUpdate: (details) => _onDragUpdate(details.localPosition),
        onPanEnd: (_) => _onDragEnd(),
        onPanCancel: _onDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller.error != null)
              _buildErrorLayer(controller)
            else if (!controller.initialized || controller.buffering)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            if (controller.controlsVisible || controller.error != null)
              _buildControls(controller),
          ],
        ),
      ),
    );
  }

  void _onDragStart(Offset position) {
    final controller = _controller;
    _dragAxis = null;
    _dragOrigin = position;
    _dragIsVolume = position.dx >= MediaQuery.of(context).size.width * 0.5;
    _dragStartBrightness = _brightness;
    _dragStartVolume = controller?.volume ?? 100;
    _dragStartProgress = controller?.progress ?? 0;
    _seekPreview = null;
  }

  void _onDragUpdate(Offset position) {
    final controller = _controller;
    final origin = _dragOrigin;
    if (controller == null || origin == null) {
      return;
    }
    final total = position - origin;
    if (_dragAxis == null) {
      if (total.dx.abs() < _dragSlop && total.dy.abs() < _dragSlop) {
        return;
      }
      _dragAxis = total.dx.abs() >= total.dy.abs()
          ? Axis.horizontal
          : Axis.vertical;
    }

    final size = MediaQuery.of(context).size;
    if (_dragAxis == Axis.horizontal) {
      final next = (_dragStartProgress + total.dx / size.width).clamp(0.0, 1.0);
      setState(() => _seekPreview = next);
      final duration = controller.duration;
      _showHud(
        Icons.fast_forward_rounded,
        '${_formatDuration(duration * next)} / ${_formatDuration(duration)}',
      );
      return;
    }

    // 手指上滑为增大（竖直位移为负），满屏高度约对应 100%。
    final delta = -total.dy / size.height * 100;
    if (_dragIsVolume) {
      final next = (_dragStartVolume + delta).clamp(0.0, 100.0);
      controller.setVolume(next);
      _showHud(
        next <= 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        '音量 ${next.round()}%',
      );
    } else {
      final next = (_dragStartBrightness + delta / 100).clamp(0.05, 1.0);
      setState(() => _brightness = next);
      unawaited(_setBrightness(next));
      _showHud(
        next <= 0.3
            ? Icons.brightness_low_rounded
            : Icons.brightness_high_rounded,
        '亮度 ${(next * 100).round()}%',
      );
    }
  }

  void _onDragEnd() {
    if (_dragAxis == Axis.horizontal) {
      _commitSeekPreview();
    }
    _dragAxis = null;
    _dragOrigin = null;
    _scheduleHudHide();
  }

  /// 提交拖动预览：真正 seek 并清掉预览值。
  void _commitSeekPreview() {
    final controller = _controller;
    final preview = _seekPreview;
    if (controller != null && preview != null) {
      controller.seekToFraction(preview);
    }
    if (mounted && _seekPreview != null) {
      setState(() => _seekPreview = null);
    }
  }

  void _showHud(IconData icon, String text) {
    _hudTimer?.cancel();
    setState(() => _hud = (icon: icon, text: text));
  }

  void _scheduleHudHide() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _hud != null) {
        setState(() => _hud = null);
      }
    });
  }

  Widget _buildErrorLayer(R34PlayerController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.onDarkSecondary,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              controller.error ?? '播放失败',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onDarkSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => controller.retry(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(R34PlayerController controller) {
    return AnimatedOpacity(
      opacity: controller.controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !controller.controlsVisible,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB3000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xCC000000),
              ],
              stops: [0, 0.22, 0.6, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(controller),
                const Spacer(),
                _buildCenterControls(controller),
                const Spacer(),
                _buildBottomBar(controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(R34PlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.onDark,
            tooltip: '返回',
          ),
          Expanded(
            child: Text(
              _args?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _callSystemDownload(controller),
            icon: const Icon(Icons.download_rounded, size: 20),
            color: AppColors.onDark,
            tooltip: '系统下载',
          ),
          if (controller.current != null)
            TextButton.icon(
              onPressed: _openResolutionPicker,
              icon: const Icon(Icons.high_quality_rounded, size: 16),
              label: Text(controller.current!.label),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onDark,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(R34PlayerController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundIconButton(
          icon: Icons.replay_10_rounded,
          size: 26,
          tooltip: '后退10秒',
          onPressed: () => controller.skip(-10),
        ),
        const SizedBox(width: AppSpacing.xl),
        _RoundIconButton(
          icon: controller.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 40,
          tooltip: controller.playing ? '暂停' : '播放',
          onPressed: controller.playOrPause,
        ),
        const SizedBox(width: AppSpacing.xl),
        _RoundIconButton(
          icon: Icons.forward_10_rounded,
          size: 26,
          tooltip: '前进10秒',
          onPressed: () => controller.skip(10),
        ),
      ],
    );
  }

  Widget _buildBottomBar(R34PlayerController controller) {
    final progress = _seekPreview ?? controller.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(
                  _seekPreview == null
                      ? controller.position
                      : controller.duration * _seekPreview!,
                ),
                style: const TextStyle(
                  color: AppColors.onDarkSecondary,
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: _PlayerProgressBar(
                  progress: progress,
                  bufferStart: controller.bufferedStartProgress,
                  bufferEnd: controller.bufferedProgress,
                  onChanged: (fraction) =>
                      setState(() => _seekPreview = fraction),
                  onChangeEnd: _commitSeekPreview,
                ),
              ),
              Text(
                _formatDuration(
                  controller.duration > Duration.zero
                      ? controller.duration
                      : Duration.zero,
                ),
                style: const TextStyle(
                  color: AppColors.onDarkSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => controller.setVolume(
                  controller.volume > 0 ? 0 : 100,
                ),
                icon: Icon(
                  controller.volume > 0
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  size: 19,
                ),
                color: AppColors.onDark,
                tooltip: '静音',
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: AppColors.onDarkSecondary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.onDark,
                    overlayColor: Colors.white24,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 4),
                  ),
                  child: Slider(
                    value: controller.volume.clamp(0, 100),
                    max: 100,
                    onChanged: controller.setVolume,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openSpeedPicker,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onDark,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: Text('${controller.rate}x'),
              ),
              IconButton(
                onPressed: _toggleFullscreen,
                icon: Icon(
                  _fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  size: 20,
                ),
                color: AppColors.onDark,
                tooltip: _fullscreen ? '退出全屏' : '全屏',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onPressed;

  const _RoundIconButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white24,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(size * 0.28),
            child: Icon(icon, size: size, color: AppColors.onDark),
          ),
        ),
      ),
    );
  }
}

/// 自绘的播放进度条：同时表达「已播放」和「已缓冲区间」两段。
///
/// 不用 [Slider] 是因为它只能表达「从 0 到某个值」的区间，无法表示 seek
/// 之后从新位置开始的缓存窗口（旧缓存已被丢弃）。
class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar({
    required this.progress,
    required this.bufferStart,
    required this.bufferEnd,
    required this.onChanged,
    required this.onChangeEnd,
  });

  /// 播放位置（拖动时为预览位置），0~1。
  final double progress;

  /// 缓存窗口起止，0~1。
  final double bufferStart;
  final double bufferEnd;

  /// 拖动中持续回调预览值。
  final ValueChanged<double> onChanged;

  /// 松手/点击结束时回调，用于提交 seek。
  final VoidCallback onChangeEnd;

  /// 触摸热区高度：轨道很细，需要更大的手指落点。
  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width <= 0) {
            return const SizedBox.shrink();
          }
          double fractionOf(double dx) => (dx / width).clamp(0.0, 1.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                onChanged(fractionOf(details.localPosition.dx)),
            onTapUp: (_) => onChangeEnd(),
            onHorizontalDragStart: (details) =>
                onChanged(fractionOf(details.localPosition.dx)),
            onHorizontalDragUpdate: (details) =>
                onChanged(fractionOf(details.localPosition.dx)),
            onHorizontalDragEnd: (_) => onChangeEnd(),
            child: CustomPaint(
              painter: _ProgressTrackPainter(
                progress: progress,
                bufferStart: bufferStart,
                bufferEnd: bufferEnd,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressTrackPainter extends CustomPainter {
  const _ProgressTrackPainter({
    required this.progress,
    required this.bufferStart,
    required this.bufferEnd,
  });

  final double progress;
  final double bufferStart;
  final double bufferEnd;

  static const double _trackHeight = 2.5;
  static const double _thumbRadius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    void drawRange(double from, double to, Color color) {
      if (to <= from) {
        return;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            from * size.width,
            centerY - _trackHeight / 2,
            to * size.width,
            centerY + _trackHeight / 2,
          ),
          Radius.circular(_trackHeight / 2),
        ),
        Paint()..color = color,
      );
    }

    // 未加载 → 已缓冲 → 已播放，逐层覆盖。
    drawRange(0, 1, Colors.white24);
    drawRange(bufferStart, bufferEnd, Colors.white38);
    drawRange(0, progress, AppColors.primary);

    final maxX = size.width - _thumbRadius;
    final thumbX = maxX <= _thumbRadius
        ? size.width / 2
        : (progress * size.width).clamp(_thumbRadius, maxX);
    canvas.drawCircle(
      Offset(thumbX, centerY),
      _thumbRadius,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferStart != bufferStart ||
        oldDelegate.bufferEnd != bufferEnd;
  }
}
