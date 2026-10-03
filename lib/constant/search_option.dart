/// 已废弃。
///
/// 早期这里的 `R34HomeFilterOption` 只有排序 / 时长 / 上传时间三个字段，而且
/// 首页和搜索结果页各维护一份，导致「搜索页只能改排序、没法再加时长条件」。
///
/// 现在统一用 `lib/constant/filter_selection.dart` 里的 `FilterSelection`
/// （排序 + 时长 + 上传时间，含自定义区间）。
///
/// 这个文件已没有任何引用，可以安全删除。
library;

export 'filter_selection.dart';
