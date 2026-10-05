# AGENTS.md

## 版本发布约定

当用户明确表示要「发布新版本」时，按以下步骤操作：

1. 升级应用版本：修改 `pubspec.yaml` 中的 `version` 字段（格式 `x.y.z+n`，例如 `1.0.0+1` → `1.0.1+2`）。
2. 创建并推送一个 commit message **以 `build:` 开头**的提交，以触发 GitHub Actions 自动编译 Android arm64 版本并发布 Release。

除此之外，**任何情况下都不要**创建 `build:` 开头的 commit。