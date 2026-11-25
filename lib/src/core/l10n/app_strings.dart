import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/workspace/workspace_service.dart';

/// Every key both locales must provide, in the order screens use them.
///
/// `test/core/app_strings_test.dart` asserts [AppStringsEn.values] and
/// [AppStringsAr.values] contain exactly this set, so a key added to one
/// language cannot silently disappear from the other.
const List<String> appStringKeys = <String>[
  'search.title',
  'search.subtitle',
  'search.queryLabel',
  'search.fromLabel',
  'search.toLabel',
  'search.typeLabel',
  'search.anyType',
  'search.clearFilters',
  'search.emptyTitle',
  'search.emptyWithFilters',
  'search.emptyNoQuery',
  'search.failed',
  'search.loading',
  'search.source',
  'search.unknownDate',
  'timeline.title',
  'timeline.subtitle',
  'timeline.day',
  'timeline.month',
  'timeline.fromLabel',
  'timeline.toLabel',
  'timeline.typeLabel',
  'timeline.anyType',
  'timeline.clearFilters',
  'timeline.unknownDate',
  'timeline.unknownHint',
  'timeline.missingTimestamp',
  'timeline.empty',
  'timeline.failed',
  'timeline.loading',
  'timeline.events',
  'timeline.eventSingular',
  'overview.title',
  'overview.subtitle',
  'overview.period',
  'overview.eventTypes',
  'overview.days',
  'overview.conversations',
  'overview.people',
  'overview.files',
  'overview.empty',
  'overview.failed',
  'overview.drillEmpty',
  'overview.source',
  'overview.unknownDate',
  'overview.openRecords',
  'settings.title',
  'settings.subtitle',
  'settings.workspacePath',
  'settings.workspaceSize',
  'settings.remove',
  'settings.removeBody',
  'settings.removeHint',
  'settings.removeButton',
  'settings.confirmTitle',
  'settings.confirmBody',
  'settings.confirmLabel',
  'settings.cancel',
  'settings.consents',
  'settings.consentsEmpty',
  'settings.deleted',
  'settings.deletedBody',
  'settings.failed',
  'settings.loading',
  'settings.language',
  'settings.languageHint',
  'settings.languageSystem',
  'settings.languageEnglish',
  'settings.languageArabic',
  'brand.name',
  'brand.tagline',
  'import.chooseFolder',
  'import.chooseZip',
  'import.chooseChat',
  'import.folderDialogTitle',
  'import.zipDialogTitle',
  'import.folderFailed',
  'import.importErrorTitle',
  'import.errorArchiveEmpty',
  'import.errorArchiveSizeLimit',
  'import.errorFolderUnreadable',
  'import.errorEntryCountLimit',
  'import.errorEntrySizeLimit',
  'import.errorJsonFileSizeLimit',
  'import.errorJsonPayloadSizeLimit',
  'import.errorExpandedSizeLimit',
  'import.errorInvalidEntryPath',
  'import.errorAbsoluteEntryPath',
  'import.errorPathTraversal',
  'import.errorDuplicateEntry',
  'import.errorSymbolicLinkRejected',
  'import.errorInvalidJsonPathFilter',
  'import.errorArchiveCorrupt',
  'import.errorArchiveChanged',
  'import.errorRecordCountLimit',
  'import.errorImportWriteFailed',
  'import.errorMalformedMessageJson',
  'import.errorUnsupportedMessageJson',
  'import.errorMalformedCommentsJson',
  'import.errorUnsupportedCommentsJson',
  'import.errorMalformedReactionsJson',
  'import.errorUnsupportedReactionsJson',
  'import.errorMalformedPostsJson',
  'import.errorUnsupportedPostsJson',
  'import.errorUnknown',
  'import.errorNoSupportedFiles',
  'import.readsAndStoresLocally',
  'import.importNow',
  'import.cancel',
  'import.progress',
  'import.recordsWritten',
  'import.resultTitle',
  'import.events',
  'import.people',
  'import.conversations',
  'import.attachments',
  'import.skippedRecords',
  'import.reusedExisting',
  'import.warningsTitle',
  'import.warningFile',
  'import.warningField',
  'import.warningBound',
  'import.warningBoundMinimum',
  'import.warningBoundMaximum',
  'import.warningBoundWrite',
  'import.warningMore',
  'import.warningGeneric',
  'import.cancelledRolledBack',
  'import.errorNothingSaved',
  'import.errorRolledBack',
  'person.failed',
  'person.retry',
  'person.emptyTitle',
  'person.emptyBody',
  'person.heroPhotos',
  'person.openConversation',
  'person.viewProfile',
  'person.rangeMessages',
  'person.rangeYear',
  'person.rangeYears',
  'person.platformId',
  'person.platformFacebook',
  'person.platformInstagram',
  'person.platformWhatsapp',
  'person.statMessages',
  'person.statPhotos',
  'person.statFirst',
  'person.statLast',
  'person.recentTitle',
  'person.recentSubtitle',
  'person.recentBadge',
  'person.recentEmpty',
  'person.loadedCount',
  'person.loadOlder',
  'person.pageFailed',
  'person.photosTitle',
  'person.photosSubtitle',
  'person.allPhotos',
  'person.photosEmpty',
  'person.yearsTitle',
  'person.yearsSubtitle',
  'person.yearsEmpty',
  'person.yearsTotal',
  'person.yearsPeak',
  'person.nearbyTitle',
  'person.nearbyBadge',
  'person.nearbyEmpty',
  'person.nearbyRank',
  'person.nearbyNote',
  'person.archiveTitle',
  'person.archiveSubtitle',
  'person.archiveIndexType',
  'person.archiveRecords',
  'person.archiveLast',
  'person.memoryTitle',
  'person.memoryEmpty',
  'person.undated',
  'person.thisYear',
  'person.yearAgo',
  'person.yearsAgo',
  'person.shortcutsTitle',
  'person.shortcutsSubtitle',
  'person.importAction',
  'person.navMe',
  'person.navHome',
  'person.navStory',
  'person.navAnalytics',
  'person.navMessages',
  'person.navMedia',
  'person.navPeople',
  'person.navSettings',
  'person.ownershipTitle',
  'person.ownershipBody',
];

/// User-visible strings of the app, in one locale.
///
/// Values are looked up by a stable key so a test can assert that both
/// languages carry exactly [appStringKeys]; typed getters keep call sites
/// readable. Text that the app did not author (names, ids, paths, quotes) is
/// never translated.
abstract class AppStrings {
  const AppStrings();

  Locale get locale;

  TextDirection get direction;

  Map<String, String> get values;

  bool get isRtl => direction == TextDirection.rtl;

  String operator [](String key) {
    final value = values[key];
    assert(
      value != null,
      'Missing AppStrings value for "$key" in ${locale.languageCode}',
    );
    return value ?? key;
  }

  // Search.
  String get searchTitle => this['search.title'];
  String get searchSubtitle => this['search.subtitle'];
  String get searchQueryLabel => this['search.queryLabel'];
  String get searchFromLabel => this['search.fromLabel'];
  String get searchToLabel => this['search.toLabel'];
  String get searchTypeLabel => this['search.typeLabel'];
  String get searchAnyType => this['search.anyType'];
  String get searchClearFilters => this['search.clearFilters'];
  String get searchEmptyTitle => this['search.emptyTitle'];
  String get searchEmptyWithFilters => this['search.emptyWithFilters'];
  String get searchEmptyNoQuery => this['search.emptyNoQuery'];
  String get searchFailed => this['search.failed'];
  String get searchLoading => this['search.loading'];
  String get searchSource => this['search.source'];
  String get searchUnknownDate => this['search.unknownDate'];

  // Timeline.
  String get timelineTitle => this['timeline.title'];
  String get timelineSubtitle => this['timeline.subtitle'];
  String get timelineDay => this['timeline.day'];
  String get timelineMonth => this['timeline.month'];
  String get timelineFromLabel => this['timeline.fromLabel'];
  String get timelineToLabel => this['timeline.toLabel'];
  String get timelineTypeLabel => this['timeline.typeLabel'];
  String get timelineAnyType => this['timeline.anyType'];
  String get timelineClearFilters => this['timeline.clearFilters'];
  String get timelineUnknownDate => this['timeline.unknownDate'];
  String get timelineUnknownHint => this['timeline.unknownHint'];
  String get timelineMissingTimestamp => this['timeline.missingTimestamp'];
  String get timelineEmpty => this['timeline.empty'];
  String get timelineFailed => this['timeline.failed'];
  String get timelineLoading => this['timeline.loading'];
  String get timelineEvents => this['timeline.events'];
  String get timelineEventSingular => this['timeline.eventSingular'];

  // Overview.
  String get overviewTitle => this['overview.title'];
  String get overviewSubtitle => this['overview.subtitle'];
  String get overviewPeriod => this['overview.period'];
  String get overviewEventTypes => this['overview.eventTypes'];
  String get overviewDays => this['overview.days'];
  String get overviewConversations => this['overview.conversations'];
  String get overviewPeople => this['overview.people'];
  String get overviewFiles => this['overview.files'];
  String get overviewEmpty => this['overview.empty'];
  String get overviewFailed => this['overview.failed'];
  String get overviewDrillEmpty => this['overview.drillEmpty'];
  String get overviewSource => this['overview.source'];
  String get overviewUnknownDate => this['overview.unknownDate'];
  String get overviewOpenRecords => this['overview.openRecords'];

  // Settings.
  String get settingsTitle => this['settings.title'];
  String get settingsSubtitle => this['settings.subtitle'];
  String get settingsWorkspacePath => this['settings.workspacePath'];
  String get settingsWorkspaceSize => this['settings.workspaceSize'];
  String get settingsRemove => this['settings.remove'];
  String get settingsRemoveBody => this['settings.removeBody'];
  String get settingsRemoveHint => this['settings.removeHint'];
  String get settingsRemoveButton => this['settings.removeButton'];
  String get settingsConfirmTitle => this['settings.confirmTitle'];
  String get settingsConfirmBody => this['settings.confirmBody'];
  String get settingsConfirmLabel => this['settings.confirmLabel'];
  String get settingsCancel => this['settings.cancel'];
  String get settingsConsents => this['settings.consents'];
  String get settingsConsentsEmpty => this['settings.consentsEmpty'];
  String get settingsDeleted => this['settings.deleted'];
  String get settingsDeletedBody => this['settings.deletedBody'];
  String get settingsFailed => this['settings.failed'];
  String get settingsLoading => this['settings.loading'];
  String get settingsLanguage => this['settings.language'];
  String get settingsLanguageHint => this['settings.languageHint'];
  String get settingsLanguageSystem => this['settings.languageSystem'];
  String get settingsLanguageEnglish => this['settings.languageEnglish'];
  String get settingsLanguageArabic => this['settings.languageArabic'];

  // Brand. The product name is a proper noun, so it is identical in both
  // locales; only the tagline is translated.
  String get brandName => this['brand.name'];
  String get brandTagline => this['brand.tagline'];

  // Import. The folder is the recommended source, so it comes first.
  String get importChooseFolder => this['import.chooseFolder'];
  String get importChooseZip => this['import.chooseZip'];
  String get importChooseChat => this['import.chooseChat'];
  String get importFolderDialogTitle => this['import.folderDialogTitle'];
  String get importZipDialogTitle => this['import.zipDialogTitle'];
  String get importFolderFailed => this['import.folderFailed'];
  String get importErrorTitle => this['import.importErrorTitle'];
  String get importErrorNothingSaved => this['import.errorNothingSaved'];
  String get importErrorRolledBack => this['import.errorRolledBack'];
  String importErrorMessage(String code) => this['import.error$code'];
  String get importReadsAndStoresLocally =>
      this['import.readsAndStoresLocally'];
  String get importNow => this['import.importNow'];
  String get importCancel => this['import.cancel'];
  String get importProgress => this['import.progress'];
  String get importRecordsWritten => this['import.recordsWritten'];
  String get importResultTitle => this['import.resultTitle'];
  String get importEvents => this['import.events'];
  String get importPeople => this['import.people'];
  String get importConversations => this['import.conversations'];
  String get importAttachments => this['import.attachments'];
  String get importSkippedRecords => this['import.skippedRecords'];
  String get importReusedExisting => this['import.reusedExisting'];
  String get importWarningsTitle => this['import.warningsTitle'];
  String get importWarningFile => this['import.warningFile'];
  String get importWarningField => this['import.warningField'];
  String get importWarningBound => this['import.warningBound'];
  String get importWarningBoundMinimum => this['import.warningBoundMinimum'];
  String get importWarningBoundMaximum => this['import.warningBoundMaximum'];
  String get importWarningBoundWrite => this['import.warningBoundWrite'];
  String get importWarningMore => this['import.warningMore'];
  String get importWarningGeneric => this['import.warningGeneric'];
  String get importCancelledRolledBack => this['import.cancelledRolledBack'];

  // Person profile. Templates keep {count}, {year}, {id} and {from}/{to} as
  // placeholders the screen fills with numbers it read from the archive.
  String get personFailed => this['person.failed'];
  String get personRetry => this['person.retry'];
  String get personEmptyTitle => this['person.emptyTitle'];
  String get personEmptyBody => this['person.emptyBody'];
  String get personHeroPhotos => this['person.heroPhotos'];
  String get personOpenConversation => this['person.openConversation'];
  String get personViewProfile => this['person.viewProfile'];
  String get personRangeMessages => this['person.rangeMessages'];
  String get personRangeYear => this['person.rangeYear'];
  String get personRangeYears => this['person.rangeYears'];
  String get personPlatformId => this['person.platformId'];
  String get personPlatformFacebook => this['person.platformFacebook'];
  String get personPlatformInstagram => this['person.platformInstagram'];
  String get personPlatformWhatsapp => this['person.platformWhatsapp'];
  String get personStatMessages => this['person.statMessages'];
  String get personStatPhotos => this['person.statPhotos'];
  String get personStatFirst => this['person.statFirst'];
  String get personStatLast => this['person.statLast'];
  String get personRecentTitle => this['person.recentTitle'];
  String get personRecentSubtitle => this['person.recentSubtitle'];
  String get personRecentBadge => this['person.recentBadge'];
  String get personRecentEmpty => this['person.recentEmpty'];
  String get personLoadedCount => this['person.loadedCount'];
  String get personLoadOlder => this['person.loadOlder'];
  String get personPageFailed => this['person.pageFailed'];
  String get personPhotosTitle => this['person.photosTitle'];
  String get personPhotosSubtitle => this['person.photosSubtitle'];
  String get personAllPhotos => this['person.allPhotos'];
  String get personPhotosEmpty => this['person.photosEmpty'];
  String get personYearsTitle => this['person.yearsTitle'];
  String get personYearsSubtitle => this['person.yearsSubtitle'];
  String get personYearsEmpty => this['person.yearsEmpty'];
  String get personYearsTotal => this['person.yearsTotal'];
  String get personYearsPeak => this['person.yearsPeak'];
  String get personNearbyTitle => this['person.nearbyTitle'];
  String get personNearbyBadge => this['person.nearbyBadge'];
  String get personNearbyEmpty => this['person.nearbyEmpty'];
  String get personNearbyRank => this['person.nearbyRank'];
  String get personNearbyNote => this['person.nearbyNote'];
  String get personArchiveTitle => this['person.archiveTitle'];
  String get personArchiveSubtitle => this['person.archiveSubtitle'];
  String get personArchiveIndexType => this['person.archiveIndexType'];
  String get personArchiveRecords => this['person.archiveRecords'];
  String get personArchiveLast => this['person.archiveLast'];
  String get personMemoryTitle => this['person.memoryTitle'];
  String get personMemoryEmpty => this['person.memoryEmpty'];
  String get personUndated => this['person.undated'];
  String get personThisYear => this['person.thisYear'];
  String get personYearAgo => this['person.yearAgo'];
  String get personYearsAgo => this['person.yearsAgo'];
  String get personShortcutsTitle => this['person.shortcutsTitle'];
  String get personShortcutsSubtitle => this['person.shortcutsSubtitle'];
  String get personImportAction => this['person.importAction'];
  String get personNavMe => this['person.navMe'];
  String get personNavHome => this['person.navHome'];
  String get personNavStory => this['person.navStory'];
  String get personNavAnalytics => this['person.navAnalytics'];
  String get personNavMessages => this['person.navMessages'];
  String get personNavMedia => this['person.navMedia'];
  String get personNavPeople => this['person.navPeople'];
  String get personNavSettings => this['person.navSettings'];
  String get personOwnershipTitle => this['person.ownershipTitle'];
  String get personOwnershipBody => this['person.ownershipBody'];
}

/// English strings. Wording follows `docs/UI_SPEC.md` §6.
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  Locale get locale => const Locale('en');

  @override
  TextDirection get direction => TextDirection.ltr;

  @override
  Map<String, String> get values => _values;

  static const Map<String, String> _values = <String, String>{
    'search.title': 'Advanced search',
    'search.subtitle':
        'Search your imported records. Everything runs on this device.',
    'search.queryLabel': 'Search text',
    'search.fromLabel': 'From (YYYY-MM-DD)',
    'search.toLabel': 'To (YYYY-MM-DD)',
    'search.typeLabel': 'Event type',
    'search.anyType': 'Any type',
    'search.clearFilters': 'Clear filters',
    'search.emptyTitle': 'No results',
    'search.emptyWithFilters':
        'No records match this query with the active filters.',
    'search.emptyNoQuery': 'Type a word to search your imported records.',
    'search.failed': 'Search failed. Your data is unchanged.',
    'search.loading': 'Searching…',
    'search.source': 'Source',
    'search.unknownDate': 'No date',
    'timeline.title': 'Timeline',
    'timeline.subtitle':
        'Activity counts grouped in UTC. Unparsed dates stay separate.',
    'timeline.day': 'Day',
    'timeline.month': 'Month',
    'timeline.fromLabel': 'From (YYYY-MM-DD)',
    'timeline.toLabel': 'To (YYYY-MM-DD)',
    'timeline.typeLabel': 'Event type',
    'timeline.anyType': 'Any type',
    'timeline.clearFilters': 'Clear filters',
    'timeline.unknownDate': 'Unknown date',
    'timeline.unknownHint':
        'These events have no parsed timestamp; they are not placed on the '
        'timeline.',
    'timeline.missingTimestamp': 'timestamp missing',
    'timeline.empty': 'No events match these filters.',
    'timeline.failed':
        'The timeline could not be loaded. Your data is unchanged.',
    'timeline.loading': 'Loading timeline…',
    'timeline.events': 'events',
    'timeline.eventSingular': 'event',
    'overview.title': 'Overview',
    'overview.subtitle':
        'Every number is computed locally and opens the records it counts.',
    'overview.period': 'Activity period',
    'overview.eventTypes': 'By event type',
    'overview.days': 'Daily activity',
    'overview.conversations': 'Top conversations',
    'overview.people': 'Top people',
    'overview.files': 'By source file',
    'overview.empty': 'No imported events yet.',
    'overview.failed':
        'The overview could not be loaded. Your data is unchanged.',
    'overview.drillEmpty': 'No records match this definition.',
    'overview.source': 'Source',
    'overview.unknownDate': 'No date',
    'overview.openRecords': 'Open the records behind this number',
    'settings.title': 'Privacy & settings',
    'settings.subtitle':
        'Everything lives in one local workspace. Nothing is uploaded.',
    'settings.workspacePath': 'Workspace folder',
    'settings.workspaceSize': 'Size on disk',
    'settings.remove': 'Delete workspace',
    'settings.removeBody':
        'Removes the local database and everything the app imported.',
    'settings.removeHint':
        'Deleting rows does not guarantee an SSD overwrite: '
        'some copies may remain in the drive until it reuses those cells. '
        'Treat the export archive as the source of truth.',
    'settings.removeButton': 'Delete workspace',
    'settings.confirmTitle': 'Delete workspace?',
    'settings.confirmBody': 'This cannot be undone. Type DELETE to confirm.',
    'settings.confirmLabel': 'Type DELETE',
    'settings.cancel': 'Cancel',
    'settings.consents': 'AI consent history',
    'settings.consentsEmpty': 'No AI consent has been granted.',
    'settings.deleted': 'Workspace deleted',
    'settings.deletedBody': 'Start by importing a data export.',
    'settings.failed': 'The workspace could not be deleted.',
    'settings.loading': 'Loading settings…',
    'settings.language': 'Language',
    'settings.languageHint':
        'The choice is stored with this local workspace and applies to the '
        'whole app.',
    'settings.languageSystem': 'System',
    'settings.languageEnglish': 'English',
    'settings.languageArabic': 'العربية',
    'brand.name': 'Tmewai',
    'brand.tagline': 'Tell me exactly who I am',
    'import.chooseFolder': 'Choose folder',
    'import.chooseZip': 'Or open a ZIP archive',
    'import.chooseChat': 'Choose WhatsApp chat (.txt)',
    'import.folderDialogTitle': 'Choose the export folder',
    'import.zipDialogTitle': 'Choose the export archive',
    'import.folderFailed': 'The folder could not be read. Check its permissions and choose it again.',
    'import.importErrorTitle': 'Import failed',
    'import.errorArchiveEmpty': 'The selected file is empty.',
    'import.errorArchiveSizeLimit':
        'The archive exceeds the supported size limit.',
    'import.errorFolderUnreadable':
        'A file in the selected folder could not be read.',
    'import.errorEntryCountLimit': 'The archive contains too many entries.',
    'import.errorEntrySizeLimit':
        'An archive entry exceeds the file-size limit.',
    'import.errorJsonFileSizeLimit':
        'A supported JSON file exceeds the import read limit.',
    'import.errorJsonPayloadSizeLimit':
        'Supported JSON files exceed the import read limit.',
    'import.errorExpandedSizeLimit':
        'The archive exceeds the expanded-size limit.',
    'import.errorInvalidEntryPath':
        'The archive contains an invalid file path.',
    'import.errorAbsoluteEntryPath':
        'The archive contains an absolute file path.',
    'import.errorPathTraversal': 'The archive contains an unsafe path.',
    'import.errorDuplicateEntry':
        'The archive contains duplicate or ambiguous paths.',
    'import.errorSymbolicLinkRejected':
        'Archives with symbolic links are not supported.',
    'import.errorInvalidJsonPathFilter':
        'The supported file selection pattern is invalid.',
    'import.errorArchiveCorrupt': 'An archive entry could not be read safely.',
    'import.errorArchiveChanged':
        'The archive changed while it was being read.',
    'import.errorRecordCountLimit':
        'The export contains more records than the import limit.',
    'import.errorImportWriteFailed': 'The import could not be saved.',
    'import.errorMalformedMessageJson': 'A messages file is not valid JSON.',
    'import.errorUnsupportedMessageJson':
        'A messages file has an unsupported shape.',
    'import.errorMalformedCommentsJson': 'A comments file is not valid JSON.',
    'import.errorUnsupportedCommentsJson':
        'A comments file has an unsupported shape.',
    'import.errorMalformedReactionsJson': 'A reactions file is not valid JSON.',
    'import.errorUnsupportedReactionsJson':
        'A reactions file has an unsupported shape.',
    'import.errorMalformedPostsJson': 'A posts file is not valid JSON.',
    'import.errorUnsupportedPostsJson':
        'A posts file has an unsupported shape.',
    'import.errorUnknown': 'An unexpected error occurred during import.',
    'import.errorNoSupportedFiles':
        'No supported Facebook export files were found.',
    'import.readsAndStoresLocally': 'Tmewai reads the selected folder or ZIP on this device and stores supported records in the local archive.',
    'import.importNow': 'Import now',
    'import.cancel': 'Cancel import',
    'import.progress': 'Files {done} of {total}',
    'import.recordsWritten': '{count} records written',
    'import.resultTitle': 'Import complete',
    'import.events': 'Events',
    'import.people': 'People',
    'import.conversations': 'Conversations',
    'import.attachments': 'Attachments',
    'import.skippedRecords': 'Skipped records',
    'import.reusedExisting': 'This export was already imported; the existing archive records were reused.',
    'import.warningsTitle': 'Skipped record details',
    'import.warningFile': 'File',
    'import.warningField': 'Field',
    'import.warningBound': 'Limit',
    'import.warningBoundMinimum': 'minimum required',
    'import.warningBoundMaximum': 'maximum allowed',
    'import.warningBoundWrite': 'rejected by the local database',
    'import.warningMore': 'and {count} more',
    'import.warningGeneric':
        'A record was skipped; no further details are available.',
    'import.cancelledRolledBack': 'Import cancelled. The partial import was rolled back; no records from this attempt remain.',
    'import.errorNothingSaved': 'No data from this attempt was saved.',
    'import.errorRolledBack':
        'The import failed and was rolled back; no partial records were saved.',
    'person.failed': 'The people archive could not be read on this device.',
    'person.retry': 'Try again',
    'person.emptyTitle': 'No people yet',
    'person.emptyBody':
        'Import a data export to see the people you talked with — every number '
        'is counted from your stored messages.',
    'person.heroPhotos': 'Show photos · {count}',
    'person.openConversation': 'Open the conversation',
    'person.viewProfile': 'View this person’s profile',
    'person.rangeMessages': '{count} messages with them',
    'person.rangeYear': 'in {year}',
    'person.rangeYears': 'from {from} to {to}',
    'person.platformId': 'Platform ID {id}',
    'person.platformFacebook': 'Facebook',
    'person.platformInstagram': 'Instagram',
    'person.platformWhatsapp': 'WhatsApp',
    'person.statMessages': 'Message',
    'person.statPhotos': 'Photo',
    'person.statFirst': 'First contact',
    'person.statLast': 'Last contact',
    'person.recentTitle': 'Last things they said',
    'person.recentSubtitle':
        'Conversations recovered from WhatsApp and Facebook',
    'person.recentBadge': 'Memory log',
    'person.recentEmpty': 'No stored text messages.',
    'person.loadedCount': 'Loaded {loaded} of {total}',
    'person.loadOlder': 'Load older messages',
    'person.pageFailed': 'Older messages could not be loaded.',
    'person.photosTitle': 'Photos of you together ({count} photos)',
    'person.photosSubtitle': 'Recovered moments, stored locally',
    'person.allPhotos': 'Show all photos',
    'person.photosEmpty': 'No shared photos in the archive.',
    'person.yearsTitle': 'Your numbers together',
    'person.yearsSubtitle': 'Their messages, year by year',
    'person.yearsEmpty': 'No dated messages from this person.',
    'person.yearsTotal': 'Total: {count} messages sent',
    'person.yearsPeak': 'Busiest: {year}',
    'person.nearbyTitle': 'People close to them',
    'person.nearbyBadge': 'Conversation circle',
    'person.nearbyEmpty': 'No people in the archive yet.',
    'person.nearbyRank': 'Rank {rank} by messages',
    'person.nearbyNote':
        'The ranking counts dated messages in your archive.',
    'person.archiveTitle': 'Local archive details',
    'person.archiveSubtitle':
        'Local only · 100% — nothing leaves your device, and everything is '
        'indexed on internal storage.',
    'person.archiveIndexType': 'Index type',
    'person.archiveRecords': 'Indexed records',
    'person.archiveLast': 'Newest dated record',
    'person.memoryTitle': 'A memory from your conversation',
    'person.memoryEmpty': 'No stored quote yet.',
    'person.undated': 'No date',
    'person.thisYear': 'This year · {year}',
    'person.yearAgo': 'One year ago · {year}',
    'person.yearsAgo': '{count} years ago · {year}',
    'person.shortcutsTitle': 'Shortcuts',
    'person.shortcutsSubtitle': 'Personal account archive',
    'person.importAction': 'Import new data',
    'person.navMe': 'My profile',
    'person.navHome': 'Home',
    'person.navStory': 'Your story in numbers',
    'person.navAnalytics': 'Analytics',
    'person.navMessages': 'Messages',
    'person.navMedia': 'Photos',
    'person.navPeople': 'People',
    'person.navSettings': 'Settings',
    'person.ownershipTitle': 'The archive is entirely yours',
    'person.ownershipBody':
        'Files are stored and indexed on your hard drive with no external '
        'connection. Your data is yours alone and never leaves your device.',
  };
}

/// Arabic strings. The app runs right-to-left, but ids, paths and quoted
/// source text stay as they were written.
class AppStringsAr extends AppStrings {
  const AppStringsAr();

  @override
  Locale get locale => const Locale('ar');

  @override
  TextDirection get direction => TextDirection.rtl;

  @override
  Map<String, String> get values => _values;

  static const Map<String, String> _values = <String, String>{
    'search.title': 'البحث المتقدم',
    'search.subtitle': 'ابحث في سجلاتك المستوردة. كل شيء يعمل على جهازك.',
    'search.queryLabel': 'نص البحث',
    'search.fromLabel': 'من (YYYY-MM-DD)',
    'search.toLabel': 'إلى (YYYY-MM-DD)',
    'search.typeLabel': 'نوع الحدث',
    'search.anyType': 'كل الأنواع',
    'search.clearFilters': 'مسح المرشحات',
    'search.emptyTitle': 'لا نتائج',
    'search.emptyWithFilters':
        'لا توجد سجلات تطابق هذا البحث مع المرشحات النشطة.',
    'search.emptyNoQuery': 'اكتب كلمة للبحث في سجلاتك المستوردة.',
    'search.failed': 'تعذّر البحث. بياناتك لم تتغير.',
    'search.loading': 'جارٍ البحث…',
    'search.source': 'المصدر',
    'search.unknownDate': 'بلا تاريخ',
    'timeline.title': 'الخط الزمني',
    'timeline.subtitle':
        'أعداد النشاط مجمّعة بتوقيت UTC. التواريخ غير المفهومة تبقى منفصلة.',
    'timeline.day': 'يوم',
    'timeline.month': 'شهر',
    'timeline.fromLabel': 'من (YYYY-MM-DD)',
    'timeline.toLabel': 'إلى (YYYY-MM-DD)',
    'timeline.typeLabel': 'نوع الحدث',
    'timeline.anyType': 'كل الأنواع',
    'timeline.clearFilters': 'مسح المرشحات',
    'timeline.unknownDate': 'تاريخ غير معروف',
    'timeline.unknownHint':
        'هذه الأحداث بلا طابع زمني مفهوم، ولا تُوضع على الخط الزمني.',
    'timeline.missingTimestamp': 'الطابع الزمني مفقود',
    'timeline.empty': 'لا توجد أحداث تطابق هذه المرشحات.',
    'timeline.failed': 'تعذّر تحميل الخط الزمني. بياناتك لم تتغير.',
    'timeline.loading': 'جارٍ تحميل الخط الزمني…',
    'timeline.events': 'أحداث',
    'timeline.eventSingular': 'حدث',
    'overview.title': 'نظرة عامة',
    'overview.subtitle': 'كل رقم محسوب محليًا ويفتح السجلات التي يحصيها.',
    'overview.period': 'فترة النشاط',
    'overview.eventTypes': 'حسب نوع الحدث',
    'overview.days': 'النشاط اليومي',
    'overview.conversations': 'أعلى المحادثات',
    'overview.people': 'أعلى الأشخاص',
    'overview.files': 'حسب ملف المصدر',
    'overview.empty': 'لا أحداث مستوردة بعد.',
    'overview.failed': 'تعذّر تحميل النظرة العامة. بياناتك لم تتغير.',
    'overview.drillEmpty': 'لا سجلات تطابق هذا التعريف.',
    'overview.source': 'المصدر',
    'overview.unknownDate': 'بلا تاريخ',
    'overview.openRecords': 'افتح السجلات خلف هذا الرقم',
    'settings.title': 'الخصوصية والإعدادات',
    'settings.subtitle': 'كل شيء في مساحة عمل محلية واحدة. لا يُرفع أي شيء.',
    'settings.workspacePath': 'مجلد مساحة العمل',
    'settings.workspaceSize': 'الحجم على القرص',
    'settings.remove': 'حذف مساحة العمل',
    'settings.removeBody':
        'يحذف قاعدة البيانات المحلية وكل ما استورده التطبيق.',
    'settings.removeHint':
        'حذف الصفوف لا يضمن محوها من أقراص SSD: قد تبقى '
        'نسخ في القرص حتى يعيد استخدام تلك الخلايا. اعتبر أرشيف التصدير هو '
        'المصدر.',
    'settings.removeButton': 'حذف مساحة العمل',
    'settings.confirmTitle': 'حذف مساحة العمل؟',
    'settings.confirmBody': 'لا يمكن التراجع. اكتب DELETE للتأكيد.',
    'settings.confirmLabel': 'اكتب DELETE',
    'settings.cancel': 'إلغاء',
    'settings.consents': 'سجل موافقات الذكاء الاصطناعي',
    'settings.consentsEmpty': 'لم تُمنح أي موافقة للذكاء الاصطناعي.',
    'settings.deleted': 'تم حذف مساحة العمل',
    'settings.deletedBody': 'ابدأ باستيراد نسخة بيانات.',
    'settings.failed': 'تعذّر حذف مساحة العمل.',
    'settings.loading': 'جارٍ تحميل الإعدادات…',
    'settings.language': 'اللغة',
    'settings.languageHint':
        'يُحفظ الاختيار مع مساحة العمل المحلية هذه ويطبَّق على التطبيق كله.',
    'settings.languageSystem': 'لغة النظام',
    'settings.languageEnglish': 'English',
    'settings.languageArabic': 'العربية',
    'brand.name': 'Tmewai',
    'brand.tagline': 'قل لي من أنا بالضبط',
    'import.chooseFolder': 'اختر مجلدًا',
    'import.chooseZip': 'أو افتح أرشيف ZIP',
    'import.chooseChat': 'اختر محادثة واتساب (.txt)',
    'import.folderDialogTitle': 'اختر مجلد بيانات التصدير',
    'import.zipDialogTitle': 'اختر أرشيف التصدير',
    'import.folderFailed':
        'تعذّرت قراءة المجلد. تأكد من صلاحياته ثم اختره مجددًا.',
    'import.importErrorTitle': 'تعذّر الاستيراد',
    'import.errorArchiveEmpty': 'الملف المحدد فارغ.',
    'import.errorArchiveSizeLimit': 'يتجاوز الأرشيف حد الحجم المدعوم.',
    'import.errorFolderUnreadable': 'تعذّرت قراءة أحد ملفات المجلد المحدد.',
    'import.errorEntryCountLimit':
        'يحتوي الأرشيف على عدد كبير جدًا من الملفات.',
    'import.errorEntrySizeLimit': 'يتجاوز أحد ملفات الأرشيف حد الحجم.',
    'import.errorJsonFileSizeLimit':
        'يتجاوز ملف JSON المدعوم حد القراءة للاستيراد.',
    'import.errorJsonPayloadSizeLimit':
        'تتجاوز ملفات JSON المدعومة حد القراءة للاستيراد.',
    'import.errorExpandedSizeLimit': 'يتجاوز الأرشيف حد الحجم بعد فك الضغط.',
    'import.errorInvalidEntryPath': 'يحتوي الأرشيف على مسار ملف غير صالح.',
    'import.errorAbsoluteEntryPath': 'يحتوي الأرشيف على مسار مطلق.',
    'import.errorPathTraversal': 'يحتوي الأرشيف على مسار غير آمن.',
    'import.errorDuplicateEntry': 'يحتوي الأرشيف على مسارات مكررة أو ملتبسة.',
    'import.errorSymbolicLinkRejected':
        'الأرشيفات التي تحتوي على روابط رمزية غير مدعومة.',
    'import.errorInvalidJsonPathFilter': 'نمط تحديد الملفات المدعومة غير صالح.',
    'import.errorArchiveCorrupt': 'تعذّرت قراءة أحد ملفات الأرشيف بأمان.',
    'import.errorArchiveChanged': 'تغيّر الأرشيف أثناء قراءته.',
    'import.errorRecordCountLimit': 'يتجاوز عدد سجلات التصدير حد الاستيراد.',
    'import.errorImportWriteFailed': 'تعذّر حفظ الاستيراد.',
    'import.errorMalformedMessageJson': 'ملف الرسائل ليس JSON صالحًا.',
    'import.errorUnsupportedMessageJson': 'صيغة ملف الرسائل غير مدعومة.',
    'import.errorMalformedCommentsJson': 'ملف التعليقات ليس JSON صالحًا.',
    'import.errorUnsupportedCommentsJson': 'صيغة ملف التعليقات غير مدعومة.',
    'import.errorMalformedReactionsJson': 'ملف التفاعلات ليس JSON صالحًا.',
    'import.errorUnsupportedReactionsJson': 'صيغة ملف التفاعلات غير مدعومة.',
    'import.errorMalformedPostsJson': 'ملف المنشورات ليس JSON صالحًا.',
    'import.errorUnsupportedPostsJson': 'صيغة ملف المنشورات غير مدعومة.',
    'import.errorUnknown': 'حدث خطأ غير متوقع أثناء الاستيراد.',
    'import.errorNoSupportedFiles': 'لم يُعثر على ملفات تصدير Facebook مدعومة.',
    'import.readsAndStoresLocally': 'يقرأ تمواي المجلد أو ملف ZIP المحدد على هذا الجهاز ويحفظ السجلات المدعومة في الأرشيف المحلي.',
    'import.importNow': 'استيراد الآن',
    'import.cancel': 'إلغاء الاستيراد',
    'import.progress': 'الملفات {done} من {total}',
    'import.recordsWritten': 'السجلات المكتوبة: {count}',
    'import.resultTitle': 'اكتمل الاستيراد',
    'import.events': 'الأحداث',
    'import.people': 'الأشخاص',
    'import.conversations': 'المحادثات',
    'import.attachments': 'المرفقات',
    'import.skippedRecords': 'السجلات المتجاوزة',
    'import.reusedExisting':
        'سبق استيراد هذا التصدير؛ أُعيد استخدام سجلات الأرشيف الموجودة.',
    'import.warningsTitle': 'تفاصيل السجلات المتجاوزة',
    'import.warningFile': 'الملف',
    'import.warningField': 'الحقل',
    'import.warningBound': 'الحد',
    'import.warningBoundMinimum': 'الحد الأدنى المطلوب',
    'import.warningBoundMaximum': 'الحد الأعلى المسموح',
    'import.warningBoundWrite': 'رفضتها قاعدة البيانات المحلية',
    'import.warningMore': 'و{count} أخرى',
    'import.warningGeneric':
        'تم تخطي أحد السجلات؛ لا تتوفر تفاصيل إضافية.',
    'import.cancelledRolledBack': 'أُلغي الاستيراد. تم التراجع عن الاستيراد الجزئي ولا تبقى سجلات من هذه المحاولة.',
    'import.errorNothingSaved': 'لم تُحفظ أي بيانات من هذه المحاولة.',
    'import.errorRolledBack':
        'فشل الاستيراد وتم التراجع عنه؛ لم تُحفظ سجلات جزئية.',
    'person.failed': 'تعذّر تحميل الأشخاص من الأرشيف المحلي.',
    'person.retry': 'حاول مرة تانية',
    'person.emptyTitle': 'ما في أشخاص بعد',
    'person.emptyBody':
        'استورد نسخة بياناتك لتشوف ملفات الأشخاص اللي حكيت معهن — كل رقم '
        'محسوب من رسائلك المحفوظة.',
    'person.heroPhotos': 'شوف الصور · {count}',
    'person.openConversation': 'افتح المحادثة',
    'person.viewProfile': 'افتح ملف الشخص',
    'person.rangeMessages': 'حكيتوا {count} رسالة',
    'person.rangeYear': 'في {year}',
    'person.rangeYears': 'من {from} لـ{to}',
    'person.platformId': 'معرّف المنصة {id}',
    'person.platformFacebook': 'فيسبوك',
    'person.platformInstagram': 'إنستغرام',
    'person.platformWhatsapp': 'واتساب',
    'person.statMessages': 'رسالة',
    'person.statPhotos': 'صورة',
    'person.statFirst': 'أول تواصل',
    'person.statLast': 'آخر تواصل',
    'person.recentTitle': 'آخر اللي حكيته',
    'person.recentSubtitle': 'محادثاتك المستردة من واتساب وفيسبوك',
    'person.recentBadge': 'سجل الذكريات',
    'person.recentEmpty': 'ما في رسائل نصية محفوظة.',
    'person.loadedCount': 'تم تحميل {loaded} من {total}',
    'person.loadOlder': 'حمّل الأقدم',
    'person.pageFailed': 'تعذّر تحميل الرسائل الأقدم.',
    'person.photosTitle': 'صور بياناتكم ({count} صورة)',
    'person.photosSubtitle': 'لقطات وذكريات مسترجعة ومحفوظة محلياً',
    'person.allPhotos': 'عرض كل الصور',
    'person.photosEmpty': 'ما في صور مشتركة بالأرشيف.',
    'person.yearsTitle': 'أرقام بياناتكم',
    'person.yearsSubtitle': 'رسائل هذا الشخص، سنة بسنة',
    'person.yearsEmpty': 'ما في رسائل مؤرخة أرسلها هذا الشخص.',
    'person.yearsTotal': 'المجموع: {count} رسالة أرسلها',
    'person.yearsPeak': 'ذروة التواصل: {year}',
    'person.nearbyTitle': 'ناس قريبين منه',
    'person.nearbyBadge': 'محيط التواصل',
    'person.nearbyEmpty': 'ما في أشخاص بالأرشيف بعد.',
    'person.nearbyRank': 'الترتيب {rank} بأكثر الرسائل',
    'person.nearbyNote': 'الترتيب محسوب من عدد الرسائل المؤرخة في أرشيفك.',
    'person.archiveTitle': 'معلومات الأرشيف المحلي',
    'person.archiveSubtitle':
        'محلي فقط · 100% — ما بينرسل أي شي خارج جهازك، وكل شي مفهرس على '
        'الذاكرة الداخلية.',
    'person.archiveIndexType': 'نوع الفهرس',
    'person.archiveRecords': 'السجلات المفهرسة',
    'person.archiveLast': 'آخر سجل مؤرخ',
    'person.memoryTitle': 'ذكرى من محادثتكم',
    'person.memoryEmpty': 'ما في اقتباس محفوظ بعد.',
    'person.undated': 'بلا تاريخ',
    'person.thisYear': 'هذه السنة · {year}',
    'person.yearAgo': 'منذ سنة · {year}',
    'person.yearsAgo': 'منذ {count} سنوات · {year}',
    'person.shortcutsTitle': 'الاختصارات',
    'person.shortcutsSubtitle': 'أرشيف الحساب الشخصي',
    'person.importAction': 'استيراد بيانات جديدة',
    'person.navMe': 'ملفي',
    'person.navHome': 'الرئيسية',
    'person.navStory': 'قصتك بالأرقام',
    'person.navAnalytics': 'التحليلات',
    'person.navMessages': 'الرسائل',
    'person.navMedia': 'الصور',
    'person.navPeople': 'الأشخاص',
    'person.navSettings': 'الإعدادات',
    'person.ownershipTitle': 'أرشيفك ملكك بالكامل',
    'person.ownershipBody':
        'الملفات مخزنة ومفهرسة على قرصك الصلب دون حاجة لأي اتصال خارجي. '
        'بياناتك ملكك وحدك، وما بتطلع من جهازك أبداً.',
  };
}

/// Language choice for the whole app; `system` follows the operating system.
enum AppLocaleMode { system, en, ar }

/// Reads and writes the language choice inside the local workspace folder.
///
/// The file is plain JSON with no personal content, so it can be deleted with
/// the workspace at any time. Every failure (missing plugin, unwritable folder,
/// corrupt JSON) resolves to `null` and the app falls back to the system
/// language.
class AppLocaleStore {
  const AppLocaleStore();

  /// Settings file name inside the workspace folder.
  static const String fileName = 'settings.json';

  /// Key holding the language mode inside that file.
  static const String localeKey = 'locale';

  Future<Directory?> _directory() async {
    try {
      final root = await getApplicationSupportDirectory();
      return Directory(
        p.join(root.path, WorkspaceService.workspaceDirectoryName),
      );
    } on Object {
      return null;
    }
  }

  Future<AppLocaleMode?> read() async {
    final directory = await _directory();
    if (directory == null) return null;
    try {
      final file = File(p.join(directory.path, fileName));
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final name = decoded[localeKey];
      if (name is! String) return null;
      return AppLocaleMode.values.byName(name);
    } on Object {
      return null;
    }
  }

  /// Writes the choice; a failure leaves the in-memory choice in effect.
  Future<void> write(AppLocaleMode mode) async {
    final directory = await _directory();
    if (directory == null) return;
    try {
      await directory.create(recursive: true);
      await File(p.join(directory.path, fileName))
          .writeAsString(jsonEncode(<String, String>{localeKey: mode.name}));
    } on Object {
      // The language stays applied for this session.
    }
  }
}

final appLocaleStoreProvider = Provider<AppLocaleStore>(
  (ref) => const AppLocaleStore(),
);

/// Holds the language choice and mirrors it to the workspace settings.
class AppLocaleController extends Notifier<AppLocaleMode> {
  /// True while the persisted choice is being read, so the app can render
  /// immediately in the system language instead of blocking.
  bool _restoring = false;

  @override
  AppLocaleMode build() {
    _restore();
    return AppLocaleMode.system;
  }

  Future<void> _restore() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final stored = await ref.read(appLocaleStoreProvider).read();
      if (stored != null) state = stored;
    } on Object {
      // Dispose or unreadable settings: keep the system language.
    } finally {
      _restoring = false;
    }
  }

  /// Applies [mode] to the running app, then persists it.
  Future<void> select(AppLocaleMode mode) async {
    state = mode;
    try {
      await ref.read(appLocaleStoreProvider).write(mode);
    } on Object {
      // Persisting is best effort; the session keeps the choice.
    }
  }
}

final appLocaleModeProvider =
    NotifierProvider<AppLocaleController, AppLocaleMode>(
      AppLocaleController.new,
    );

/// Language of the operating system, used by [AppLocaleMode.system].
Locale systemLocale() {
  final locales = PlatformDispatcher.instance.locales;
  return locales.isEmpty ? const Locale('en') : locales.first;
}

/// Strings for the active language.
final appStringsProvider = Provider<AppStrings>((ref) {
  final mode = ref.watch(appLocaleModeProvider);
  return switch (mode) {
    AppLocaleMode.en => const AppStringsEn(),
    AppLocaleMode.ar => const AppStringsAr(),
    AppLocaleMode.system =>
      systemLocale().languageCode == 'ar'
          ? const AppStringsAr()
          : const AppStringsEn(),
  };
});
