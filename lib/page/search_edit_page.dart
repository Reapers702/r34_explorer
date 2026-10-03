import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/provider/search_edit_provider.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class SearchEditPage extends StatefulWidget {
  const SearchEditPage({super.key});

  @override
  State<SearchEditPage> createState() => _SearchEditPageState();
}

class _SearchEditPageState extends State<SearchEditPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<SearchEditProvider>();
      provider.loadHistory();
      provider.loadTrending();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      _toast('请输入要搜索的内容');
      return;
    }

    context.read<SearchEditProvider>().addSearchHistory(text);
    Navigator.of(context).pushNamed(
      PageRoutes.searchResultPage,
      arguments: SearchResultPageArgs(text),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchEditProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.page,
        title: Row(
          children: [
            Expanded(
              child: AppSearchBar(
                controller: _controller,
                autofocus: true,
                hintText: '搜点东西试试',
                onSubmitted: _submit,
                onClear: () => _controller.clear(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () => _submit(_controller.text),
              child: const Text('搜索'),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await provider.loadTrending();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            SectionHeader(
              title: '搜索历史',
              trailing: provider.history.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => provider.clearSearchHistory(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.textHint,
                      ),
                      child: const Text(
                        '清空',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
            ),
            if (provider.historyLoading && provider.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppSkeleton(height: 28),
              )
            else if (provider.history.isEmpty)
              const InlineEmpty('还没有搜索记录')
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: provider.history
                      .map(
                        (e) => VideoSearchHistoryChip(
                          e,
                          onDelete: () => provider.removeSearchHistory(e),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SectionHeader(title: '热搜 Tag'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingTags.isEmpty,
              children: provider.trendingTags
                  .map((e) => VideoTagChip(e))
                  .toList(),
            ),
            const SectionHeader(title: '热搜分类'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingCategories.isEmpty,
              children: provider.trendingCategories
                  .map((e) => VideoCategoryChip(e, showAvatar: true))
                  .toList(),
            ),
            const SectionHeader(title: '热搜创作者'),
            _buildChipSection(
              loading: provider.trendingLoading,
              empty: provider.trendingArtists.isEmpty,
              children: provider.trendingArtists
                  .map((e) => VideoArtistChip(e, showAvatar: true))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipSection({
    required bool loading,
    required bool empty,
    required List<Widget> children,
  }) {
    if (loading && empty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppSkeleton(height: 28),
      );
    }
    if (empty) {
      return const InlineEmpty('暂时没取到数据，下拉刷新试试');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: children,
      ),
    );
  }
}
