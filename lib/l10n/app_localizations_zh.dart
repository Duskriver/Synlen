// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '词镜';

  @override
  String get settings => '设置';

  @override
  String get importBook => '导入书籍';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确认';

  @override
  String get chapter => '章节';

  @override
  String get page => '页面';

  @override
  String get progress => '进度';

  @override
  String get aiReading => 'AI 朗读';

  @override
  String get ttsVoice => '音色';

  @override
  String get ttsVoicePickerTitle => '选择音色';

  @override
  String get ttsVoicePickerSubtitle => '新音色会用于后续生成的朗读音频。';

  @override
  String get save => '保存';

  @override
  String get sortBy => '排序方式';

  @override
  String get title => '标题';

  @override
  String get recentlyAdded => '最近添加';

  @override
  String get recentlyRead => '最近阅读';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get failed => '失败';

  @override
  String get loading => '加载中';

  @override
  String get back => '返回';

  @override
  String get next => '下一页';

  @override
  String get previous => '上一页';

  @override
  String get close => '关闭';

  @override
  String get version => '版本';

  @override
  String get all => '全部';

  @override
  String get uncategorized => '未分类';

  @override
  String get selectAll => '全选';

  @override
  String get sort => '排序';

  @override
  String get editCategory => '编辑分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get sortBooksBy => '排序方式';

  @override
  String get titleAZ => '标题 (A-Z)';

  @override
  String get titleZA => '标题 (Z-A)';

  @override
  String get authorAZ => '作者 (A-Z)';

  @override
  String get authorZA => '作者 (Z-A)';

  @override
  String get readingProgress => '阅读进度';

  @override
  String get noItemsInCategory => '此分类中没有项目';

  @override
  String selected(int count) {
    return '已选择 $count 项';
  }

  @override
  String get move => '移动';

  @override
  String get deleted => '已删除';

  @override
  String get moveTo => '移动到';

  @override
  String get createNewCategory => '创建新分类';

  @override
  String get newCategory => '新分类';

  @override
  String get create => '创建';

  @override
  String get deleteBooks => '删除书籍';

  @override
  String get deleteBooksConfirm => '永久删除所选书籍？';

  @override
  String movedTo(String name) {
    return '已移动到“$name”';
  }

  @override
  String get failedToMove => '移动失败';

  @override
  String get failedToDelete => '删除失败';

  @override
  String get importing => '导入中';

  @override
  String get importCompleted => '导入完成';

  @override
  String importingProgress(int success, int failed, int remaining) {
    return '$success 成功，$failed 失败，$remaining 剩余';
  }

  @override
  String get importFailed => '导入失败，请重试。';

  @override
  String get importFailedDrm => '该书籍受 DRM 保护，无法导入。';

  @override
  String get importFileUnreadable => '无法读取所选文件。';

  @override
  String get importParseFailed => '无法解析书籍文件，文件可能已损坏或格式不受支持。';

  @override
  String get importDuplicateBook => '这本书已在书架中。';

  @override
  String get importFileWriteFailed => '书籍文件写入设备存储失败。';

  @override
  String get importSaveFailed => '书籍保存到书库失败。';

  @override
  String get details => '详情';

  @override
  String errorLoadingLibrary(String error) {
    return '加载书库时出错：$error';
  }

  @override
  String get bookNotFound => '未找到图书';

  @override
  String progressPercent(String percent) {
    return '进度：$percent%';
  }

  @override
  String get notStarted => '未开始';

  @override
  String chaptersCount(int count) {
    return '$count 章节';
  }

  @override
  String get bookFormatTxt => 'TXT';

  @override
  String epubVersion(String version) {
    return 'EPUB $version';
  }

  @override
  String get continueReading => '继续阅读';

  @override
  String get startReading => '开始阅读';

  @override
  String get collapse => '收起';

  @override
  String get expandAll => '展开全部';

  @override
  String errorLoadingBook(String error) {
    return '加载图书时出错：$error';
  }

  @override
  String get firstChapterOfBook => '这是本书的第一章';

  @override
  String get lastChapterOfBook => '这是本书的最后一章';

  @override
  String get lastPageOfBook => '这是本书的最后一页';

  @override
  String get firstPageOfBook => '这是本书的第一页';

  @override
  String get chapterHasNoContent => '本章节没有内容';

  @override
  String get never => '从未';

  @override
  String get failedToCreateCategory => '创建分类失败！';

  @override
  String get categoryNameCannotBeEmpty => '分类名称不能为空';

  @override
  String categoryCreated(String name) {
    return '分类“$name”已创建';
  }

  @override
  String categoryDeleted(String name) {
    return '分类“$name”已删除';
  }

  @override
  String get failedToDeleteCategory => '删除分类失败！';

  @override
  String get about => '关于';

  @override
  String get storage => '存储';

  @override
  String get cleanCache => '清理缓存';

  @override
  String get cleanCacheSubtitle => '删除孤立文件，并清理可重建的学习缓存（解释文本与发音音频）';

  @override
  String cleanCacheSuccessWithCount(int count) {
    return '清理完成，已删除 $count 个无用文件';
  }

  @override
  String get cleanCacheSuccess => '清理完成';

  @override
  String get cleanCacheFailed => '缓存清理未完成，请重试。';

  @override
  String get appAppearance => '外观';

  @override
  String get appThemeMode => '主题';

  @override
  String get appThemeModeSystem => '跟随系统';

  @override
  String get appThemeModeLight => '浅色';

  @override
  String get appThemeModeDark => '深色';

  @override
  String get appThemeVariant => '主题方案';

  @override
  String get aiService => 'AI 服务';

  @override
  String get deepSeekApiKey => 'DeepSeek API Key';

  @override
  String get deepSeekApiKeySubtitle => '用于单词解释与句子分析';

  @override
  String get aliyunTtsApiKey => '阿里云 TTS API Key';

  @override
  String get aliyunTtsApiKeySubtitle => '用于朗读发音（阿里云百炼，北京地域端点，其他地域的 Key 无法使用）';

  @override
  String get apiKeyNotConfigured => '未配置';

  @override
  String get apiKeyInputHint => '粘贴 API Key';

  @override
  String apiKeyObtainHint(String provider) {
    return '可在 $provider 控制台创建 API Key';
  }

  @override
  String get apiKeySaved => '已保存';

  @override
  String get apiKeyCleared => '已清除';

  @override
  String get clearKey => '清除 Key';

  @override
  String get projectInfo => '项目信息';

  @override
  String get github => 'GitHub';

  @override
  String get author => '作者';

  @override
  String get openSourceLicenses => '开源许可证';

  @override
  String get openSourceLicensesSubtitle => '显示应用中使用的开源库及其许可证';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkForUpdatesSubtitle => '检查是否有新版本可用';

  @override
  String get upToDate => '已是最新版本';

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String get updateViaChinaCloud => '蓝奏云下载';

  @override
  String get updateViaGithub => 'GitHub 下载';

  @override
  String get passwordCopied => '密码已复制';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get downloadAndInstall => '下载并安装';

  @override
  String get goToAppStore => '前往 App Store';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get downloadCompleted => '下载完成，请点击安装';

  @override
  String get installUnknownSourcesRequired => '需要允许安装未知来源应用，请到系统设置中开启';

  @override
  String get noUpdateChannel => '当前平台暂无更新渠道，请留意 GitHub Releases';

  @override
  String get updateInsecureUrl => '更新下载链接不安全（要求 HTTPS），已取消下载';

  @override
  String get updateChecksumMismatch => '安装包校验失败，请重试或前往 GitHub 下载';

  @override
  String get backupInvalidArchive => '备份文件损坏或超出大小限制，已取消恢复';

  @override
  String get backupDataCorrupted => '备份数据损坏或不完整，已取消恢复。';

  @override
  String get backupVersionTooNew => '备份由更新版本的应用创建，请升级后再恢复';

  @override
  String get languageNameInEnglish => 'Chinese';

  @override
  String get tips => '使用提示';

  @override
  String get tipLongPressTab => '长按标签页可编辑分组';

  @override
  String get tipLongPressNextTrack => '长按上/下一页按钮跳到上/下一章节';

  @override
  String get longPressToViewImage => '长按图片查看原图';

  @override
  String get importFromFolder => '扫描文件夹';

  @override
  String get importFiles => '导入文件';

  @override
  String get backupShared => '备份已通过分享功能导出';

  @override
  String exportFailed(String message) {
    return '备份失败：$message';
  }

  @override
  String progressing(String fileName) {
    return '正在处理：$fileName';
  }

  @override
  String get progressedAll => '全部处理完成';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get backupLibrary => '备份书库';

  @override
  String get library => '书库';

  @override
  String get backupLibraryDescription => '将书库导出为单个备份文件，并通过系统分享面板保存';

  @override
  String get restoreCompleted => '恢复完成';

  @override
  String get restoreFailed => '备份恢复失败，请重试。';

  @override
  String get restoring => '正在恢复';

  @override
  String restoringProgress(int success, int failed, int remaining) {
    return '$success 成功，$failed 失败，$remaining 剩余';
  }

  @override
  String get viewMode => '显示模式';

  @override
  String get viewModeCompact => '紧凑';

  @override
  String get viewModeRelaxed => '宽松';

  @override
  String get spliter => '，';

  @override
  String get shareBook => '分享书籍';

  @override
  String shareBookFailed(String error) {
    return '分享书籍失败：$error';
  }

  @override
  String get editBook => '编辑书籍';

  @override
  String get authors => '作者';

  @override
  String get bookDescription => '简介';

  @override
  String get bookSaved => '书籍已更新';

  @override
  String bookSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get authorsTooltip => '多个作者请使用英文半角逗号分隔';

  @override
  String get openStorageLocation => '打开存储位置';

  @override
  String get openStorageLocationSubtitle => '在文件管理器中打开词镜的存储目录';

  @override
  String openStorageLocationFailed(String error) {
    return '无法打开存储位置：$error';
  }

  @override
  String get openStorageLocationIOSMessage =>
      '请在文件应用中打开“我的 iPhone/iPad”下的“词镜”文件夹来访问存储位置';

  @override
  String get unsavedChangesTitle => '未保存的修改';

  @override
  String get unsavedChangesMessage => '您有未保存的修改，请选择操作。';

  @override
  String get discard => '放弃修改';

  @override
  String get titleRequired => '标题不能为空';

  @override
  String get readerTypographyLayout => '字体与排版';

  @override
  String get readerScale => '缩放';

  @override
  String get readerMargins => '边距';

  @override
  String get readerMarginTop => '上';

  @override
  String get readerMarginBottom => '下';

  @override
  String get readerMarginLeft => '左';

  @override
  String get readerMarginRight => '右';

  @override
  String get readerAppearance => '外观与主题';

  @override
  String get readerFollowAppTheme => '跟随应用主题';

  @override
  String get readerLinkHandlingSection => '链接处理';

  @override
  String get readerLinkHandlingAsk => '打开前询问';

  @override
  String get readerLinkHandlingAlways => '总是打开';

  @override
  String get readerLinkHandlingNever => '从不打开';

  @override
  String get readerHandleIntraLink => '跟随书内链接';

  @override
  String get readerPageAnimationSection => '翻页';

  @override
  String get readerPageAnimationNone => '无动画';

  @override
  String get readerPageAnimationSlide => '滑动翻页';

  @override
  String get readerVolumeKeyTurnsPage => '用音量键翻页';

  @override
  String get readerFontSection => '自定义字体';

  @override
  String get readerFontDefault => '书籍默认';

  @override
  String get readerOverrideFontFamily => '强制使用该字体';

  @override
  String get readerFontManageTip => '前往设置页面管理自定义字体';

  @override
  String get fontManagement => '字体管理';

  @override
  String get fontManagementSubtitle => '自定义字体（.ttf / .otf）';

  @override
  String get importFont => '导入字体';

  @override
  String importFontSuccess(String name) {
    return '字体“$name”已导入';
  }

  @override
  String importFontsSuccess(int count) {
    return '已导入 $count 个字体';
  }

  @override
  String importFontFailed(String error) {
    return '导入字体失败：$error';
  }

  @override
  String get deleteFontConfirm => '移除字体';

  @override
  String deleteFontConfirmText(String name) {
    return '确定要删除字体“$name”吗？此操作无法撤销';
  }

  @override
  String get noFontsHint => '暂无自定义字体';

  @override
  String cannotOpenLink(String url) {
    return '无法打开链接：$url';
  }

  @override
  String get openExternalLink => '打开外部链接';

  @override
  String openExternalLinkConfirmation(String url) {
    return '您正在尝试打开一个外部链接：$url\n\n是否继续？';
  }

  @override
  String get open => '打开';

  @override
  String get chapterNotFoundInSpine => '未找到该章节';

  @override
  String get sentenceAnalysis => '句子分析';

  @override
  String get playPronunciation => '播放发音';

  @override
  String get definitionUpdateFailed => '释义更新失败';

  @override
  String get wordExplanationLoading => '正在思考...';

  @override
  String get playAudio => '播放音频';

  @override
  String get readSentenceAloud => '朗读句子';

  @override
  String get analysisUpdateFailed => '分析更新失败';

  @override
  String get sentenceAnalyzing => '正在分析...';

  @override
  String loadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String audioUnavailable(String error) {
    return '音频暂不可用：$error';
  }

  @override
  String get aliyunDashScopeName => '阿里云 DashScope';

  @override
  String get learningErrorNoDeepSeekApiKey =>
      '未配置 DeepSeek API Key，请在 设置 → AI 服务 中配置';

  @override
  String get learningErrorNoAliyunTtsApiKey =>
      '未配置阿里云 TTS API Key，请在 设置 → AI 服务 中配置';

  @override
  String get learningErrorServiceUnavailable => 'AI 服务暂时不可用';

  @override
  String get learningErrorEmptyResult => '服务没有返回内容';

  @override
  String get learningErrorRequestFailed => '请求失败，请稍后重试';

  @override
  String get learningErrorAudioFileMissing => '音频文件不存在';

  @override
  String get learningErrorUnsupportedFormat => '仅支持 16-bit PCM 音频播放';

  @override
  String get learningErrorNoPlayableAudio => '没有可播放的音频';

  @override
  String get backupShareTitle => '词镜备份';

  @override
  String get apiKeyLoadFailed => '无法读取已保存的密钥，请重试。';

  @override
  String get apiKeySaveFailed => '密钥保存失败，请重试。';

  @override
  String get retry => '重试';

  @override
  String get readingProgressSaveFailed => '阅读进度保存失败，请重试。';

  @override
  String get restoreIncomplete => '恢复未完成，请检查备份后重试。';

  @override
  String get restoreSourceHint => '选择一个 .zip 备份文件，或从旧版本导出的备份文件夹恢复。';

  @override
  String get restoreSourceFile => '备份文件（.zip）';

  @override
  String get restoreSourceFolder => '备份文件夹（旧版）';

  @override
  String get originalSentence => '原句';

  @override
  String get aiServicePrivacyNote =>
      '点击单词、长按句子会把对应文本发送给第三方服务（词典、DeepSeek、阿里云 TTS）以获取学习内容；未配置密钥时不发起网络请求。';

  @override
  String get deepSeekCheckConnectivity => '检查 DeepSeek 连通性';

  @override
  String get deepSeekCheckOk => 'DeepSeek 连接成功';

  @override
  String get deepSeekCheckBadKey => 'DeepSeek 密钥无效或已过期';

  @override
  String get deepSeekCheckFailed => '无法连接 DeepSeek，请检查网络';

  @override
  String get readerLoadFailed => '无法打开这本书，请重试。';

  @override
  String get readerRenderFailed => '阅读排版更新失败，请重试。';
}
