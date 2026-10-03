import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/player/player_args.dart';
import 'package:r34_video/player/r34_player_controller.dart';
import 'package:r34_video/page/component/common/app_select_tile.dart';
import 'package:r34_video/provider/settings_provider.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) {
      return;
    }

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is! PlayerArgs) {
      return;
    }
    _args = rawArgs;

    final settings = context.read<SettingsProvider>();
    _controller = R34PlayerController(
      args: rawArgs,
      preferredLabel: settings.settingsModel.preferredQuality,
      autoPlay: settings.settingsModel.autoPlay,
    );
    _controller!.initialize();
  }

  @override
  void dispose() {
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
          ? const Center(
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

  /// 整屏的手势层：单击显隐控件，双击播放/暂停，连点两侧快进退。
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
