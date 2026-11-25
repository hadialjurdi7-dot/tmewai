import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_data_agent/src/app/app_shell.dart';
import 'package:personal_data_agent/src/app/facebook_import_preview_summary.dart';
import 'package:personal_data_agent/src/core/design/theme.dart';
import 'package:personal_data_agent/src/core/design/tokens.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/core/logging/redacted_log.dart';
import 'package:personal_data_agent/src/features/import/import_controller.dart';
import 'package:personal_data_agent/src/features/import/import_run_status.dart';
import 'package:personal_data_agent/src/features/overview/overview_controller.dart';
import 'package:personal_data_agent/src/features/overview/overview_screen.dart';
import 'package:personal_data_agent/src/features/search/search_controller.dart';
import 'package:personal_data_agent/src/features/search/search_screen.dart';
import 'package:personal_data_agent/src/features/settings/settings_controller.dart';
import 'package:personal_data_agent/src/features/settings/settings_screen.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_controller.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_screen.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

/// Records one content-free event per import action on the local developer
/// log, so a failed import leaves a code behind instead of only a message.
const RedactedLog _importLog = RedactedLog();

final exportInspectorProvider = Provider<ExportInspector>(
  (ref) => const ExportInspector(),
);
final facebookJsonImporterProvider = Provider<FacebookJsonImporter>(
  (ref) => const FacebookJsonImporter(),
);
final facebookImportPreviewProvider =
    NotifierProvider<_FacebookImportPreviewNotifier, FacebookImportPreview?>(
  _FacebookImportPreviewNotifier.new,
);

final selectedArchiveProvider =
    NotifierProvider<_SelectedArchiveNotifier, SelectedExport?>(
  _SelectedArchiveNotifier.new,
);
/// The ZIP the browser picker handed over.
///
/// A browser has no file path to keep, so the bytes are held here between the
/// pick, the inspection and the import; on every other platform it stays null.
final webArchiveBytesProvider =
    NotifierProvider<_WebArchiveBytesNotifier, Uint8List?>(
  _WebArchiveBytesNotifier.new,
);

class _WebArchiveBytesNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => null;

  void set(Uint8List? bytes) => state = bytes;

  void clear() => state = null;
}

final inspectionProvider =
    NotifierProvider<_InspectionNotifier, ArchiveInspection?>(
  _InspectionNotifier.new,
);
final inspectionErrorProvider =
    NotifierProvider<_InspectionErrorNotifier, String?>(
  _InspectionErrorNotifier.new,
);
final isInspectingProvider =
    NotifierProvider<_IsInspectingNotifier, bool>(
  _IsInspectingNotifier.new,
);

class _FacebookImportPreviewNotifier extends Notifier<FacebookImportPreview?> {
  @override
  FacebookImportPreview? build() => null;

  void set(FacebookImportPreview? value) => state = value;
}

class _SelectedArchiveNotifier extends Notifier<SelectedExport?> {
  @override
  SelectedExport? build() => null;

  void set(SelectedExport? value) => state = value;
}

class _InspectionNotifier extends Notifier<ArchiveInspection?> {
  @override
  ArchiveInspection? build() => null;

  void set(ArchiveInspection? value) => state = value;
}

class _InspectionErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

class _IsInspectingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The export the user chose: a folder they extracted themselves, or a ZIP.
///
/// A ZIP is read through its central directory, so a multi-hundred-megabyte
/// export never lands in memory; the folder remains for people who already
/// extracted theirs.
class SelectedExport {
  const SelectedExport({required this.path, required this.isFolder});

  final String path;
  final bool isFolder;

  String get name => path.split(Platform.pathSeparator)
      .where((segment) => segment.isNotEmpty)
      .last;
}

/// Locales the app ships strings for; Arabic switches the app to RTL.
const List<Locale> appSupportedLocales = [Locale('en'), Locale('ar')];

class PersonalDataAgentApp extends ConsumerWidget {
  const PersonalDataAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appLocaleModeProvider);
    final strings = ref.watch(appStringsProvider);
    // A null locale asks MaterialApp to resolve the system language below.
    final locale = switch (mode) {
      AppLocaleMode.system => null,
      AppLocaleMode.en => const Locale('en'),
      AppLocaleMode.ar => const Locale('ar'),
    };

    return MaterialApp(
      title: strings.brandName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: appSupportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('en');
        return supportedLocales.firstWhere(
          (supported) => supported.languageCode == locale.languageCode,
          orElse: () => const Locale('en'),
        );
      },
      theme: buildTmewaiTheme(),
      // Dark mode is not designed yet, so the app stays on the approved light
      // theme instead of inventing dark tokens.
      themeMode: ThemeMode.light,
      home: AppShell(importPageBuilder: _buildImportPage),
    );
  }
}

/// The first section of the shell: the working inspection/import page.
///
/// The home screen from `TASKS.md` session 2 replaces it; until then the shell
/// keeps the only functional entry point reachable.
Widget _buildImportPage(BuildContext context) => const ImportHomePage();

class ImportHomePage extends ConsumerWidget {
  const ImportHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final archive = ref.watch(selectedArchiveProvider);
    final result = ref.watch(inspectionProvider);
    final importPreview = ref.watch(facebookImportPreviewProvider);
    final error = ref.watch(inspectionErrorProvider);
    final busy = ref.watch(isInspectingProvider);
    final importState = ref.watch(importRunProvider);
    final hasSupportedFiles = importPreview != null &&
        importPreview.supportedFiles > 0;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final searchOpen = ref.watch(searchOpenProvider);
    final timelineOpen = ref.watch(timelineOpenProvider);
    final overviewOpen = ref.watch(overviewOpenProvider);
    final settingsOpen = ref.watch(settingsOpenProvider);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Row(
          children: [
            // Focus visits the sidebar in its own group before the content;
            // the default reading-order policy follows the text direction.
            FocusTraversalGroup(child: _AppSidebar(isRtl: isRtl)),
            Expanded(
              child: Column(
                children: [
                  _TopBar(isRtl: isRtl),
                  Expanded(
                    child: searchOpen
                        ? const SearchScreen()
                        : timelineOpen
                        ? const TimelineScreen()
                        : overviewOpen
                        ? const OverviewScreen()
                        : settingsOpen
                        ? const SettingsScreen()
                        : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(36, 30, 36, 48),
                          children: [
                            Text(
                              isRtl
                                  ? 'افهم أرشيفك، وبياناتك تبقى على جهازك'
                                  : 'Understand your archive. Keep your data on your device.',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isRtl
                                  ? 'ابدأ بفحص نسخة البيانات التي نزّلتها من المنصة. الفحص محلي ولا يرسل محتوى إلى أي نموذج ذكاء اصطناعي.'
                                  : 'Inspect a data export you downloaded from a platform. Inspection is local and sends no content to an AI model.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: TmColors.text2),
                            ),
                            const SizedBox(height: 28),
                            _PrivacyNotice(isRtl: isRtl),
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRtl
                                          ? 'ابدأ باستيراد نسخة بيانات'
                                          : 'Start with a data export',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      strings.importReadsAndStoresLocally,
                                      style: Theme.of(context).textTheme.bodyMedium
                                          ?.copyWith(color: TmColors.text2),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        // A browser cannot hand over a folder:
                                        // only the ZIP upload exists there.
                                        if (!kIsWeb)
                                          FilledButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _chooseFolder(
                                                    ref,
                                                    isRtl,
                                                    strings,
                                                  ),
                                          icon: const Icon(Icons.folder_open),
                                          label: Text(strings.importChooseFolder),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _chooseArchive(
                                                    ref,
                                                    isRtl,
                                                    strings,
                                                  ),
                                          icon: const Icon(Icons.archive_outlined),
                                          label: Text(strings.importChooseZip),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _chooseChat(
                                                    ref,
                                                    isRtl,
                                                    strings,
                                                  ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                          ),
                                          label: Text(strings.importChooseChat),
                                        ),
                                        if (result != null && archive != null)
                                          FilledButton.icon(
                                            key: const ValueKey('import-now'),
                                            onPressed: !hasSupportedFiles ||
                                                    importState.running ||
                                                    busy
                                                ? null
                                                : () {
                                                    final bytes = ref.read(
                                                      webArchiveBytesProvider,
                                                    );
                                                    final controller = ref.read(
                                                      importRunProvider.notifier,
                                                    );
                                                    if (bytes != null) {
                                                      controller.runBytes(
                                                        bytes,
                                                        label: archive.name,
                                                      );
                                                    } else {
                                                      controller.run(
                                                        archive.path,
                                                      );
                                                    }
                                                  },
                                            icon: const Icon(Icons.download_for_offline_outlined),
                                            label: Text(strings.importNow),
                                          ),
                                        if (busy)
                                          const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (archive != null) ...[
                                      const SizedBox(height: 18),
                                      _SelectedArchive(source: archive, isRtl: isRtl),
                                    ],
                                    if (error != null) ...[
                                      const SizedBox(height: 16),
                                      _ErrorBanner(message: error),
                                    ],
                                    if (result != null) ...[
                                      const SizedBox(height: 22),
                                      _InspectionSummary(
                                        report: result,
                                        isRtl: isRtl,
                                      ),
                                    ],
                                    if (importPreview != null) ...[
                                      const SizedBox(height: 22),
                                      FacebookImportPreviewSummary(
                                        preview: importPreview,
                                        isRtl: isRtl,
                                      ),
                                    ],
                                    if (importState.running) ...[
                                      const SizedBox(height: 18),
                                      ImportRunProgress(
                                        state: importState,
                                        strings: strings,
                                        onCancel: () => ref
                                            .read(importRunProvider.notifier)
                                            .cancel(),
                                      ),
                                    ],
                                    if (importState.outcome != null) ...[
                                      const SizedBox(height: 18),
                                      ImportOutcomeSummary(
                                        outcome: importState.outcome!,
                                        strings: strings,
                                      ),
                                    ],
                                    if (importState.cancelled) ...[
                                      const SizedBox(height: 16),
                                      ImportCancelledSummary(strings: strings),
                                    ],
                                    if (importState.errorCode != null) ...[
                                      const SizedBox(height: 16),
                                      ImportRunErrorSummary(
                                        code: importState.errorCode!,
                                        strings: strings,
                                        recordsWritten:
                                            importState.progress?.recordsWritten ?? 0,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _NextSteps(isRtl: isRtl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The primary path: the user already extracted the export, so the app reads
  /// the folder in place and never holds the whole archive in memory.
  Future<void> _chooseFolder(
    WidgetRef ref,
    bool isRtl,
    AppStrings strings,
  ) async {
    try {
      final selected = await FilePicker.pickDirectory(
        dialogTitle: strings.importFolderDialogTitle,
      );
      final path = selected?.toFilePath();
      if (path == null || path.isEmpty) return;
      await _inspectSource(
        ref,
        isRtl,
        SelectedExport(path: path, isFolder: true),
      );
    } on Object catch (error) {
      _importLog.failure(
        'import.selection_failed',
        code: 'unknown_error',
        error: error,
        fields: const {'sourceKind': 'folder'},
      );
      ref.read(inspectionErrorProvider.notifier).set(strings.importFolderFailed);
      ref.read(isInspectingProvider.notifier).set(false);
    }
  }

  Future<void> _chooseArchive(
    WidgetRef ref,
    bool isRtl,
    AppStrings strings,
  ) async {
    try {
      final selected = await FilePicker.pickFile(
        dialogTitle: strings.importZipDialogTitle,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (selected == null) return;
      if (kIsWeb) {
        // A browser picker yields a blob URI and no path: read the bytes.
        final bytes = await selected.xFile.readAsBytes();
        if (bytes.isEmpty) return;
        ref.read(webArchiveBytesProvider.notifier).set(bytes);
        await _inspectSource(
          ref,
          isRtl,
          SelectedExport(path: selected.name, isFolder: false),
        );
        return;
      }
      if (selected.path == null) return;
      ref.read(webArchiveBytesProvider.notifier).clear();
      await _inspectSource(
        ref,
        isRtl,
        SelectedExport(path: selected.path!, isFolder: false),
      );
    } on Object catch (error) {
      _importLog.failure(
        'import.selection_failed',
        code: 'unknown_error',
        error: error,
        fields: const {'sourceKind': 'archive'},
      );
      ref.read(inspectionErrorProvider.notifier).set(
            isRtl
                ? 'تعذّر فحص الملف. تأكد أنه ملف ZIP سليم ويمكن قراءته.'
                : 'The archive could not be inspected. Check that it is a readable ZIP file.',
          );
      ref.read(isInspectingProvider.notifier).set(false);
      return;
    }
  }

  /// WhatsApp chat path: pick a `.txt` export or a ZIP carrying its chat logs
  /// and import it through the same run controller. A plain text file has no
  /// ZIP inspection screen, so it goes straight to the write path.
  Future<void> _chooseChat(
    WidgetRef ref,
    bool isRtl,
    AppStrings strings,
  ) async {
    try {
      final selected = await FilePicker.pickFile(
        dialogTitle: strings.importChooseChat,
        type: FileType.custom,
        allowedExtensions: const ['txt', 'zip'],
      );
      if (selected == null) return;
      final controller = ref.read(importRunProvider.notifier);
      controller.reset();
      if (kIsWeb) {
        final bytes = await selected.xFile.readAsBytes();
        if (bytes.isEmpty) return;
        await controller.runWhatsAppBytes(bytes, label: selected.name);
      } else {
        final path = selected.path;
        if (path == null) return;
        await controller.runWhatsApp(path);
      }
    } on Object catch (error) {
      _importLog.failure(
        'import.selection_failed',
        code: 'unknown_error',
        error: error,
        fields: const {'sourceKind': 'chat'},
      );
      ref.read(inspectionErrorProvider.notifier).set(
            isRtl
                ? 'تعذّر قراءة المحادثة. تأكد من ملف نصي صالح.'
                : 'The chat could not be read. Check that it is a valid text file.',
          );
    }
  }

  Future<void> _inspectSource(
    WidgetRef ref,
    bool isRtl,
    SelectedExport source,
  ) async {
    ref.read(inspectionErrorProvider.notifier).set(null);
    ref.read(inspectionProvider.notifier).set(null);
    ref.read(facebookImportPreviewProvider.notifier).set(null);
    ref.read(importRunProvider.notifier).reset();
    ref.read(selectedArchiveProvider.notifier).set(source);
    ref.read(isInspectingProvider.notifier).set(true);
    try {
      final bytes = ref.read(webArchiveBytesProvider);
      final inspector = ref.read(exportInspectorProvider);
      final inspection = bytes != null && !source.isFolder
          ? await inspector.inspectBytes(bytes)
          : await inspector.inspect(source.path);
      ref.read(inspectionProvider.notifier).set(inspection);
      final importer = ref.read(facebookJsonImporterProvider);
      final preview = bytes != null && !source.isFolder
          ? await importer.previewArchiveBytes(bytes)
          : await importer.previewSource(source.path);
      ref.read(facebookImportPreviewProvider.notifier).set(preview);
    } on ArchiveInspectionException catch (exception) {
      _importLog.failure(
        'import.inspect_failed',
        code: exception.code,
        error: exception,
        fields: {'sourceKind': source.isFolder ? 'folder' : 'archive'},
      );
      ref.read(inspectionErrorProvider.notifier).set(
            _inspectionErrorMessage(exception.code, isRtl),
          );
    } on Object catch (error) {
      _importLog.failure(
        'import.inspect_failed',
        code: 'unknown_error',
        error: error,
        fields: {'sourceKind': source.isFolder ? 'folder' : 'archive'},
      );
      ref.read(inspectionErrorProvider.notifier).set(
            isRtl
                ? 'تعذّر فحص المصدر. تأكد من المجلد أو ملف ZIP.'
                : 'The source could not be inspected. Check the folder or the ZIP file.',
          );
    } finally {
      ref.read(isInspectingProvider.notifier).set(false);
    }
  }
}

class _AppSidebar extends ConsumerWidget {
  const _AppSidebar({required this.isRtl});
  final bool isRtl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final searchOpen = ref.watch(searchOpenProvider);
    final timelineOpen = ref.watch(timelineOpenProvider);
    final settingsOpen = ref.watch(settingsOpenProvider);

    return Container(
      width: 238,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: isRtl
              ? BorderSide.none
              : const BorderSide(color: TmColors.border),
          right: isRtl
              ? const BorderSide(color: TmColors.border)
              : BorderSide.none,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // excludeFromSemantics: the wordmark beside it already names
                  // the app, so the mark must not announce a second time.
                  Image.asset(
                    'assets/branding/tmewai_app_icon.png',
                    width: 36,
                    height: 36,
                    // The asset is 1024px. Decoding it at the slot's real pixel
                    // width keeps it sharp on any display without holding a
                    // megapixel of RGBA in memory.
                    cacheWidth:
                        (36 * MediaQuery.devicePixelRatioOf(context)).round(),
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.brandName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          strings.brandTagline,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            // #5D6B7E keeps 4.6:1 on white at this size;
                            // #7A8798 measured 3.7:1, under the AA target.
                            color: Color(0xFF5D6B7E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              _NavItem(
                icon: Icons.dashboard_outlined,
                label: isRtl ? 'نظرة عامة' : 'Overview',
                selected: !searchOpen && !timelineOpen,
                onTap: () {
                  ref.read(searchOpenProvider.notifier).set(false);
                  ref.read(timelineOpenProvider.notifier).set(false);
                  ref.read(overviewOpenProvider.notifier).set(true);
                  ref.read(settingsOpenProvider.notifier).set(false);
                },
              ),
              _NavItem(
                icon: Icons.search,
                label: isRtl ? 'البحث المتقدم' : 'Advanced search',
                selected: searchOpen,
                onTap: () {
                  ref.read(timelineOpenProvider.notifier).set(false);
                  ref.read(overviewOpenProvider.notifier).set(false);
                  ref.read(settingsOpenProvider.notifier).set(false);
                  ref.read(searchOpenProvider.notifier).set(true);
                },
              ),
              _NavItem(
                icon: Icons.timeline,
                label: isRtl ? 'الخط الزمني' : 'Timeline',
                selected: timelineOpen,
                onTap: () {
                  ref.read(searchOpenProvider.notifier).set(false);
                  ref.read(overviewOpenProvider.notifier).set(false);
                  ref.read(settingsOpenProvider.notifier).set(false);
                  ref.read(timelineOpenProvider.notifier).set(true);
                },
              ),
              _NavItem(
                icon: Icons.forum_outlined,
                label: isRtl ? 'المحادثات' : 'Conversations',
              ),
              _NavItem(
                icon: Icons.hub_outlined,
                label: isRtl ? 'شبكة التواصل' : 'Connections',
              ),
              _NavItem(
                icon: Icons.auto_awesome_outlined,
                label: isRtl ? 'أنماطي الرقمية' : 'My digital patterns',
              ),
              const Spacer(),
              const Divider(),
              _NavItem(
                icon: Icons.security_outlined,
                label: isRtl ? 'الخصوصية والإعدادات' : 'Privacy & settings',
                selected: settingsOpen,
                onTap: () {
                  ref.read(searchOpenProvider.notifier).set(false);
                  ref.read(timelineOpenProvider.notifier).set(false);
                  ref.read(overviewOpenProvider.notifier).set(false);
                  ref.read(settingsOpenProvider.notifier).set(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0xFFEAF0F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: ListTile(
          dense: true,
          // Primary navigation: keep a comfortable 44px pointer target.
          minTileHeight: 44,
          onTap: onTap,
          minLeadingWidth: 26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          leading: Icon(
            icon,
            size: 20,
            color: selected
                ? const Color(0xFF355C7D)
                : TmColors.text2,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF263C50)
                  : const Color(0xFF475467),
            ),
          ),
          selected: selected,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isRtl});
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TmColors.border)),
      ),
      child: Row(
        children: [
          Text(isRtl ? 'مساحة البيانات' : 'Data workspace',
              style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: TmColors.successTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 15, color: TmColors.success),
                const SizedBox(width: 6),
                Text(isRtl ? 'محلي — لا يوجد إرسال' : 'Local — no data sent',
                    style: const TextStyle(
                        color: TmColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.isRtl});
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5E9DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: TmColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRtl ? 'الفحص يعمل محليًا' : 'Inspection runs locally',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isRtl
                      ? 'لن يُرسل هذا الفحص الأرشيف أو محتواه إلى خادم أو مزوّد AI.'
                      : 'This inspection does not send the archive or its contents to a server or AI provider.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF476354)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedArchive extends StatelessWidget {
  const _SelectedArchive({required this.source, required this.isRtl});
  final SelectedExport source;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      // A folder has no single byte length; the inspection card below reports
      // its totals, so only a ZIP file shows a size here.
      future: source.isFolder ? Future.value(0) : File(source.path).length(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final sizeLabel = source.isFolder
            ? (isRtl ? 'مجلد' : 'Folder')
            : bytes == null
                ? ''
                : bytes < 1024 * 1024
                    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
                    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        final icon = source.isFolder
            ? Icons.folder_outlined
            : Icons.archive_outlined;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(icon, color: TmColors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(source.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(sizeLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: TmColors.text2)),
              const SizedBox(width: 8),
              Text(
                isRtl ? 'تم الاختيار' : 'Selected',
                style: const TextStyle(
                  fontSize: 12,
                  color: TmColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InspectionSummary extends StatelessWidget {
  const _InspectionSummary({required this.report, required this.isRtl});
  final ArchiveInspection report;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRtl ? 'ملخص الفحص الأولي' : 'Initial inspection summary',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              label: isRtl ? 'الملفات' : 'Entries',
              value: report.entries,
            ),
            _Metric(label: 'JSON', value: report.jsonFiles),
            _Metric(
              label: isRtl ? 'وسائط' : 'Media',
              value: report.mediaFiles,
            ),
            _Metric(
              label: isRtl ? 'غير مدعوم' : 'Other',
              value: report.ignoredFiles,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isRtl
              ? 'حجم الملفات بعد فك الضغط (تقديري من معلومات الأرشيف): ${_formatBytes(report.totalExpandedBytes)}. هذا الفحص لا يعني أن محتوى المنصة قد تم تحليله.'
              : 'Expanded size (from archive metadata): ${_formatBytes(report.totalExpandedBytes)}. Inspection does not mean platform data has been analyzed.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: TmColors.text2),
        ),
        if (report.hasWarnings) ...[
          const SizedBox(height: 12),
          Text(
            isRtl
                ? 'توجد ملفات غير مدعومة أو لم تُكتشف ملفات JSON.'
                : 'Some files are not supported by this prototype, or no JSON files were found.',
            style: const TextStyle(color: Color(0xFF8A5A12)),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: TmColors.text2),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFF6D6CF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: TmColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.isRtl});
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final items = isRtl
        ? const [
            ('1', 'افحص بنية الأرشيف بأمان'),
            ('2', 'راجع أنواع البيانات التي يمكن قراءتها'),
            ('3', 'استورد البيانات محليًا بعد موافقتك'),
          ]
        : const [
            ('1', 'Inspect archive structure safely'),
            ('2', 'Review which data types are readable'),
            ('3', 'Import locally after your confirmation'),
          ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRtl ? 'ما الخطوة التالية؟' : 'What happens next?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: const Color(0xFFEAF0F5),
                      child: Text(item.$1,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF355C7D))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.$2)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _inspectionErrorMessage(String code, bool isRtl) {
  if (!isRtl) {
    return switch (code) {
      'archive_empty' => 'The selected file is empty.',
      'archive_size_limit' =>
        'The archive is larger than the size limit. Extract it and choose the '
            'folder instead.',
      'folder_unreadable' =>
        'A file in the selected folder could not be read.',
      'entry_count_limit' => 'The archive contains too many entries.',
      'entry_size_limit' => 'An archive entry exceeds the file-size limit.',
      'json_file_size_limit' => 'A supported JSON file exceeds the import read limit.',
      'json_payload_size_limit' => 'Supported JSON files exceed the import read limit.',
      'expanded_size_limit' => 'The archive exceeds the expanded-size limit.',
      'invalid_entry_path' => 'The archive contains an invalid file path.',
      'absolute_entry_path' => 'The archive contains an absolute file path.',
      'path_traversal' => 'The archive contains a path traversal entry.',
      'duplicate_entry' => 'The archive contains duplicate or ambiguous paths.',
      'symbolic_link_rejected' => 'Archives with symbolic links are not supported.',
      'invalid_json_path_filter' => 'The supported file selection pattern is invalid.',
      'archive_corrupt' => 'The archive entry content is corrupt.',
      'archive_changed' => 'The archive changed while it was being read.',
      _ => 'The selected file is not a supported, intact ZIP archive.',
    };
  }
  return switch (code) {
    'archive_empty' => 'الملف المحدد فارغ.',
    'archive_size_limit' =>
      'الأرشيف أكبر من حد الحجم. استخرجه واختر المجلد بدلًا منه.',
    'folder_unreadable' => 'تعذّرت قراءة أحد ملفات المجلد المحدد.',
    'entry_count_limit' => 'يحتوي الأرشيف على عدد كبير جدًا من الملفات.',
    'entry_size_limit' => 'يتجاوز أحد الملفات حد الحجم المسموح.',
    'json_file_size_limit' => 'يتجاوز ملف JSON المدعوم حد القراءة للاستيراد.',
    'json_payload_size_limit' => 'تتجاوز ملفات JSON المدعومة حد القراءة للاستيراد.',
    'expanded_size_limit' => 'يتجاوز الأرشيف حد الحجم بعد فك الضغط.',
    'invalid_entry_path' => 'يحتوي الأرشيف على مسار ملف غير صالح.',
    'absolute_entry_path' => 'يحتوي الأرشيف على مسار مطلق.',
    'path_traversal' => 'يحتوي الأرشيف على مسار يحاول الخروج من مجلده.',
    'duplicate_entry' => 'يحتوي الأرشيف على مسارات مكررة أو ملتبسة.',
    'symbolic_link_rejected' => 'الأرشيفات التي تحتوي على روابط رمزية غير مدعومة.',
    'invalid_json_path_filter' => 'نمط تحديد الملفات المدعومة غير صالح.',
    'archive_corrupt' => 'محتوى أحد ملفات الأرشيف تالف.',
    'archive_changed' => 'تغيّر الأرشيف أثناء قراءته.',
    _ => 'الملف ليس أرشيف ZIP سليمًا ومدعومًا.',
  };
}

String _formatBytes(int value) {
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
