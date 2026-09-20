import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Synlen'**
  String get appName;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Import book action
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Chapter label
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapter;

  /// Page label
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// Progress label
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// AI reading settings section title
  ///
  /// In en, this message translates to:
  /// **'AI Reading'**
  String get aiReading;

  /// TTS voice setting title
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get ttsVoice;

  /// TTS voice picker title
  ///
  /// In en, this message translates to:
  /// **'Choose Voice'**
  String get ttsVoicePickerTitle;

  /// TTS voice picker helper text
  ///
  /// In en, this message translates to:
  /// **'New voice selections apply to newly generated reading audio.'**
  String get ttsVoicePickerSubtitle;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Sort by label
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// Title sort option
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Recently added sort option
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// Recently read sort option
  ///
  /// In en, this message translates to:
  /// **'Recently Read'**
  String get recentlyRead;

  /// Error label
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Success label
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Failed label
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Loading label
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// Back button label
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous button label
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// All books tab label
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Uncategorized books tab label
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// Select all button label
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// Sort button tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Edit category dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// Category name input label
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// Sort books bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Sort Books by'**
  String get sortBooksBy;

  /// Sort by title ascending
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get titleAZ;

  /// Sort by title descending
  ///
  /// In en, this message translates to:
  /// **'Title (Z-A)'**
  String get titleZA;

  /// Sort by author ascending
  ///
  /// In en, this message translates to:
  /// **'Author (A-Z)'**
  String get authorAZ;

  /// Sort by author descending
  ///
  /// In en, this message translates to:
  /// **'Author (Z-A)'**
  String get authorZA;

  /// Sort by reading progress
  ///
  /// In en, this message translates to:
  /// **'Reading Progress'**
  String get readingProgress;

  /// Empty category message
  ///
  /// In en, this message translates to:
  /// **'No items in this Category'**
  String get noItemsInCategory;

  /// Selection count label
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected(int count);

  /// Move button label
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// Deleted badge label
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// Move to dialog title
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get moveTo;

  /// Create new category option
  ///
  /// In en, this message translates to:
  /// **'Create New Category'**
  String get createNewCategory;

  /// New category dialog title
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Delete books dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Books'**
  String get deleteBooks;

  /// Delete books confirmation message
  ///
  /// In en, this message translates to:
  /// **'Delete selected books permanently?'**
  String get deleteBooksConfirm;

  /// Successfully moved message
  ///
  /// In en, this message translates to:
  /// **'Moved to \"{name}\"'**
  String movedTo(String name);

  /// Failed to move error message
  ///
  /// In en, this message translates to:
  /// **'Failed to move items'**
  String get failedToMove;

  /// Failed to delete error message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedToDelete;

  /// Importing progress message
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get importing;

  /// Import completed message
  ///
  /// In en, this message translates to:
  /// **'Import completed'**
  String get importCompleted;

  /// Importing progress details
  ///
  /// In en, this message translates to:
  /// **'{success} success, {failed} failed, {remaining} remaining'**
  String importingProgress(int success, int failed, int remaining);

  /// Generic import failure message (typed errors carry no user-facing detail)
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please try again.'**
  String get importFailed;

  /// Import rejected because the EPUB is DRM-encrypted
  ///
  /// In en, this message translates to:
  /// **'This book is protected by DRM and cannot be imported.'**
  String get importFailedDrm;

  /// 导入时无法读取所选文件（I/O 或哈希计算失败）的提示
  ///
  /// In en, this message translates to:
  /// **'Cannot read the selected file.'**
  String get importFileUnreadable;

  /// 书籍文件解析失败（结构损坏或格式不受支持）的提示
  ///
  /// In en, this message translates to:
  /// **'Cannot parse this book file; it may be corrupted or in an unsupported format.'**
  String get importParseFailed;

  /// 重复导入同一本书时的提示
  ///
  /// In en, this message translates to:
  /// **'This book is already in your library.'**
  String get importDuplicateBook;

  /// 书籍文件写入设备存储失败的提示
  ///
  /// In en, this message translates to:
  /// **'Failed to save the book file to device storage.'**
  String get importFileWriteFailed;

  /// 书籍元数据写库失败的提示
  ///
  /// In en, this message translates to:
  /// **'Failed to save the book to the library.'**
  String get importSaveFailed;

  /// Details button label
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Error loading library message
  ///
  /// In en, this message translates to:
  /// **'Error loading library: {error}'**
  String errorLoadingLibrary(String error);

  /// Book not found error message
  ///
  /// In en, this message translates to:
  /// **'Book not found'**
  String get bookNotFound;

  /// Reading progress percentage
  ///
  /// In en, this message translates to:
  /// **'Progress: {percent}%'**
  String progressPercent(String percent);

  /// Book not started reading status
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// Number of chapters
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String chaptersCount(int count);

  /// TXT 格式书籍的格式标签
  ///
  /// In en, this message translates to:
  /// **'TXT'**
  String get bookFormatTxt;

  /// EPUB version label
  ///
  /// In en, this message translates to:
  /// **'EPUB {version}'**
  String epubVersion(String version);

  /// Continue reading button label
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get continueReading;

  /// Start reading button label
  ///
  /// In en, this message translates to:
  /// **'Start Reading'**
  String get startReading;

  /// Collapse button label
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// Expand all button label
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// Error loading book message
  ///
  /// In en, this message translates to:
  /// **'Error loading book: {error}'**
  String errorLoadingBook(String error);

  /// First chapter notification
  ///
  /// In en, this message translates to:
  /// **'This is the first chapter of the book'**
  String get firstChapterOfBook;

  /// Last chapter notification
  ///
  /// In en, this message translates to:
  /// **'This is the last chapter of the book'**
  String get lastChapterOfBook;

  /// Last page notification
  ///
  /// In en, this message translates to:
  /// **'This is the last page of the book'**
  String get lastPageOfBook;

  /// First page notification
  ///
  /// In en, this message translates to:
  /// **'This is the first page of the book'**
  String get firstPageOfBook;

  /// Empty chapter notification
  ///
  /// In en, this message translates to:
  /// **'This chapter has no content'**
  String get chapterHasNoContent;

  /// Never synced status
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// Failed to create category message
  ///
  /// In en, this message translates to:
  /// **'Failed to create category!'**
  String get failedToCreateCategory;

  /// Category name empty validation message
  ///
  /// In en, this message translates to:
  /// **'Category name cannot be empty'**
  String get categoryNameCannotBeEmpty;

  /// Category created success message
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" created'**
  String categoryCreated(String name);

  /// Category deleted success message
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" deleted'**
  String categoryDeleted(String name);

  /// Failed to delete category message
  ///
  /// In en, this message translates to:
  /// **'Failed to delete category!'**
  String get failedToDeleteCategory;

  /// About page title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Storage section title on About page
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Clean cache button label
  ///
  /// In en, this message translates to:
  /// **'Clean Cache'**
  String get cleanCache;

  /// Clean cache subtitle
  ///
  /// In en, this message translates to:
  /// **'Remove orphan files and clear the rebuildable learning cache (explanations and audio)'**
  String get cleanCacheSubtitle;

  /// Clean cache success message
  ///
  /// In en, this message translates to:
  /// **'Cache cleaned. Removed {count} unused {count, plural, =1{file} other{files}}.'**
  String cleanCacheSuccessWithCount(int count);

  /// Clean cache success message when no files were removed
  ///
  /// In en, this message translates to:
  /// **'Cache cleaned'**
  String get cleanCacheSuccess;

  /// 缓存清理失败提示
  ///
  /// In en, this message translates to:
  /// **'Cache cleanup could not finish. Please try again.'**
  String get cleanCacheFailed;

  /// Appearance section title in about screen
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appAppearance;

  /// Label for the app-wide theme mode selector
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get appThemeMode;

  /// Theme mode option: follow system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appThemeModeSystem;

  /// Theme mode option: always light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appThemeModeLight;

  /// Theme mode option: always dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appThemeModeDark;

  /// Label for the theme variant selector
  ///
  /// In en, this message translates to:
  /// **'Theme Variant'**
  String get appThemeVariant;

  /// AI service settings section title
  ///
  /// In en, this message translates to:
  /// **'AI Service'**
  String get aiService;

  /// DeepSeek API Key setting title
  ///
  /// In en, this message translates to:
  /// **'DeepSeek API Key'**
  String get deepSeekApiKey;

  /// DeepSeek API Key setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Used for word explanation and sentence analysis'**
  String get deepSeekApiKeySubtitle;

  /// Aliyun TTS API Key setting title
  ///
  /// In en, this message translates to:
  /// **'Aliyun TTS API Key'**
  String get aliyunTtsApiKey;

  /// Aliyun TTS API Key setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Used for read-aloud (Aliyun Model Studio, Beijing region endpoint only)'**
  String get aliyunTtsApiKeySubtitle;

  /// API key not configured status
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get apiKeyNotConfigured;

  /// API key input hint
  ///
  /// In en, this message translates to:
  /// **'Paste API key'**
  String get apiKeyInputHint;

  /// Hint for obtaining an API key
  ///
  /// In en, this message translates to:
  /// **'Create an API key in the {provider} console'**
  String apiKeyObtainHint(String provider);

  /// API key saved toast
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get apiKeySaved;

  /// API key cleared toast
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get apiKeyCleared;

  /// Clear API key button
  ///
  /// In en, this message translates to:
  /// **'Clear key'**
  String get clearKey;

  /// Project information section title
  ///
  /// In en, this message translates to:
  /// **'Project Info'**
  String get projectInfo;

  /// GitHub label
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get github;

  /// Author label
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// Open source licenses label
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicenses;

  /// Open source licenses subtitle
  ///
  /// In en, this message translates to:
  /// **'View open source libraries used in the app and their licenses'**
  String get openSourceLicensesSubtitle;

  /// Check for updates label
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// Check for updates subtitle
  ///
  /// In en, this message translates to:
  /// **'Check if a new version is available'**
  String get checkForUpdatesSubtitle;

  /// Up to date message
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get upToDate;

  /// New version available message
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// Update via Lanzou cloud button label
  ///
  /// In en, this message translates to:
  /// **'Download via Lanzou'**
  String get updateViaChinaCloud;

  /// Update via GitHub button label
  ///
  /// In en, this message translates to:
  /// **'Download via GitHub'**
  String get updateViaGithub;

  /// Password copied toast message
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get passwordCopied;

  /// Failed to check for updates toast
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates'**
  String get updateCheckFailed;

  /// Download and install update button
  ///
  /// In en, this message translates to:
  /// **'Download & install'**
  String get downloadAndInstall;

  /// Go to App Store update button
  ///
  /// In en, this message translates to:
  /// **'Go to App Store'**
  String get goToAppStore;

  /// Download failed toast
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// Download completed message
  ///
  /// In en, this message translates to:
  /// **'Download complete, tap to install'**
  String get downloadCompleted;

  /// Unknown sources permission message
  ///
  /// In en, this message translates to:
  /// **'Installing apps from unknown sources must be enabled in system settings'**
  String get installUnknownSourcesRequired;

  /// No update channel message
  ///
  /// In en, this message translates to:
  /// **'No update channel available for this platform yet, please check GitHub Releases'**
  String get noUpdateChannel;

  /// 非 HTTPS 更新直链被拦截的提示
  ///
  /// In en, this message translates to:
  /// **'The update download link is insecure (HTTPS required); download cancelled'**
  String get updateInsecureUrl;

  /// APK 摘要与版本清单不一致的提示
  ///
  /// In en, this message translates to:
  /// **'Update package failed integrity check; please try again or download from GitHub'**
  String get updateChecksumMismatch;

  /// 备份 ZIP 未通过解压前校验的提示
  ///
  /// In en, this message translates to:
  /// **'Backup file is corrupt or too large; restore cancelled'**
  String get backupInvalidArchive;

  /// 备份数据损坏或结构不一致（JSON 解析失败、书架与清单标识不符）的提示
  ///
  /// In en, this message translates to:
  /// **'Backup data is corrupted or incomplete; restore cancelled.'**
  String get backupDataCorrupted;

  /// 备份格式版本高于当前应用支持版本时的提示
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of the app. Please update the app and try again.'**
  String get backupVersionTooNew;

  /// The name of the current language in English, used to select the matching section in update logs
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameInEnglish;

  /// Tips section title
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// Tip for long pressing tab to edit category
  ///
  /// In en, this message translates to:
  /// **'Long press on tab to edit category'**
  String get tipLongPressTab;

  /// Tip for long pressing previous/next button
  ///
  /// In en, this message translates to:
  /// **'Long press previous/next button to jump to previous/next chapter'**
  String get tipLongPressNextTrack;

  /// Tip for long pressing image to view original
  ///
  /// In en, this message translates to:
  /// **'Long press on image to view original'**
  String get longPressToViewImage;

  /// Import from folder option label
  ///
  /// In en, this message translates to:
  /// **'Scan Folder'**
  String get importFromFolder;

  /// Import files option label
  ///
  /// In en, this message translates to:
  /// **'Import Files'**
  String get importFiles;

  /// Backup shared success message
  ///
  /// In en, this message translates to:
  /// **'Backup successfully shared'**
  String get backupShared;

  /// Backup export failed message
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {message}'**
  String exportFailed(String message);

  /// Importing progress message with file name
  ///
  /// In en, this message translates to:
  /// **'Processing {fileName}'**
  String progressing(String fileName);

  /// All files processed message
  ///
  /// In en, this message translates to:
  /// **'All Processed'**
  String get progressedAll;

  /// Restore from backup option label
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get restoreFromBackup;

  /// Backup library option label
  ///
  /// In en, this message translates to:
  /// **'Backup Library'**
  String get backupLibrary;

  /// Library section title
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// Backup library feature description
  ///
  /// In en, this message translates to:
  /// **'Export your library as a single backup file via the system share sheet'**
  String get backupLibraryDescription;

  /// Title shown when restore finishes
  ///
  /// In en, this message translates to:
  /// **'Restore Completed'**
  String get restoreCompleted;

  /// Generic restore failure message (typed errors carry no user-facing detail)
  ///
  /// In en, this message translates to:
  /// **'Failed to restore the backup. Please try again.'**
  String get restoreFailed;

  /// Restoring progress message
  ///
  /// In en, this message translates to:
  /// **'Restoring'**
  String get restoring;

  /// Restoring progress details
  ///
  /// In en, this message translates to:
  /// **'{success} success, {failed} failed, {remaining} remaining'**
  String restoringProgress(int success, int failed, int remaining);

  /// View mode section title in the style bottom sheet
  ///
  /// In en, this message translates to:
  /// **'View Mode'**
  String get viewMode;

  /// Compact view mode option
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get viewModeCompact;

  /// Relaxed view mode option
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get viewModeRelaxed;

  /// Spliter used to separate multiple values in a single string
  ///
  /// In en, this message translates to:
  /// **', '**
  String get spliter;

  /// Share source file action label
  ///
  /// In en, this message translates to:
  /// **'Share book'**
  String get shareBook;

  /// Error message when sharing a book fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share book: {error}'**
  String shareBookFailed(String error);

  /// Edit book dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Book'**
  String get editBook;

  /// Authors field label
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get authors;

  /// Book description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get bookDescription;

  /// Book saved success message
  ///
  /// In en, this message translates to:
  /// **'Book updated'**
  String get bookSaved;

  /// Book save failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String bookSaveFailed(String error);

  /// Tooltip for authors field
  ///
  /// In en, this message translates to:
  /// **'Separate multiple authors with commas'**
  String get authorsTooltip;

  /// Open storage location action label
  ///
  /// In en, this message translates to:
  /// **'Open Storage Location'**
  String get openStorageLocation;

  /// Subtitle for open storage location action
  ///
  /// In en, this message translates to:
  /// **'Open the folder where Synlen stores its data (cache, books, etc.)'**
  String get openStorageLocationSubtitle;

  /// Error message when opening storage location fails
  ///
  /// In en, this message translates to:
  /// **'Failed to open storage location: {error}'**
  String openStorageLocationFailed(String error);

  /// Message shown on iOS when user tries to open storage location, since it's not possible to open it directly
  ///
  /// In en, this message translates to:
  /// **'Please open the \"Synlen\" folder under the \"On My iPhone/iPad\" section in the Files app to access your data.'**
  String get openStorageLocationIOSMessage;

  /// Title of the dialog shown when the user tries to leave edit mode with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChangesTitle;

  /// Body of the dialog shown when the user tries to leave edit mode with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. What would you like to do?'**
  String get unsavedChangesMessage;

  /// Discard button label — discards unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Validation error shown below the title field when the user tries to save with an empty title
  ///
  /// In en, this message translates to:
  /// **'Title cannot be empty'**
  String get titleRequired;

  /// Reader style sheet section title for typography and layout
  ///
  /// In en, this message translates to:
  /// **'Typography & Layout'**
  String get readerTypographyLayout;

  /// Reader scale / zoom sub-label
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get readerScale;

  /// Reader margins sub-label
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get readerMargins;

  /// Top margin stepper label
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get readerMarginTop;

  /// Bottom margin stepper label
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get readerMarginBottom;

  /// Left margin stepper label
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get readerMarginLeft;

  /// Right margin stepper label
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get readerMarginRight;

  /// Reader style sheet section title for appearance
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get readerAppearance;

  /// Toggle label to make the reader follow the app-wide color scheme
  ///
  /// In en, this message translates to:
  /// **'Follow App Theme'**
  String get readerFollowAppTheme;

  /// Reader style sheet section title for link handling
  ///
  /// In en, this message translates to:
  /// **'Link Handling'**
  String get readerLinkHandlingSection;

  /// Link handling option: ask before opening
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get readerLinkHandlingAsk;

  /// Link handling option: always open without asking
  ///
  /// In en, this message translates to:
  /// **'Always open'**
  String get readerLinkHandlingAlways;

  /// Link handling option: never open external links
  ///
  /// In en, this message translates to:
  /// **'Never open'**
  String get readerLinkHandlingNever;

  /// Switch label to enable/disable following intra-book (book://) links
  ///
  /// In en, this message translates to:
  /// **'Follow in-book links'**
  String get readerHandleIntraLink;

  /// Reader style sheet section title for page-turning animation
  ///
  /// In en, this message translates to:
  /// **'Pagination'**
  String get readerPageAnimationSection;

  /// Page animation option: no animation
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get readerPageAnimationNone;

  /// Page animation option: slide/swipe transition
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get readerPageAnimationSlide;

  /// Toggle label to use hardware volume keys for page turning
  ///
  /// In en, this message translates to:
  /// **'Volume Keys Turn Pages'**
  String get readerVolumeKeyTurnsPage;

  /// Reader style sheet subsection label for custom font settings
  ///
  /// In en, this message translates to:
  /// **'Custom Font'**
  String get readerFontSection;

  /// Font picker option meaning use the epub's own font
  ///
  /// In en, this message translates to:
  /// **'Book Default'**
  String get readerFontDefault;

  /// Switch label to force the selected custom font over the epub's own font
  ///
  /// In en, this message translates to:
  /// **'Override Book Font'**
  String get readerOverrideFontFamily;

  /// Tip shown in the reader font subsection directing users to the settings screen
  ///
  /// In en, this message translates to:
  /// **'Manage custom fonts in Settings.'**
  String get readerFontManageTip;

  /// Title of the font management screen
  ///
  /// In en, this message translates to:
  /// **'Font Management'**
  String get fontManagement;

  /// Subtitle shown on the font management settings tile
  ///
  /// In en, this message translates to:
  /// **'Custom fonts (.ttf / .otf)'**
  String get fontManagementSubtitle;

  /// Button label to import a font file
  ///
  /// In en, this message translates to:
  /// **'Import Font'**
  String get importFont;

  /// Toast shown after successfully importing a single font
  ///
  /// In en, this message translates to:
  /// **'Font \"{name}\" imported'**
  String importFontSuccess(String name);

  /// Toast shown after importing multiple fonts at once
  ///
  /// In en, this message translates to:
  /// **'{count} fonts imported'**
  String importFontsSuccess(int count);

  /// Toast shown when font import fails
  ///
  /// In en, this message translates to:
  /// **'Failed to import font: {error}'**
  String importFontFailed(String error);

  /// Confirmation dialog title for deleting a font
  ///
  /// In en, this message translates to:
  /// **'Remove font'**
  String get deleteFontConfirm;

  /// Confirmation dialog message for deleting a font
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove the font \"{name}\"? This will not delete the original font file, only remove it from the app.'**
  String deleteFontConfirmText(String name);

  /// Placeholder text shown on the font management screen when no fonts exist
  ///
  /// In en, this message translates to:
  /// **'No custom fonts yet'**
  String get noFontsHint;

  /// Error message shown when the user tries to open a link that cannot be handled by the system
  ///
  /// In en, this message translates to:
  /// **'Cannot open this link: {url}'**
  String cannotOpenLink(String url);

  /// Label for the action to open a link in the system browser
  ///
  /// In en, this message translates to:
  /// **'Open External Link'**
  String get openExternalLink;

  /// Confirmation message shown before opening an external link
  ///
  /// In en, this message translates to:
  /// **'This link will be opened in your browser: {url}\n\nDo you want to proceed?'**
  String openExternalLinkConfirmation(String url);

  /// Open button label for opening external links
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Error message shown when trying to navigate to a chapter that doesn't exist in the book spine
  ///
  /// In en, this message translates to:
  /// **'Chapter not found in book spine'**
  String get chapterNotFoundInSpine;

  /// Title of the sentence analysis dialog
  ///
  /// In en, this message translates to:
  /// **'Sentence Analysis'**
  String get sentenceAnalysis;

  /// Tooltip and label of the word pronunciation play button
  ///
  /// In en, this message translates to:
  /// **'Play pronunciation'**
  String get playPronunciation;

  /// Prefix of the error message when the word definition update fails (followed by a colon and the error detail)
  ///
  /// In en, this message translates to:
  /// **'Failed to update definition'**
  String get definitionUpdateFailed;

  /// Loading hint shown while the word explanation is being fetched
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get wordExplanationLoading;

  /// Tooltip of the sentence audio play button
  ///
  /// In en, this message translates to:
  /// **'Play audio'**
  String get playAudio;

  /// Label of the sentence read-aloud button
  ///
  /// In en, this message translates to:
  /// **'Read sentence aloud'**
  String get readSentenceAloud;

  /// Prefix of the error message when the sentence analysis update fails (followed by a colon and the error detail)
  ///
  /// In en, this message translates to:
  /// **'Failed to update analysis'**
  String get analysisUpdateFailed;

  /// Loading hint shown while the sentence analysis is being fetched
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get sentenceAnalyzing;

  /// Error shown when the learning dialog fails to load, {error} is the error detail
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadFailed(String error);

  /// Error shown when audio is unavailable in the learning dialog, {error} is the error detail
  ///
  /// In en, this message translates to:
  /// **'Audio unavailable: {error}'**
  String audioUnavailable(String error);

  /// Name of the Aliyun DashScope service shown in the API key edit dialog in settings
  ///
  /// In en, this message translates to:
  /// **'Aliyun DashScope'**
  String get aliyunDashScopeName;

  /// Learning error message shown when the DeepSeek API key is not configured
  ///
  /// In en, this message translates to:
  /// **'DeepSeek API key not configured. Please set it in Settings → AI Service'**
  String get learningErrorNoDeepSeekApiKey;

  /// Learning error message shown when the Aliyun TTS API key is not configured
  ///
  /// In en, this message translates to:
  /// **'Aliyun TTS API key not configured. Please set it in Settings → AI Service'**
  String get learningErrorNoAliyunTtsApiKey;

  /// Learning error message shown when the AI service is temporarily unavailable
  ///
  /// In en, this message translates to:
  /// **'AI service is temporarily unavailable'**
  String get learningErrorServiceUnavailable;

  /// Learning error message shown when the service returns no content
  ///
  /// In en, this message translates to:
  /// **'The service returned no content'**
  String get learningErrorEmptyResult;

  /// Generic fallback learning error message shown when a request fails
  ///
  /// In en, this message translates to:
  /// **'Request failed. Please try again later'**
  String get learningErrorRequestFailed;

  /// Learning error message shown when the audio file is missing
  ///
  /// In en, this message translates to:
  /// **'Audio file not found'**
  String get learningErrorAudioFileMissing;

  /// Learning error message shown for an unsupported audio format
  ///
  /// In en, this message translates to:
  /// **'Only 16-bit PCM audio is supported'**
  String get learningErrorUnsupportedFormat;

  /// Learning error message shown when no playable audio is available
  ///
  /// In en, this message translates to:
  /// **'No playable audio available'**
  String get learningErrorNoPlayableAudio;

  /// Title of the backup folder shown in the iOS share sheet
  ///
  /// In en, this message translates to:
  /// **'Synlen Backup'**
  String get backupShareTitle;

  /// No description provided for @apiKeyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read saved API keys. Please retry.'**
  String get apiKeyLoadFailed;

  /// No description provided for @apiKeySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the API key. Please retry.'**
  String get apiKeySaveFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @readingProgressSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your reading position. Please retry.'**
  String get readingProgressSaveFailed;

  /// No description provided for @restoreIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Restore incomplete. Check the backup and retry.'**
  String get restoreIncomplete;

  /// Restore backup source chooser hint
  ///
  /// In en, this message translates to:
  /// **'Choose a .zip backup file, or restore from a backup folder exported by an older version.'**
  String get restoreSourceHint;

  /// Choose ZIP backup file option
  ///
  /// In en, this message translates to:
  /// **'Backup file (.zip)'**
  String get restoreSourceFile;

  /// Choose legacy backup folder option
  ///
  /// In en, this message translates to:
  /// **'Backup folder (legacy)'**
  String get restoreSourceFolder;

  /// 句子分析弹窗中的原句标签
  ///
  /// In en, this message translates to:
  /// **'Original sentence'**
  String get originalSentence;

  /// No description provided for @aiServicePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Tapping a word or long-pressing a sentence sends that text to third-party services (dictionary, DeepSeek, Aliyun TTS) to fetch learning content. No network requests are made until you configure keys.'**
  String get aiServicePrivacyNote;

  /// No description provided for @deepSeekCheckConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Check DeepSeek connectivity'**
  String get deepSeekCheckConnectivity;

  /// No description provided for @deepSeekCheckOk.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek connected successfully'**
  String get deepSeekCheckOk;

  /// No description provided for @deepSeekCheckBadKey.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek key is invalid or expired'**
  String get deepSeekCheckBadKey;

  /// No description provided for @deepSeekCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach DeepSeek. Check your network'**
  String get deepSeekCheckFailed;

  /// No description provided for @readerLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this book. Please try again.'**
  String get readerLoadFailed;

  /// No description provided for @readerRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the reading layout. Please try again.'**
  String get readerRenderFailed;

  /// No description provided for @wordTabExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get wordTabExplanation;

  /// No description provided for @wordTabSynonyms.
  ///
  /// In en, this message translates to:
  /// **'Synonyms'**
  String get wordTabSynonyms;

  /// No description provided for @wordTabFormation.
  ///
  /// In en, this message translates to:
  /// **'Formation'**
  String get wordTabFormation;

  /// No description provided for @wordNoSynonyms.
  ///
  /// In en, this message translates to:
  /// **'No suitable synonyms in this context.'**
  String get wordNoSynonyms;

  /// No description provided for @wordNoFormation.
  ///
  /// In en, this message translates to:
  /// **'No reliable word formation information.'**
  String get wordNoFormation;

  /// No description provided for @wordSectionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This section could not be loaded.'**
  String get wordSectionUnavailable;

  /// 朗读被点击词形的按钮提示
  ///
  /// In en, this message translates to:
  /// **'Pronounce “{word}”'**
  String pronounceWord(String word);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
