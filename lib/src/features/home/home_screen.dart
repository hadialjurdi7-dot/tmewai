import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/l10n/import_labels.dart';
import '../../data/repositories/timeline_repository.dart';
import 'home_controller.dart';
import 'home_service.dart';

/// Where a home shortcut leads; the shell owns route selection.
enum HomeDestination { story, messages, media, people, settings }

/// «الرئيسية» — a compact local archive dashboard and recent-record feed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.importPageBuilder,
    this.onOpenDestination,
  });

  final WidgetBuilder importPageBuilder;
  final ValueChanged<HomeDestination>? onOpenDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(homeSnapshotProvider);
    return snapshot.when(
      loading: () => const Center(
        key: Key('home-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (_, _) => Center(
        key: const Key('home-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل الأرشيف من هذا الجهاز.'),
              const SizedBox(height: TmSpace.m),
              Wrap(
                spacing: TmSpace.m,
                runSpacing: TmSpace.m,
                children: [
                  OutlinedButton(
                    onPressed: () => ref.invalidate(homeSnapshotProvider),
                    child: const Text('حاول مرة تانية'),
                  ),
                  FilledButton.icon(
                    key: const Key('home-import'),
                    onPressed: () => _openImport(context),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('استيراد بيانات جديدة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      data: (value) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: const Key('home-screen'),
          padding: EdgeInsets.zero,
          children: [
            _HomeOverview(snapshot: value),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TmSize.homeContentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TmSpace.xl,
                    TmSpace.l,
                    TmSpace.xl,
                    TmSpace.xxxl,
                  ),
                  child: constraints.maxWidth < TmSize.homeThreeColumnMinWidth
                      ? _StackedHomeBody(
                          snapshot: value,
                          onImport: () => _openImport(context),
                          onOpenDestination: onOpenDestination,
                        )
                      : _ThreeColumnHomeBody(
                          snapshot: value,
                          onImport: () => _openImport(context),
                          onOpenDestination: onOpenDestination,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImport(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: importPageBuilder));
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-kpi-strip'),
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.xl,
        vertical: TmSpace.m,
      ),
      decoration: const BoxDecoration(
        color: TmColors.card,
        border: Border(bottom: BorderSide(color: TmColors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TmSize.homeContentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final greeting = _Greeting(snapshot: snapshot);
              final metrics = _KpiTiles(snapshot: snapshot);
              if (constraints.maxWidth < TmSize.homeOverviewWrapWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    greeting,
                    const SizedBox(height: TmSpace.m),
                    metrics,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: greeting,
                    ),
                  ),
                  const SizedBox(width: TmSpace.l),
                  metrics,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final events = _formatNumber(snapshot.totals.events);
    final first = snapshot.firstYear;
    final last = snapshot.lastYear;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: TmSize.homeGreetingIcon,
          height: TmSize.homeGreetingIcon,
          decoration: BoxDecoration(
            color: TmColors.primaryTint,
            borderRadius: BorderRadius.circular(TmRadius.card),
          ),
          child: const Icon(
            Icons.article_outlined,
            color: TmColors.primary,
            size: TmSize.homeHeaderIcon,
          ),
        ),
        const SizedBox(width: TmSpace.m),
        // `Flexible` (not `Expanded`) lets the green pill hug the greeting, as
        // in 01-home.jpg, instead of being pushed against the KPI card.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مساء الخير', style: TmType.h1Style),
              const SizedBox(height: TmSpace.xs),
              Text(
                first == null || last == null
                    ? 'عندك $events حكاية محفوظة، والتواريخ غير متاحة'
                    : 'عندك $events حكاية محفوظة من $first لليوم ($last)',
                key: const Key('home-greeting-range'),
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: TmSpace.m),
        const _LocalArchivePill(),
      ],
    );
  }
}

class _LocalArchivePill extends StatelessWidget {
  const _LocalArchivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-local-archive'),
      constraints: const BoxConstraints(minHeight: TmHit.min),
      padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.successTint,
        borderRadius: BorderRadius.circular(TmRadius.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: TmSize.homeStatusDot,
            color: TmColors.success,
          ),
          SizedBox(width: TmSpace.s),
          Text(
            'أرشيف محلي مفتوح',
            style: TextStyle(
              fontSize: TmType.caption,
              fontWeight: FontWeight.w600,
              color: TmColors.success,
              height: TmType.height,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTiles extends StatelessWidget {
  const _KpiTiles({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, int? value})>[
      (label: 'رسالة', value: snapshot.totals.messages),
      (label: 'صور', value: snapshot.totals.photos),
      (label: 'شخص', value: snapshot.totals.people),
      (label: 'سنة', value: snapshot.yearSpan),
    ];
    return Container(
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      padding: const EdgeInsets.all(TmSpace.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            if (index > 0)
              const SizedBox(
                height: TmSize.homeDividerHeight,
                child: VerticalDivider(width: 1, color: TmColors.border),
              ),
            Container(
              constraints: const BoxConstraints(
                minWidth: TmSize.homeKpiMinWidth,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: TmSpace.m,
                vertical: TmSpace.xs,
              ),
              child: Column(
                children: [
                  Text(
                    tiles[index].value == null
                        ? '—'
                        : _formatNumber(tiles[index].value!),
                    key: Key('home-kpi-${tiles[index].label}'),
                    textDirection: TextDirection.ltr,
                    style: TmType.metricStyle,
                  ),
                  Text(tiles[index].label, style: TmType.captionStyle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThreeColumnHomeBody extends StatelessWidget {
  const _ThreeColumnHomeBody({
    required this.snapshot,
    required this.onImport,
    this.onOpenDestination,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onImport;
  final ValueChanged<HomeDestination>? onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _ShortcutsColumn(
            snapshot: snapshot,
            onImport: onImport,
            onOpenDestination: onOpenDestination,
          ),
        ),
        const SizedBox(width: TmSpace.m),
        Expanded(flex: 6, child: _FeedColumn(snapshot: snapshot)),
        const SizedBox(width: TmSpace.m),
        Expanded(
          flex: 3,
          child: _PeopleColumn(
            people: snapshot.topPeople,
            onOpenPeople: onOpenDestination == null
                ? null
                : () => onOpenDestination!(HomeDestination.people),
          ),
        ),
      ],
    );
  }
}

class _StackedHomeBody extends StatelessWidget {
  const _StackedHomeBody({
    required this.snapshot,
    required this.onImport,
    this.onOpenDestination,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onImport;
  final ValueChanged<HomeDestination>? onOpenDestination;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShortcutsColumn(
          snapshot: snapshot,
          onImport: onImport,
          onOpenDestination: onOpenDestination,
        ),
        const SizedBox(height: TmSpace.m),
        _FeedColumn(snapshot: snapshot),
        const SizedBox(height: TmSpace.m),
        _PeopleColumn(
          people: snapshot.topPeople,
          onOpenPeople: onOpenDestination == null
              ? null
              : () => onOpenDestination!(HomeDestination.people),
        ),
      ],
    );
  }
}

class _ShortcutsColumn extends StatelessWidget {
  const _ShortcutsColumn({
    required this.snapshot,
    required this.onImport,
    this.onOpenDestination,
  });

  final HomeSnapshot snapshot;
  final VoidCallback onImport;
  final ValueChanged<HomeDestination>? onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String label, HomeDestination target})>[
      (
        icon: Icons.person_outline,
        label: 'ملفي',
        target: HomeDestination.people,
      ),
      (
        icon: Icons.chat_bubble_outline,
        label: 'الرسائل',
        target: HomeDestination.messages,
      ),
      (
        icon: Icons.image_outlined,
        label: 'الصور',
        target: HomeDestination.media,
      ),
      (
        icon: Icons.auto_awesome_outlined,
        label: 'الذكريات',
        target: HomeDestination.story,
      ),
      (
        icon: Icons.people_outline,
        label: 'الأشخاص',
        target: HomeDestination.people,
      ),
      (
        icon: Icons.settings_outlined,
        label: 'الإعدادات',
        target: HomeDestination.settings,
      ),
    ];
    return Column(
      children: [
        _HomeCard(
          key: const Key('home-shortcuts'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('الاختصارات', style: TmType.h2Style)),
                  Text('تصفح محلي', style: TmType.captionStyle),
                ],
              ),
              const SizedBox(height: TmSpace.m),
              for (final row in rows)
                _ShortcutRow(
                  key: ValueKey('home-shortcut-${row.label}'),
                  icon: row.icon,
                  label: row.label,
                  selected: row.label == 'ملفي',
                  badge: null,
                  onTap: onOpenDestination == null || row.label == 'ملفي'
                      ? null
                      : () => onOpenDestination!(row.target),
                ),
              const Divider(height: TmSpace.xl),
              SizedBox(
                height: TmHit.min,
                child: FilledButton.icon(
                  key: const Key('home-import'),
                  onPressed: onImport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('استيراد بيانات جديدة'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _PrivacyCard(),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? TmColors.primary : TmColors.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      child: Container(
        constraints: const BoxConstraints(minHeight: TmHit.min),
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
        decoration: BoxDecoration(
          color: selected ? TmColors.primaryTint : Colors.transparent,
          borderRadius: BorderRadius.circular(TmRadius.chip),
        ),
        child: Row(
          children: [
            Icon(icon, size: TmSize.homeHeaderIcon, color: color),
            const SizedBox(width: TmSpace.s),
            Expanded(
              child: Text(
                label,
                style: TmType.bodyStyle.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (badge != null)
              Container(
                constraints: const BoxConstraints(minHeight: TmHit.min / 2),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
                decoration: BoxDecoration(
                  color: TmColors.primaryTint,
                  borderRadius: BorderRadius.circular(TmRadius.pill),
                ),
                child: Text(
                  badge!,
                  textDirection: TextDirection.ltr,
                  style: TmType.captionStyle.copyWith(color: TmColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: TmSize.homeHeaderIcon,
            color: TmColors.success,
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Text(
              'الملفات مخزنة ومفهرسة على قرصك الصلب دون حاجة لأي اتصال خارجي. '
              'بياناتك ملكك وحدك.',
              style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn({required this.snapshot});

  final HomeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FeedComposer(),
        const SizedBox(height: TmSpace.m),
        if (snapshot.latest.isEmpty)
          _HomeCard(
            key: const Key('home-activity-empty'),
            child: Text(
              'ما في منشورات محفوظة بعد. استورد بياناتك لتظهر هنا.',
              style: TmType.bodyMuted,
            ),
          )
        else
          for (final event in snapshot.latest) ...[
            _ActivityCard(event: event),
            const SizedBox(height: TmSpace.m),
          ],
        const _LocalReassuranceLine(),
      ],
    );
  }
}

class _FeedComposer extends StatelessWidget {
  const _FeedComposer();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      key: const Key('home-feed-composer'),
      child: Column(
        children: [
          Row(
            children: [
              const _Avatar(initial: 'ه', size: TmSize.homeSmallAvatar),
              const SizedBox(width: TmSpace.s),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: TmHit.min),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
                  decoration: BoxDecoration(
                    color: TmColors.bg,
                    borderRadius: BorderRadius.circular(TmRadius.pill),
                  ),
                  child: Text('شو بدك تشوف اليوم؟', style: TmType.bodyMuted),
                ),
              ),
            ],
          ),
          const Divider(height: TmSpace.xl),
          const Row(
            children: [
              Expanded(
                child: _FeedTab(
                  key: Key('home-feed-tab-messages'),
                  icon: Icons.chat_bubble_outline,
                  label: 'الرسائل',
                  color: TmColors.primary,
                ),
              ),
              Expanded(
                child: _FeedTab(
                  key: Key('home-feed-tab-media'),
                  icon: Icons.image_outlined,
                  label: 'الصور',
                  color: TmColors.success,
                ),
              ),
              Expanded(
                child: _FeedTab(
                  key: Key('home-feed-tab-posts'),
                  icon: Icons.star_border,
                  label: 'المنشورات',
                  color: TmColors.warm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TmHit.min),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: TmSize.homeHeaderIcon, color: color),
          const SizedBox(width: TmSpace.s),
          Text(
            label,
            style: TmType.captionStyle.copyWith(color: TmColors.text),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.event});

  final TimelineRow event;

  @override
  Widget build(BuildContext context) {
    final text = event.textContent?.trim();
    final hasText = text != null && text.isNotEmpty;
    final isPost = event.eventType == 'post';
    return _HomeCard(
      key: ValueKey('home-activity-${event.eventId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 01-home.jpg keeps the platform chip on the title line beside the
          // author, with the date line under it and the menu at the far end.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Avatar(initial: 'ه', size: TmSize.homeAvatar),
              const SizedBox(width: TmSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isPost
                                ? 'منشور محفوظ'
                                : _eventTypeLabel(event.eventType),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TmType.h2Style,
                          ),
                        ),
                        if (isPost) ...[
                          const SizedBox(width: TmSpace.s),
                          const _FacebookBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      '${_formatDate(event.timestampNormalized)} • محفوظ محلياً',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              const Icon(
                Icons.more_horiz,
                size: TmSize.homeHeaderIcon,
                color: TmColors.text2,
              ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          Text(
            hasText
                ? text
                : 'سجل بلا نص محفوظ — ${_eventTypeLabel(event.eventType)}',
            textAlign: TextAlign.right,
            style: TmType.bodyStyle.copyWith(
              color: hasText ? TmColors.text : TmColors.text2,
            ),
          ),
          const SizedBox(height: TmSpace.m),
          const Divider(),
          const Row(
            children: [
              Expanded(
                child: _PostAction(icon: Icons.favorite_border, label: 'إعجاب'),
              ),
              Expanded(
                child: _PostAction(
                  icon: Icons.mode_comment_outlined,
                  label: 'تعليقات',
                ),
              ),
              Expanded(
                child: _PostAction(icon: Icons.reply_outlined, label: 'شارك'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FacebookBadge extends StatelessWidget {
  const _FacebookBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.s,
        vertical: TmSpace.xs,
      ),
      decoration: BoxDecoration(
        color: TmColors.primaryTint,
        borderRadius: BorderRadius.circular(TmRadius.pill),
      ),
      child: Text(
        'فيسبوك',
        style: TmType.captionStyle.copyWith(color: TmColors.primary),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TmHit.min),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: TmSize.homeHeaderIcon, color: TmColors.text2),
          const SizedBox(width: TmSpace.xs),
          Text(label, style: TmType.captionStyle),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: TmColors.primaryTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TmType.captionStyle.copyWith(
          color: TmColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocalReassuranceLine extends StatelessWidget {
  const _LocalReassuranceLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: TmSpace.s),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(minHeight: TmHit.min),
        padding: const EdgeInsets.symmetric(
          horizontal: TmSpace.l,
          vertical: TmSpace.s,
        ),
        decoration: BoxDecoration(
          color: TmColors.card,
          borderRadius: BorderRadius.circular(TmRadius.pill),
          border: Border.all(color: TmColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: TmSize.homeHeaderIcon,
              color: TmColors.success,
            ),
            SizedBox(width: TmSpace.s),
            Flexible(
              child: Text(
                'كل هالشي من ملفك على جهازك — ولا حرف طلع عالإنترنت',
                style: TextStyle(
                  fontSize: TmType.caption,
                  fontWeight: FontWeight.w600,
                  color: TmColors.success,
                  height: TmType.height,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleColumn extends StatelessWidget {
  const _PeopleColumn({required this.people, this.onOpenPeople});

  final List<HomePerson> people;
  final VoidCallback? onOpenPeople;

  @override
  Widget build(BuildContext context) {
    final max = people.fold<int>(
      0,
      (value, person) => person.count > value ? person.count : value,
    );
    return Column(
      children: [
        _HomeCard(
          key: const Key('home-top-people'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'أكثر ناس حكيت معهن',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TmType.h2Style,
                    ),
                  ),
                  const SizedBox(width: TmSpace.s),
                  Text('${people.length} جهات', style: TmType.captionStyle),
                ],
              ),
              const SizedBox(height: TmSpace.l),
              if (people.isEmpty)
                Text('لسا ما في أشخاص مفهرسين.', style: TmType.bodyMuted)
              else
                for (final person in people)
                  Padding(
                    key: ValueKey('home-person-${person.id}'),
                    padding: const EdgeInsets.only(bottom: TmSpace.l),
                    child: _PersonBar(person: person, max: max),
                  ),
              Center(
                child: TextButton(
                  key: const Key('home-see-all-people'),
                  onPressed: onOpenPeople,
                  child: const Text('‹ شوف الكل'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _IndexingNote(),
      ],
    );
  }
}

class _PersonBar extends StatelessWidget {
  const _PersonBar({required this.person, required this.max});

  final HomePerson person;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (person.count / max).clamp(0.0, 1.0);
    return Column(
      key: ValueKey('home-person-row-${person.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TmType.captionStyle.copyWith(
                  color: TmColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: TmSpace.s),
            _Avatar(
              initial: _initial(person.name),
              size: TmSize.homeSmallAvatar,
            ),
          ],
        ),
        const SizedBox(height: TmSpace.xs),
        Text(
          '${_formatNumber(person.count)} رسالة',
          textDirection: TextDirection.rtl,
          style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: TmSpace.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(TmRadius.pill),
          child: SizedBox(
            height: TmSize.homeProgressHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: TmColors.bg),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  // `heightFactor` is required: without it the fill box has no
                  // height and the bar reads as an empty grey track.
                  child: FractionallySizedBox(
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: const ColoredBox(color: TmColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IndexingNote extends StatelessWidget {
  const _IndexingNote();

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: TmSize.homeHeaderIcon,
            color: TmColors.success,
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كل الأسماء والرسائل مقترحة محلياً',
                  style: TmType.captionStyle,
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  'الأسماء والعدادات مستمدة من الأرشيف المستورد على جهازك.',
                  style: TmType.captionStyle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      child: child,
    );
  }
}

String _formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

const List<String> _monthNames = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

String _formatDate(DateTime? value) {
  if (value == null) return 'تاريخ غير معروف';
  final utc = value.toUtc();
  return '${utc.day} ${_monthNames[utc.month - 1]} ${utc.year}';
}

String _eventTypeLabel(String eventType) => switch (eventType) {
  'message' => 'رسالة محفوظة',
  'post' => 'منشور محفوظ',
  'comment' => 'تعليق محفوظ',
  'reaction' => 'تفاعل محفوظ',
  'attachment' => 'مرفق محفوظ',
  _ => importEventLabel(eventType, isRtl: true) ?? 'سجل محفوظ',
};

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}
