import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/l10n/app_strings.dart';
import '../features/analytics/analytics_controller.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/home/home_screen.dart';
import '../features/media/media_screen.dart';
import '../features/messages/messages_controller.dart';
import '../features/messages/messages_screen.dart';
import '../features/people/person_controller.dart';
import '../features/people/person_screen.dart';
import '../features/search/search_screen.dart';
import '../features/story/story_screen.dart';
import '../features/settings/settings_screen.dart';

/// أقسام التطبيق السبعة — ترتيبها هو ترتيب `NavigationBar` و`IndexedStack`.
///
/// الأيقونات من خريطة `docs/DESIGN.md` §4: `Icons.*` بنفس الوزن البصري لـLucide.
enum TmSection {
  home(Icons.home_outlined, Icons.home),
  story(Icons.bar_chart, Icons.bar_chart),
  analytics(Icons.insights, Icons.insights),
  messages(Icons.forum_outlined, Icons.forum),
  media(Icons.image_outlined, Icons.image),
  people(Icons.people_outline, Icons.people),
  settings(Icons.settings_outlined, Icons.settings);

  const TmSection(this.icon, this.selectedIcon);

  final IconData icon;
  final IconData selectedIcon;
}

/// أسماء الأقسام بالعربية والإنجليزية.
///
/// `AppStrings` ملك `lib/src/core/l10n` وهو خارج نطاق هذه الجلسة، فلا نضيف
/// إليه مفاتيح؛ تسميات التنقّل تعيش مع الهيكل الذي يعرضها.
class _SectionLabels {
  const _SectionLabels(this.rtl);

  final bool rtl;

  String of(TmSection section) => switch (section) {
    TmSection.home => rtl ? 'الرئيسية' : 'Home',
    TmSection.story => rtl ? 'قصتك بالأرقام' : 'Your story in numbers',
    TmSection.analytics => rtl ? 'التحليلات' : 'Analytics',
    TmSection.messages => rtl ? 'الرسائل' : 'Messages',
    TmSection.media => rtl ? 'الصور' : 'Photos',
    TmSection.people => rtl ? 'الأشخاص' : 'People',
    TmSection.settings => rtl ? 'الإعدادات' : 'Settings',
  };

  /// تسمية قصيرة لتبويبات الشريط العلوي: المرجع يستعمل «الرئيسية/الذكريات/
  /// الأشخاص»، فتبويبات الهيدر لا تحمل الأسماء الطويلة.
  String short(TmSection section) => switch (section) {
    TmSection.home => rtl ? 'الرئيسية' : 'Home',
    TmSection.story => rtl ? 'الذكريات' : 'Memories',
    TmSection.people => rtl ? 'الأشخاص' : 'People',
    _ => of(section),
  };

  String get search => rtl ? 'البحث' : 'Search';
}

/// هيكل التطبيق: شريط علوي ثابت، سبعة أقسام في `IndexedStack`، وشريط تنقّل.
///
/// الاتجاه يُفرض هنا من [AppStrings.direction] حتى تعمل الشاشات النائبة RTL
/// دون الاعتماد على استنتاج Flutter من اللغة.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.importPageBuilder});

  /// صفحة الفحص/الاستيراد الحالية، تُفتح من أزرار الاستيراد في الرئيسية.
  final WidgetBuilder importPageBuilder;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  TmSection _section = TmSection.home;

  /// الأقسام المزارة فقط تُبنى: الشاشات الحقيقية تفتح مساحة العمل وقاعدة
  /// البيانات، ولا نريد ذلك لقسم لم يفتحه المستخدم. وبعد أول زيارة يبقى
  /// العنصر في الشجرة فيحفظ `IndexedStack` حالته وموضع تمريره.
  final Set<TmSection> _visited = {TmSection.home};

  void _select(int index) {
    final section = TmSection.values[index];
    setState(() {
      _section = section;
      _visited.add(section);
    });
  }

  /// اختصارات الرئيسية تُترجم إلى أقسام الهيكل، فلا تعرف الشاشة عن الهيكل شيئاً.
  void _openDestination(HomeDestination destination) {
    final section = switch (destination) {
      HomeDestination.story => TmSection.story,
      HomeDestination.messages => TmSection.messages,
      HomeDestination.media => TmSection.media,
      HomeDestination.people => TmSection.people,
      HomeDestination.settings => TmSection.settings,
    };
    _select(section.index);
  }

  /// Opens the people section on [personId].
  ///
  /// Used by a search result's person line and by a conversation participant;
  /// the screens only know the id, never the shell.
  void _openPerson(int personId) {
    ref.read(personSelectionProvider.notifier).select(personId);
    _select(TmSection.people.index);
  }

  void _openSearch(TextDirection textDirection) {
    // المسار الجديد يُبنى فوق الـNavigator، أي خارج Directionality الهيكل.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(
          textDirection: textDirection,
          child: Scaffold(
            appBar: AppBar(
              leading: Builder(
                builder: (buttonContext) => IconButton(
                  key: const ValueKey('search-back'),
                  tooltip: textDirection == TextDirection.rtl ? 'رجوع' : 'Back',
                  icon: Icon(
                    textDirection == TextDirection.rtl
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                  ),
                  onPressed: () => Navigator.of(buttonContext).pop(),
                ),
              ),
            ),
            body: SafeArea(
              child: SearchScreen(
                onOpenPerson: (personId) {
                  Navigator.of(context).pop();
                  _openPerson(personId);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final labels = _SectionLabels(strings.isRtl);

    return Directionality(
      textDirection: strings.direction,
      child: Scaffold(
        backgroundColor: TmColors.bg,
        body: Column(
          children: [
            _ShellTopBar(
              labels: labels,
              section: _section,
              onSelect: _select,
              onSearch: () => _openSearch(strings.direction),
            ),
            Expanded(
              child: IndexedStack(
                index: _section.index,
                children: [
                  for (final section in TmSection.values)
                    _page(context, section),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportRoute(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: Builder(
        builder: (buttonContext) => IconButton(
          key: const ValueKey('import-page-back'),
          tooltip: Directionality.of(buttonContext) == TextDirection.rtl
              ? 'رجوع'
              : 'Back',
          icon: Icon(
            Directionality.of(buttonContext) == TextDirection.rtl
                ? Icons.arrow_forward
                : Icons.arrow_back,
          ),
          onPressed: () => Navigator.of(buttonContext).pop(),
        ),
      ),
    ),
    body: widget.importPageBuilder(context),
  );

  /// وجه واحد من `IndexedStack`: مفتاح ثابت وشاشته الحقيقية.
  Widget _page(BuildContext context, TmSection section) {
    if (!_visited.contains(section)) return const SizedBox.shrink();

    final Widget child = switch (section) {
      TmSection.home => HomeScreen(
        importPageBuilder: _buildImportRoute,
        onOpenDestination: _openDestination,
      ),
      // «قصتك بالأرقام» شاشة القراءة الواحدة لأرقام الأرشيف؛ التحليلات
      // بواجهتها الخاصة. سنة الذروة تفتح التحليلات مفلترة عليها، والشاشة
      // نفسها لا تعرف الهيكل.
      TmSection.story => StoryScreen(
        importPageBuilder: _buildImportRoute,
        onOpenYear: (year) {
          ref.read(analyticsYearProvider.notifier).select(year);
          _select(TmSection.analytics.index);
        },
      ),
      TmSection.settings => const SettingsScreen(),
      TmSection.analytics => AnalyticsScreen(
        importPageBuilder: _buildImportRoute,
        onOpenSection: (name) =>
            _select(TmSection.values.byName(name).index),
      ),
      // شريطا «كل الصور» و«الأرقام والإحصائيات» برأس المحادثة ينقلان عبر
      // الهيكل، فلا تعرف شاشة الرسائل شيئاً عنه.
      TmSection.messages => MessagesScreen(
        onOpenSection: (name) =>
            _select(TmSection.values.byName(name).index),
        // A participant's name in the open thread opens their profile.
        onOpenPerson: _openPerson,
      ),
      // عمود «الاختصارات» داخل شاشة الصور ينقل عبر الهيكل، وزر الاستيراد
      // يفتح صفحة الاستيراد نفسها بلا أن تعرف الشاشة الهيكل.
      TmSection.media => MediaScreen(
        importPageBuilder: _buildImportRoute,
        onOpenSection: (name) =>
            _select(TmSection.values.byName(name).index),
      ),
      // «الأشخاص» يفتح ملف الشخص، وزراه ينقلان للقسمين المبنيين فعلاً: لا
      // يعرف ملف الشخص عن الهيكل شيئاً.
      TmSection.people => PersonScreen(
        onOpenConversation: (conversationId) {
          ref.read(messagesSelectionProvider.notifier).select(conversationId);
          _select(TmSection.messages.index);
        },
        onOpenPhotos: () => _select(TmSection.media.index),
        // عمود «الاختصارات» داخل الملف ينقل عبر الهيكل، وزر الاستيراد يفتح
        // صفحة الاستيراد نفسها بلا أن تعرف الشاشة الهيكل.
        onOpenSection: (name) =>
            _select(TmSection.values.byName(name).index),
        importPageBuilder: _buildImportRoute,
      ),
    };

    return KeyedSubtree(
      key: ValueKey('shell-page-${section.name}'),
      child: child,
    );
  }
}

/// الشريط العلوي كما في `design/reference/user-2026-10-30/01-home.jpg`
/// (ومنه بقية الصور): مارك دائري أزرق فيه درع + «Tmewai» وتحته سطر رمادي،
/// تبويبات بأيقونة قائدة وخط سفلي أزرق للنشط، كبسولة بحث رمادية، ثم حبّة
/// «محلي على جهازك» وقرص جرس بشارة حمراء وأفاتار دائري.
///
/// التبويبات الثلاثة (الرئيسية · الذكريات · الأشخاص) ثابتة كما في الرئيسية،
/// ويُضاف تبويب القسم المفتوح إن لم يكن منها فيبقى للقسم النشط تبويب ظاهر.
///
/// الترتيب يتغيّر مع العرض: الضيق يضع البحث بعد التبويبات (صورة الرئيسية)،
/// والواسع يضعه بجانب المارك ويُظهر حبّة «محلي على جهازك» (صور 02–06).
class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.labels,
    required this.section,
    required this.onSelect,
    required this.onSearch,
  });

  final _SectionLabels labels;
  final TmSection section;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;

  static const _coreTabs = [
    TmSection.home,
    TmSection.story,
    TmSection.people,
  ];

  List<TmSection> get _tabs => [
    for (final candidate in TmSection.values)
      if (_coreTabs.contains(candidate) || candidate == section) candidate,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= TmSize.shellWideMinWidth;

        final search = SizedBox(
          width: TmSize.homeSearchWidth,
          child: SearchBar(
            key: const ValueKey('shell-search'),
            hintText: labels.rtl
                ? 'بحث على رسالة أو اسم'
                : 'Search messages or names',
            onTap: onSearch,
            trailing: const [Icon(Icons.search)],
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: const WidgetStatePropertyAll(TmColors.bg),
            constraints: const BoxConstraints(minHeight: TmHit.min),
          ),
        );

        final tabs = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final candidate in _tabs)
                ShellTab(
                  label: labels.short(candidate),
                  icon: candidate.icon,
                  selected: candidate == section,
                  onTap: () => onSelect(candidate.index),
                  key: ValueKey('shell-nav-${candidate.name}'),
                ),
            ],
          ),
        );

        return Container(
          key: const ValueKey('shell-top-bar'),
          height: TmSize.shellTopBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
          decoration: const BoxDecoration(
            color: TmColors.card,
            border: Border(bottom: BorderSide(color: TmColors.border)),
          ),
          child: Row(
            children: [
              _ShellBrand(labels: labels),
              const SizedBox(width: TmSpace.l),
              if (wide) search,
              Expanded(child: Center(child: tabs)),
              if (wide && section != TmSection.home)
                _LocalOnlyPill(labels: labels),
              if (!wide) search,
              const _ShellBell(),
              const SizedBox(width: TmSpace.xs),
              _ShellAvatar(
                tooltip: labels.rtl ? 'الملف الشخصي' : 'Profile',
                onTap: () => onSelect(TmSection.home.index),
              ),
            ],
          ),
        );
      },
    );
  }

}

/// المارك الدائري واسم المنتج: الدائرة أزرق [TmColors.primary] بدرع أبيض،
/// والكلمة بسطر رمادي صغير تحتها.
class _ShellBrand extends StatelessWidget {
  const _ShellBrand({required this.labels});

  final _SectionLabels labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('shell-brand-mark'),
          width: TmSize.shellBrandMark,
          height: TmSize.shellBrandMark,
          decoration: const BoxDecoration(
            color: TmColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield,
            color: TmColors.card,
            size: TmSize.shellBrandIcon,
          ),
        ),
        const SizedBox(width: TmSpace.s),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tmewai', style: _wordmarkStyle),
            Text(
              labels.rtl
                  ? 'بياناتك الشخصية على جهازك'
                  : 'Your data stays on device',
              maxLines: 1,
              style: TmType.captionStyle.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// حبّة «محلي على جهازك 100%» الخضراء — تظهر بكل الصور عدا الرئيسية.
class _LocalOnlyPill extends StatelessWidget {
  const _LocalOnlyPill({required this.labels});

  final _SectionLabels labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('shell-local-only'),
      height: TmSize.shellLocalPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.successSurfaceSoft,
        borderRadius: BorderRadius.circular(TmRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: TmSize.shellLocalIcon,
            color: TmColors.success,
          ),
          const SizedBox(width: TmSpace.s),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labels.rtl ? 'محلي على جهازك' : 'Local on your device',
                style: TmType.captionStyle.copyWith(
                  color: TmColors.success,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              Text(
                '100%',
                style: TmType.captionStyle.copyWith(
                  color: TmColors.success,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// الجرس داخل قرص رمادي فاتح، وشارة حمراء صغيرة أعلاه يميناً.
///
/// لا رقم داخل الشارة: الأرشيف لا يخزّن إشعارات، والرقم في المرجع محتوى تجريبي.
class _ShellBell extends StatelessWidget {
  const _ShellBell();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('shell-notifications'),
      tooltip: Directionality.of(context) == TextDirection.rtl
          ? 'الإشعارات'
          : 'Notifications',
      onPressed: () {},
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: TmHit.min,
        minHeight: TmHit.min,
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: TmSize.shellBell,
            height: TmSize.shellBell,
            decoration: const BoxDecoration(
              color: TmColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: TmSize.shellAvatarIcon,
              color: TmColors.text2,
            ),
          ),
          const PositionedDirectional(
            top: 1,
            end: 4,
            child: _BellDot(),
          ),
        ],
      ),
    );
  }
}

class _BellDot extends StatelessWidget {
  const _BellDot();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('shell-notification-dot'),
    width: TmSize.shellBellDot,
    height: TmSize.shellBellDot,
    decoration: BoxDecoration(
      color: TmColors.error,
      shape: BoxShape.circle,
      border: Border.all(
        color: TmColors.card,
        width: TmSize.shellBellDotRing,
      ),
    ),
  );
}

/// أفاتار دائري محايد: الأرشيف لا يخزّن صورة الحساب، فالدائرة من توكنز فقط.
class _ShellAvatar extends StatelessWidget {
  const _ShellAvatar({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('shell-avatar'),
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: TmHit.min,
        minHeight: TmHit.min,
      ),
      icon: Container(
        width: TmSize.shellAvatar,
        height: TmSize.shellAvatar,
        decoration: const BoxDecoration(
          color: TmColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_outline,
          size: TmSize.shellAvatarIcon,
          color: TmColors.primary,
        ),
      ),
    );
  }
}

/// تبويب واحد في الشريط العلوي: أيقونة قائدة 18 ثم التسمية، والخط السفلي
/// 3px للمحدَّد فقط (وهو ما تفعله صورة الرئيسية).
class ShellTab extends StatelessWidget {
  const ShellTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TmColors.primary : TmColors.text2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      child: Container(
        height: TmSize.shellTopBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? TmColors.primary : TmColors.transparent,
              width: TmSize.shellTabUnderline,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: TmSize.shellTabIcon, color: color),
            const SizedBox(width: TmSize.shellTabGap),
            Text(
              label,
              style: TextStyle(
                fontSize: TmType.caption,
                height: TmType.height,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _wordmarkStyle = TextStyle(
  fontFamily: 'IBMPlexSansArabic',
  fontSize: TmType.h1,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.3,
  color: TmColors.text,
  height: 1.15,
);
