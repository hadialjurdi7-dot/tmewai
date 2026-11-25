import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';

/// Store that never touches the filesystem, so the test is hermetic.
class _RecordingLocaleStore extends AppLocaleStore {
  _RecordingLocaleStore();

  final List<AppLocaleMode> writes = <AppLocaleMode>[];
  AppLocaleMode? stored;

  @override
  Future<AppLocaleMode?> read() async => stored;

  @override
  Future<void> write(AppLocaleMode mode) async {
    writes.add(mode);
    stored = mode;
  }
}

class _FixedLocaleController extends AppLocaleController {
  _FixedLocaleController(this.mode);

  final AppLocaleMode mode;

  @override
  AppLocaleMode build() => mode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('string tables', () {
    test('the key list has no duplicates', () {
      expect(appStringKeys.toSet().length, appStringKeys.length);
    });

    test('both locales expose exactly the same keys', () {
      final expected = appStringKeys.toSet();
      expect(const AppStringsEn().values.keys.toSet(), expected);
      expect(const AppStringsAr().values.keys.toSet(), expected);
    });

    test('no translation is empty or a placeholder', () {
      for (final strings in const <AppStrings>[
        AppStringsEn(),
        AppStringsAr(),
      ]) {
        for (final key in appStringKeys) {
          expect(
            strings[key].trim(),
            isNotEmpty,
            reason: '$key in ${strings.locale.languageCode}',
          );
        }
      }
    });

    test('language direction follows the locale', () {
      expect(const AppStringsEn().direction, TextDirection.ltr);
      expect(const AppStringsEn().isRtl, isFalse);
      expect(const AppStringsAr().direction, TextDirection.rtl);
      expect(const AppStringsAr().isRtl, isTrue);
      expect(const AppStringsAr().locale, const Locale('ar'));
    });

    test('typed getters read their own key in both languages', () {
      const en = AppStringsEn();
      const ar = AppStringsAr();
      expect(en.searchTitle, 'Advanced search');
      expect(ar.searchTitle, 'البحث المتقدم');
      expect(en.settingsCancel, 'Cancel');
      expect(ar.settingsCancel, 'إلغاء');
      expect(en.overviewOpenRecords, isNot(ar.overviewOpenRecords));
      // The date pattern stays untranslated in both languages.
      expect(ar.searchFromLabel, contains('YYYY-MM-DD'));
      expect(en.settingsConfirmBody.contains('DELETE'), isTrue);
      expect(ar.settingsConfirmBody.contains('DELETE'), isTrue);
    });
  });

  group('locale provider', () {
    test('Arabic mode selects Arabic strings and RTL', () {
      final container = ProviderContainer.test(
        overrides: [
          appLocaleModeProvider.overrideWith(
            () => _FixedLocaleController(AppLocaleMode.ar),
          ),
        ],
      );

      final strings = container.read(appStringsProvider);
      expect(strings, isA<AppStringsAr>());
      expect(strings.locale, const Locale('ar'));
      expect(strings.isRtl, isTrue);
    });

    test('English mode selects English strings and LTR', () {
      final container = ProviderContainer.test(
        overrides: [
          appLocaleModeProvider.overrideWith(
            () => _FixedLocaleController(AppLocaleMode.en),
          ),
        ],
      );

      final strings = container.read(appStringsProvider);
      expect(strings, isA<AppStringsEn>());
      expect(strings.isRtl, isFalse);
    });

    test('system mode follows the platform language', () {
      final container = ProviderContainer.test(
        overrides: [
          appLocaleStoreProvider.overrideWithValue(_RecordingLocaleStore()),
        ],
      );

      final strings = container.read(appStringsProvider);
      expect(
        strings.locale.languageCode,
        systemLocale().languageCode == 'ar' ? 'ar' : 'en',
      );
    });

    test('choosing a language persists it in the workspace settings', () async {
      final store = _RecordingLocaleStore();
      final container = ProviderContainer.test(
        overrides: [appLocaleStoreProvider.overrideWithValue(store)],
      );

      expect(container.read(appLocaleModeProvider), AppLocaleMode.system);

      await container.read(appLocaleModeProvider.notifier).select(
        AppLocaleMode.ar,
      );

      expect(container.read(appLocaleModeProvider), AppLocaleMode.ar);
      expect(container.read(appStringsProvider), isA<AppStringsAr>());
      expect(store.writes, [AppLocaleMode.ar]);
      expect(store.stored, AppLocaleMode.ar);
    });

    test('a stored choice is restored on startup', () async {
      final store = _RecordingLocaleStore()..stored = AppLocaleMode.ar;
      final container = ProviderContainer.test(
        overrides: [appLocaleStoreProvider.overrideWithValue(store)],
      );

      container.read(appLocaleModeProvider);
      // Let the asynchronous restore finish.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appLocaleModeProvider), AppLocaleMode.ar);
    });
  });
}
