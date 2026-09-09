// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Synlen';

  @override
  String get settings => 'Settings';

  @override
  String get importBook => 'Import Book';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get chapter => 'Chapter';

  @override
  String get page => 'Page';

  @override
  String get progress => 'Progress';

  @override
  String get aiReading => 'AI Reading';

  @override
  String get ttsVoice => 'Voice';

  @override
  String get ttsVoicePickerTitle => 'Choose Voice';

  @override
  String get ttsVoicePickerSubtitle =>
      'New voice selections apply to newly generated reading audio.';

  @override
  String get save => 'Save';

  @override
  String get sortBy => 'Sort by';

  @override
  String get title => 'Title';

  @override
  String get recentlyAdded => 'Recently Added';

  @override
  String get recentlyRead => 'Recently Read';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get loading => 'Loading';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get close => 'Close';

  @override
  String get version => 'Version';

  @override
  String get all => 'All';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get selectAll => 'Select All';

  @override
  String get sort => 'Sort';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get categoryName => 'Category name';

  @override
  String get sortBooksBy => 'Sort Books by';

  @override
  String get titleAZ => 'Title (A-Z)';

  @override
  String get titleZA => 'Title (Z-A)';

  @override
  String get authorAZ => 'Author (A-Z)';

  @override
  String get authorZA => 'Author (Z-A)';

  @override
  String get readingProgress => 'Reading Progress';

  @override
  String get noItemsInCategory => 'No items in this Category';

  @override
  String selected(int count) {
    return '$count selected';
  }

  @override
  String get move => 'Move';

  @override
  String get deleted => 'Deleted';

  @override
  String get moveTo => 'Move to';

  @override
  String get createNewCategory => 'Create New Category';

  @override
  String get newCategory => 'New Category';

  @override
  String get create => 'Create';

  @override
  String get deleteBooks => 'Delete Books';

  @override
  String get deleteBooksConfirm => 'Delete selected books permanently?';

  @override
  String movedTo(String name) {
    return 'Moved to \"$name\"';
  }

  @override
  String get failedToMove => 'Failed to move items';

  @override
  String get failedToDelete => 'Failed to delete';

  @override
  String get importing => 'Importing';

  @override
  String get importCompleted => 'Import completed';

  @override
  String importingProgress(int success, int failed, int remaining) {
    return '$success success, $failed failed, $remaining remaining';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get details => 'Details';

  @override
  String errorLoadingLibrary(String error) {
    return 'Error loading library: $error';
  }

  @override
  String get bookNotFound => 'Book not found';

  @override
  String progressPercent(String percent) {
    return 'Progress: $percent%';
  }

  @override
  String get notStarted => 'Not started';

  @override
  String chaptersCount(int count) {
    return '$count chapters';
  }

  @override
  String get bookFormatTxt => 'TXT';

  @override
  String epubVersion(String version) {
    return 'EPUB $version';
  }

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get startReading => 'Start Reading';

  @override
  String get collapse => 'Collapse';

  @override
  String get expandAll => 'Expand all';

  @override
  String errorLoadingBook(String error) {
    return 'Error loading book: $error';
  }

  @override
  String get firstChapterOfBook => 'This is the first chapter of the book';

  @override
  String get lastChapterOfBook => 'This is the last chapter of the book';

  @override
  String get lastPageOfBook => 'This is the last page of the book';

  @override
  String get firstPageOfBook => 'This is the first page of the book';

  @override
  String get chapterHasNoContent => 'This chapter has no content';

  @override
  String get never => 'Never';

  @override
  String get failedToCreateCategory => 'Failed to create category!';

  @override
  String get categoryNameCannotBeEmpty => 'Category name cannot be empty';

  @override
  String categoryCreated(String name) {
    return 'Category \"$name\" created';
  }

  @override
  String categoryDeleted(String name) {
    return 'Category \"$name\" deleted';
  }

  @override
  String get failedToDeleteCategory => 'Failed to delete category!';

  @override
  String get about => 'About';

  @override
  String get storage => 'Storage';

  @override
  String get cleanCache => 'Clean Cache';

  @override
  String get cleanCacheSubtitle =>
      'Remove orphan files and clear the rebuildable learning cache (explanations and audio)';

  @override
  String cleanCacheSuccessWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return 'Cache cleaned. Removed $count unused $_temp0.';
  }

  @override
  String get cleanCacheSuccess => 'Cache cleaned';

  @override
  String get appAppearance => 'Appearance';

  @override
  String get appThemeMode => 'Theme';

  @override
  String get appThemeModeSystem => 'System';

  @override
  String get appThemeModeLight => 'Light';

  @override
  String get appThemeModeDark => 'Dark';

  @override
  String get appThemeVariant => 'Theme Variant';

  @override
  String get aiService => 'AI Service';

  @override
  String get deepSeekApiKey => 'DeepSeek API Key';

  @override
  String get deepSeekApiKeySubtitle =>
      'Used for word explanation and sentence analysis';

  @override
  String get aliyunTtsApiKey => 'Aliyun TTS API Key';

  @override
  String get aliyunTtsApiKeySubtitle =>
      'Used for read-aloud (Aliyun Model Studio, Beijing region endpoint only)';

  @override
  String get apiKeyNotConfigured => 'Not configured';

  @override
  String get apiKeyInputHint => 'Paste API key';

  @override
  String apiKeyObtainHint(String provider) {
    return 'Create an API key in the $provider console';
  }

  @override
  String get apiKeySaved => 'Saved';

  @override
  String get apiKeyCleared => 'Cleared';

  @override
  String get clearKey => 'Clear key';

  @override
  String get projectInfo => 'Project Info';

  @override
  String get github => 'GitHub';

  @override
  String get author => 'Author';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get openSourceLicensesSubtitle =>
      'View open source libraries used in the app and their licenses';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkForUpdatesSubtitle => 'Check if a new version is available';

  @override
  String get upToDate => 'Already up to date';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String get updateViaChinaCloud => 'Download via Lanzou';

  @override
  String get updateViaGithub => 'Download via GitHub';

  @override
  String get passwordCopied => 'Password copied';

  @override
  String get updateCheckFailed => 'Failed to check for updates';

  @override
  String get downloadAndInstall => 'Download & install';

  @override
  String get goToAppStore => 'Go to App Store';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadCompleted => 'Download complete, tap to install';

  @override
  String get installUnknownSourcesRequired =>
      'Installing apps from unknown sources must be enabled in system settings';

  @override
  String get noUpdateChannel =>
      'No update channel available for this platform yet, please check GitHub Releases';

  @override
  String get languageNameInEnglish => 'English';

  @override
  String get tips => 'Tips';

  @override
  String get tipLongPressTab => 'Long press on tab to edit category';

  @override
  String get tipLongPressNextTrack =>
      'Long press previous/next button to jump to previous/next chapter';

  @override
  String get longPressToViewImage => 'Long press on image to view original';

  @override
  String get importFromFolder => 'Scan Folder';

  @override
  String get importFiles => 'Import Files';

  @override
  String get backupShared => 'Backup successfully shared';

  @override
  String exportFailed(String message) {
    return 'Backup failed: $message';
  }

  @override
  String progressing(String fileName) {
    return 'Processing $fileName';
  }

  @override
  String get progressedAll => 'All Processed';

  @override
  String get restoreFromBackup => 'Restore from Backup';

  @override
  String get backupLibrary => 'Backup Library';

  @override
  String get library => 'Library';

  @override
  String get backupLibraryDescription =>
      'Export your library as a single backup file via the system share sheet';

  @override
  String get restoreCompleted => 'Restore Completed';

  @override
  String restoreFailed(String message) {
    return 'Failed to restore backup: $message';
  }

  @override
  String get restoring => 'Restoring';

  @override
  String restoringProgress(int success, int failed, int remaining) {
    return '$success success, $failed failed, $remaining remaining';
  }

  @override
  String get viewMode => 'View Mode';

  @override
  String get viewModeCompact => 'Compact';

  @override
  String get viewModeRelaxed => 'Relaxed';

  @override
  String get spliter => ', ';

  @override
  String get shareBook => 'Share book';

  @override
  String shareBookFailed(String error) {
    return 'Failed to share book: $error';
  }

  @override
  String get editBook => 'Edit Book';

  @override
  String get authors => 'Authors';

  @override
  String get bookDescription => 'Description';

  @override
  String get bookSaved => 'Book updated';

  @override
  String bookSaveFailed(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get authorsTooltip => 'Separate multiple authors with commas';

  @override
  String get openStorageLocation => 'Open Storage Location';

  @override
  String get openStorageLocationSubtitle =>
      'Open the folder where Synlen stores its data (cache, books, etc.)';

  @override
  String openStorageLocationFailed(String error) {
    return 'Failed to open storage location: $error';
  }

  @override
  String get openStorageLocationIOSMessage =>
      'Please open the \"Synlen\" folder under the \"On My iPhone/iPad\" section in the Files app to access your data.';

  @override
  String get unsavedChangesTitle => 'Unsaved Changes';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. What would you like to do?';

  @override
  String get discard => 'Discard';

  @override
  String get titleRequired => 'Title cannot be empty';

  @override
  String get readerTypographyLayout => 'Typography & Layout';

  @override
  String get readerScale => 'Scale';

  @override
  String get readerMargins => 'Margins';

  @override
  String get readerMarginTop => 'Top';

  @override
  String get readerMarginBottom => 'Bottom';

  @override
  String get readerMarginLeft => 'Left';

  @override
  String get readerMarginRight => 'Right';

  @override
  String get readerAppearance => 'Appearance';

  @override
  String get readerFollowAppTheme => 'Follow App Theme';

  @override
  String get readerLinkHandlingSection => 'Link Handling';

  @override
  String get readerLinkHandlingAsk => 'Ask';

  @override
  String get readerLinkHandlingAlways => 'Always open';

  @override
  String get readerLinkHandlingNever => 'Never open';

  @override
  String get readerHandleIntraLink => 'Follow in-book links';

  @override
  String get readerPageAnimationSection => 'Pagination';

  @override
  String get readerPageAnimationNone => 'None';

  @override
  String get readerPageAnimationSlide => 'Slide';

  @override
  String get readerVolumeKeyTurnsPage => 'Volume Keys Turn Pages';

  @override
  String get readerFontSection => 'Custom Font';

  @override
  String get readerFontDefault => 'Book Default';

  @override
  String get readerOverrideFontFamily => 'Override Book Font';

  @override
  String get readerFontManageTip => 'Manage custom fonts in Settings.';

  @override
  String get fontManagement => 'Font Management';

  @override
  String get fontManagementSubtitle => 'Custom fonts (.ttf / .otf)';

  @override
  String get importFont => 'Import Font';

  @override
  String importFontSuccess(String name) {
    return 'Font \"$name\" imported';
  }

  @override
  String importFontsSuccess(int count) {
    return '$count fonts imported';
  }

  @override
  String importFontFailed(String error) {
    return 'Failed to import font: $error';
  }

  @override
  String get deleteFontConfirm => 'Remove font';

  @override
  String deleteFontConfirmText(String name) {
    return 'Are you sure you want to remove the font \"$name\"? This will not delete the original font file, only remove it from the app.';
  }

  @override
  String get noFontsHint => 'No custom fonts yet';

  @override
  String cannotOpenLink(String url) {
    return 'Cannot open this link: $url';
  }

  @override
  String get openExternalLink => 'Open External Link';

  @override
  String openExternalLinkConfirmation(String url) {
    return 'This link will be opened in your browser: $url\n\nDo you want to proceed?';
  }

  @override
  String get open => 'Open';

  @override
  String get chapterNotFoundInSpine => 'Chapter not found in book spine';

  @override
  String get sentenceAnalysis => 'Sentence Analysis';

  @override
  String get playPronunciation => 'Play pronunciation';

  @override
  String get definitionUpdateFailed => 'Failed to update definition';

  @override
  String get wordExplanationLoading => 'Thinking...';

  @override
  String get playAudio => 'Play audio';

  @override
  String get readSentenceAloud => 'Read sentence aloud';

  @override
  String get analysisUpdateFailed => 'Failed to update analysis';

  @override
  String get sentenceAnalyzing => 'Analyzing...';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String audioUnavailable(String error) {
    return 'Audio unavailable: $error';
  }

  @override
  String get aliyunDashScopeName => 'Aliyun DashScope';

  @override
  String get learningErrorNoDeepSeekApiKey =>
      'DeepSeek API key not configured. Please set it in Settings → AI Service';

  @override
  String get learningErrorNoAliyunTtsApiKey =>
      'Aliyun TTS API key not configured. Please set it in Settings → AI Service';

  @override
  String get learningErrorServiceUnavailable =>
      'AI service is temporarily unavailable';

  @override
  String get learningErrorEmptyResult => 'The service returned no content';

  @override
  String get learningErrorRequestFailed =>
      'Request failed. Please try again later';

  @override
  String get learningErrorAudioFileMissing => 'Audio file not found';

  @override
  String get learningErrorUnsupportedFormat =>
      'Only 16-bit PCM audio is supported';

  @override
  String get learningErrorNoPlayableAudio => 'No playable audio available';

  @override
  String get backupShareTitle => 'Synlen Backup';

  @override
  String get apiKeyLoadFailed => 'Could not read saved API keys. Please retry.';

  @override
  String get apiKeySaveFailed => 'Could not save the API key. Please retry.';

  @override
  String get retry => 'Retry';

  @override
  String get readingProgressSaveFailed =>
      'Could not save your reading position. Please retry.';

  @override
  String get restoreIncomplete =>
      'Restore incomplete. Check the backup and retry.';

  @override
  String get restoreSourceHint =>
      'Choose a .zip backup file, or restore from a backup folder exported by an older version.';

  @override
  String get restoreSourceFile => 'Backup file (.zip)';

  @override
  String get restoreSourceFolder => 'Backup folder (legacy)';

  @override
  String get originalSentence => 'Original sentence';

  @override
  String get aiServicePrivacyNote =>
      'Tapping a word or long-pressing a sentence sends that text to third-party services (dictionary, DeepSeek, Aliyun TTS) to fetch learning content. No network requests are made until you configure keys.';

  @override
  String get deepSeekCheckConnectivity => 'Check DeepSeek connectivity';

  @override
  String get deepSeekCheckOk => 'DeepSeek connected successfully';

  @override
  String get deepSeekCheckBadKey => 'DeepSeek key is invalid or expired';

  @override
  String get deepSeekCheckFailed => 'Cannot reach DeepSeek. Check your network';
}
