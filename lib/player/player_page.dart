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

  /// 亮度手势（0~1，1 表示不遮罩）。
  double _brightness = 1.0;

  /// 当前竖向拖动手势作用在左（亮度）还是右（音量）半屏。
  bool? _dragIsVolume;
  double? _dragStartBrightness;
  double? _dragStartVolume;

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
    _saveProgress();
    if (_fullscreen) {
      _leaveFullscreenSystemUi();
    }
    _controller?.dispose();
    super.dispose();
  }

  // ---- 系统 UI / 全屏 ----

  void _enterFullscreenSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _leaveFullscreenSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    setState(() {
      _fullscreen = !_fullscreen;
    });
    if (_fullscreen) {
      _enterFullscreenSystemUi();
    } else {
      _leaveFullscreenSystemUi();
    }
    _controller?.pokeControls();
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
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildVideoSurface(controller),
            ),
          )
        else
          _buildVideoSurface(controller),
        _buildBrightnessOverlay(controller),
        _buildTouchLayer(controller),
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
    );
  }

  Widget _buildVideoSurface(R34PlayerController controller) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: AppColors.playerBackground,
        child: Video(
          controller: controller.videoController,
          controls: NoVideoControls,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// 竖直滑动调亮度：只覆盖视频区域，黑色遮罩模拟变暗（不引额外依赖）。
  Widget _buildBrightnessOverlay(R34PlayerController controller) {
    if (_brightness >= 0.999) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: (1 - _brightness).clamp(0.0, 1.0)),
          ),
        ),
      ),
    );
  }

  /// 整屏的手势层：单击显隐控件，双击播放/暂停，连点两侧快进退。
  /// 左侧竖直滑动调亮度，右侧竖直滑动调音量。
  Widget _buildTouchLayer(R34PlayerController controller) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.pokeControls,
        onDoubleTap: controller.playOrPause,
        onDoubleTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.localPosition.dx < width * 0.3) {
            controller.skip(-10);
          } else if (details.localPosition.dx > width * 0.7) {
            controller.skip(10);
          }
        },
        onVerticalDragStart: (details) {
          final width = MediaQuery.of(context).size.width;
          final isVolume = details.localPosition.dx >= width * 0.5;
          _dragIsVolume = isVolume;
          _dragStartBrightness = _brightness;
          _dragStartVolume = controller.volume;
        },
        onVerticalDragUpdate: (details) {
          final height = MediaQuery.of(context).size.height;
          // 手指上滑 -> 增大（detail.delta.dy 为负）。
          final primary = details.primaryDelta;
          final delta = primary == null ? 0.0 : -primary;
          if (_dragIsVolume == true) {
            final start = _dragStartVolume ?? controller.volume;
            final next = (start + delta / height * 200).clamp(0.0, 100.0);
            controller.setVolume(next);
          } else if (_dragIsVolume == false) {
            final start = _dragStartBrightness ?? _brightness;
            final next = (start + delta / height * 200 / 100).clamp(0.0, 1.0);
            setState(() => _brightness = next);
          }
        },
        onVerticalDragEnd: (_) {
          _dragIsVolume = null;
          _dragStartBrightness = null;
          _dragStartVolume = null;
        },
        child: const SizedBox.expand(),
      ),
    );
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
                _formatDuration(controller.position),
                style: const TextStyle(
                  color: AppColors.onDarkSecondary,
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: controller.progress,
                    onChanged: (value) => controller.seekToFraction(value),
                  ),
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
