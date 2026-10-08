# i18n 扩展约定

已配置 SwiftPM defaultLocalization 为 zh-Hans，并使用独立资源 bundle。时间格式使用稳定键：age.minutes_seconds、age.minutes、age.hours_minutes、age.days_hours。已有简体中文与英文资源。

新增语言：在 Sources/iClip/Resources/<语言代码>.lproj/Localizable.strings 添加相同键，保留占位符数量与类型。时间计算位于 iClipCore/EntryAge，与 UI 字符串分离。

当前仅时间显示接入上述资源，其他 UI 仍为中文，未宣称完成全界面翻译。后续将其他界面文字逐步迁移为稳定键，并显式使用 Localization.bundle；安装的 app 从 Contents/Resources 读取，swift run 才回退到 Bundle.module，避免依赖本机编译目录。

打包脚本复制并签名 iClip_iClip.bundle；添加资源后需重新构建应用包。
