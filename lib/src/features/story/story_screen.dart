import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import 'story_controller.dart';
import 'story_service.dart';

/// «قصتك بالأرقام» — the archive told as a few provable numbers.
///
/// Rebuilt from the owner reference
/// `design/reference/user-2026-10-30/02-story.jpg`: the peak-year hero, the
/// yearly columns, the people ranking and the monthly memories in the main
/// column, with the quick numbers, index coverage and local-only note in the
/// side column. Every number is read from the local archive, so a card whose
/// evidence is missing is not drawn instead of being filled with a guess.
class StoryScreen extends ConsumerWidget {
  const StoryScreen({
    super.key,
    required this.importPageBuilder,
    this.onOpenYear,
  });

  /// The existing inspection/import page, opened from the empty state.
  final WidgetBuilder importPageBuilder;

  /// Opens the analytics section with one year selected, when the shell allows
  /// it. The story screen itself knows nothing about the shell.
  final ValueChanged<int>? onOpenYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(storySnapshotProvider);

    return snapshot.when(
      loading: () => const Center(
        key: Key('story-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (_, _) => Center(
        key: const Key('story-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل قصتك من الأرشيف المحلي.'),
              const SizedBox(height: TmSpace.m),
              OutlinedButton(
                onPressed: () => ref.invalidate(storySnapshotProvider),
                child: const Text('حاول مرة تانية'),
              ),
            ],
          ),
        ),
      ),
      data: (value) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: const Key('story-screen'),
          padding: const EdgeInsets.fromLTRB(
            TmSpace.xl,
            TmSpace.l,
            TmSpace.xl,
            TmSpace.xxl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TmSize.storyContentMaxWidth,
                ),
                child: value.isEmpty
                    ? _StoryEmpty(onImport: () => _openImport(context))
                    : constraints.maxWidth < TmSize.storyColumnMinWidth
                    ? _StackedStoryBody(
                        snapshot: value,
                        onOpenYear: onOpenYear,
                      )
                    : _TwoColumnStoryBody(
                        snapshot: value,
                        onOpenYear: onOpenYear,
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

class _TwoColumnStoryBody extends StatelessWidget {
  const _TwoColumnStoryBody({required this.snapshot, this.onOpenYear});

  final StorySnapshot snapshot;
  final ValueChanged<int>? onOpenYear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: TmSize.storyMainFlex,
          child: _StoryMain(snapshot: snapshot, onOpenYear: onOpenYear),
        ),
        const SizedBox(width: TmSpace.m),
        Expanded(
          flex: TmSize.storySideFlex,
          child: _StorySidebar(snapshot: snapshot),
        ),
      ],
    );
  }
}

class _StackedStoryBody extends StatelessWidget {
  const _StackedStoryBody({required this.snapshot, this.onOpenYear});

  final StorySnapshot snapshot;
  final ValueChanged<int>? onOpenYear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoryMain(snapshot: snapshot, onOpenYear: onOpenYear),
        const SizedBox(height: TmSpace.m),
        _StorySidebar(snapshot: snapshot),
      ],
    );
  }
}

class _StoryMain extends StatelessWidget {
  const _StoryMain({required this.snapshot, this.onOpenYear});

  final StorySnapshot snapshot;
  final ValueChanged<int>? onOpenYear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BusiestYearHero(snapshot: snapshot, onOpenYear: onOpenYear),
        const SizedBox(height: TmSpace.m),
        _YearChartCard(snapshot: snapshot),
        const SizedBox(height: TmSpace.m),
        _PeopleCard(people: snapshot.people),
        const SizedBox(height: TmSpace.m),
        _MemoriesCard(
          memories: snapshot.memories,
          month: snapshot.memoryMonth,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: the busiest year.
// ---------------------------------------------------------------------------

class _BusiestYearHero extends StatelessWidget {
  const _BusiestYearHero({required this.snapshot, this.onOpenYear});

  final StorySnapshot snapshot;
  final ValueChanged<int>? onOpenYear;

  @override
  Widget build(BuildContext context) {
    final year = snapshot.busiestYear;
    final totals = snapshot.busiestTotals;
    final average = snapshot.busiestDailyAverage;

    return _StoryCard(
      key: const Key('story-hero'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  year == null
                      ? 'لسا ما في سنة مؤرخة تحكي قصتك'
                      : 'سنة $year كانت أكثر سنة حكيت فيها',
                  key: const Key('story-hero-year'),
                  style: TmType.h1Style,
                ),
              ),
              const SizedBox(width: TmSpace.s),
              const _StoryChip(
                label: 'سنة الذروة',
                icon: Icons.star_border,
                tone: _ChipTone.warm,
              ),
            ],
          ),
          if (year != null && totals != null) ...[
            const SizedBox(height: TmSpace.m),
            Container(
              padding: const EdgeInsets.all(TmSpace.m),
              decoration: BoxDecoration(
                color: TmColors.warmTint,
                borderRadius: BorderRadius.circular(TmRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: TmSize.storyHeroIconBox,
                    height: TmSize.storyHeroIconBox,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: TmColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: TmSize.storyIcon,
                      color: TmColors.warm,
                    ),
                  ),
                  const SizedBox(width: TmSpace.m),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatNumber(totals.messages),
                        key: const Key('story-hero-messages'),
                        textDirection: TextDirection.ltr,
                        style: TmType.displayStyle,
                      ),
                      Text(
                        'رسالة مسجلة خلال ${_formatNumber(totals.days)} يوم',
                        style: TmType.captionStyle.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          average == null
                              ? 'سنة على رأس كل سنينك'
                              : 'بمعدل ${_formatNumber(average)} رسالة كل يوم',
                          key: const Key('story-hero-daily'),
                          style: TmType.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: TmSpace.xs),
                        Text(
                          'محسوبة من محادثاتك المؤرشفة على هذا الجهاز.',
                          style: TmType.captionStyle.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TmSpace.s),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'محسوبة من ${_formatNumber(totals.events)} حدث مؤرّخ',
                    key: const Key('story-hero-total'),
                    style: TmType.captionStyle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                SizedBox(
                  height: TmHit.min,
                  child: TextButton(
                    key: const Key('story-hero-open-year'),
                    onPressed: onOpenYear == null
                        ? null
                        : () => onOpenYear!(year),
                    child: const Text('‹ شوف السنة بالتحليلات'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages per year.
// ---------------------------------------------------------------------------

class _YearChartCard extends StatelessWidget {
  const _YearChartCard({required this.snapshot});

  final StorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final years = snapshot.years;
    final total = years.fold<int>(0, (value, year) => value + year.count);
    final max = years.fold<int>(
      0,
      (value, year) => year.count > value ? year.count : value,
    );
    final ranked = [...years]..sort((a, b) => b.count.compareTo(a.count));
    final rankOf = {
      for (var index = 0; index < ranked.length; index++)
        ranked[index].year: index,
    };

    return _StoryCard(
      key: const Key('story-year-bars'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رسائلك على السنين', style: TmType.h2Style),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      'كل سنة من سنوات أرشيفك بعمود واحد، من الأقدم لليمين.',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              _StoryChip(
                label: '${years.length} سنة',
                tone: _ChipTone.muted,
              ),
            ],
          ),
          const SizedBox(height: TmSpace.l),
          if (years.isEmpty)
            Text('ما في رسائل مؤرخة بعد.', style: TmType.bodyMuted)
          else
            SizedBox(
              height: TmSize.storyChartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Oldest first inside the RTL row: the oldest year sits on
                  // the right and the newest on the left, as in the reference.
                  for (final year in years)
                    Expanded(
                      child: _YearBar(
                        year: year,
                        max: max,
                        rank: rankOf[year.year] ?? 0,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: TmSpace.m),
          const Divider(),
          const SizedBox(height: TmSpace.s),
          Row(
            children: [
              Text(
                'المجموع: ${_formatNumber(total)} رسالة',
                key: const Key('story-year-total'),
                style: TmType.captionStyle,
              ),
              const Spacer(),
              Text(
                'سلسلة ممتدة عبر ${years.length} سنة',
                style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _YearBar extends StatelessWidget {
  const _YearBar({required this.year, required this.max, required this.rank});

  final StoryYear year;
  final int max;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (year.count / max).clamp(0.0, 1.0);
    final color = rank == 0
        ? TmColors.warm
        : rank <= 2
        ? TmColors.primarySoft
        : TmColors.border;

    return Padding(
      key: ValueKey('story-year-${year.year}'),
      padding: const EdgeInsets.symmetric(horizontal: TmSize.hairline),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank <= 2)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatNumber(year.count),
                textDirection: TextDirection.ltr,
                style: TmType.captionStyle.copyWith(
                  color: TmColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: TmType.caption * TmType.height),
          const SizedBox(height: TmSpace.xs),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio,
                child: Container(
                  width: TmSize.storyBarWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TmRadius.chip),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TmSpace.xs),
          Text(
            '${year.year % 100}'.padLeft(2, '0'),
            textDirection: TextDirection.ltr,
            style: TmType.captionStyle.copyWith(
              color: rank <= 2 ? TmColors.text : TmColors.text2,
              fontWeight: rank == 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// People talked to most.
// ---------------------------------------------------------------------------

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.people});

  final List<StoryPerson> people;

  @override
  Widget build(BuildContext context) {
    final max = people.fold<int>(
      0,
      (value, person) => person.count > value ? person.count : value,
    );

    return _StoryCard(
      key: const Key('story-people'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مع مين كنت تحكي', style: TmType.h2Style),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      'أكثر الأشخاص اللي تواصلت معهم، بعدد رسائل محفوظ '
                      'على جهازك.',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              _StoryChip(
                label: 'أكثر جهات تواصل',
                tone: _ChipTone.muted,
              ),
            ],
          ),
          const SizedBox(height: TmSpace.l),
          if (people.isEmpty)
            Text('ما في رسائل مربوطة بأشخاص بعد.', style: TmType.bodyMuted)
          else
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(bottom: TmSpace.l),
                child: _PersonRow(person: person, max: max),
              ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.max});

  final StoryPerson person;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (person.count / max).clamp(0.0, 1.0);

    return Row(
      key: ValueKey('story-person-${person.id}'),
      children: [
        _Avatar(initial: _initial(person.name)),
        const SizedBox(width: TmSpace.s),
        Flexible(
          flex: 3,
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
        const SizedBox(width: TmSpace.m),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TmRadius.pill),
            child: SizedBox(
              height: TmSize.storyProgressHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: TmColors.bg),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: ratio,
                      child: const ColoredBox(color: TmColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: TmSpace.m),
        Text(
          '${_formatNumber(person.count)} رسالة',
          style: TmType.captionStyle,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly memories.
// ---------------------------------------------------------------------------

class _MemoriesCard extends StatelessWidget {
  const _MemoriesCard({required this.memories, required this.month});

  final List<StoryMemory> memories;
  final int? month;

  @override
  Widget build(BuildContext context) {
    final monthName = month == null ? null : _monthNames[month! - 1];

    return _StoryCard(
      key: const Key('story-memories'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: TmSize.storyDot,
                          color: TmColors.warm,
                        ),
                        const SizedBox(width: TmSpace.s),
                        Flexible(
                          child: Text(
                            monthName == null
                                ? 'ذكريات من أرشيفك'
                                : 'ذكريات $monthName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TmType.h2Style,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      'صور محفوظة على جهازك من نفس الشهر، بلا أي رفع.',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              _StoryChip(
                label: 'من أرشيفك المصوّر',
                tone: _ChipTone.muted,
              ),
            ],
          ),
          const SizedBox(height: TmSpace.l),
          if (memories.isEmpty)
            Text(
              'ما في صور مؤرخة بهذا الأرشيف بعد.',
              style: TmType.bodyMuted,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < memories.length; index++) ...[
                  if (index > 0) const SizedBox(width: TmSpace.m),
                  Expanded(child: _MemoryTile(memory: memories[index])),
                ],
              ],
            ),
          const SizedBox(height: TmSpace.s),
          const Divider(),
          const SizedBox(height: TmSpace.s),
          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: TmSize.storyIcon,
                color: TmColors.text2,
              ),
              const SizedBox(width: TmSpace.xs),
              Expanded(
                child: Text(
                  'الصور تُقرأ من مجلدك المحلي فقط',
                  style: TmType.captionStyle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                '${memories.length} صورة',
                style: TmType.captionStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final StoryMemory memory;

  @override
  Widget build(BuildContext context) {
    final at = memory.at.toUtc();

    return Column(
      key: ValueKey('story-memory-${memory.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: TmSize.storyMemoryHeight,
          decoration: BoxDecoration(
            color: TmColors.bg,
            borderRadius: BorderRadius.circular(TmRadius.card),
            border: Border.all(color: TmColors.border),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image_outlined,
                      size: TmSize.storyHeroIconBox / 2,
                      color: TmColors.text2,
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      _mediaLabel(memory.mediaType),
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                bottom: TmSpace.s,
                end: TmSpace.s,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TmSpace.s,
                    vertical: TmSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: TmColors.card,
                    borderRadius: BorderRadius.circular(TmRadius.pill),
                    border: Border.all(color: TmColors.border),
                  ),
                  child: Text(
                    'محفوظة محلياً',
                    style: TmType.captionStyle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.s),
        Row(
          children: [
            Text(
              _formatDate(at),
              textDirection: TextDirection.ltr,
              style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
            ),
            const Spacer(),
            Text(
              _monthNames[at.month - 1],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TmType.captionStyle,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar: quick numbers, coverage, local-only note.
// ---------------------------------------------------------------------------

class _StorySidebar extends StatelessWidget {
  const _StorySidebar({required this.snapshot});

  final StorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final first = snapshot.firstYear;
    final last = snapshot.lastYear;
    final month = snapshot.busiestMonth;
    final average = snapshot.dailyAverage;

    return Column(
      children: [
        _StoryCard(
          key: const Key('story-quick-numbers'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('أرقام سريعة', style: TmType.h2Style),
                  ),
                  const _StoryChip(
                    label: 'إحصاء شامل',
                    tone: _ChipTone.muted,
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.m),
              _QuickStat(
                label: 'أول رسالة',
                value: first == null ? 'بلا تاريخ' : '$first',
              ),
              _QuickStat(
                label: 'آخر رسالة',
                value: last == null ? 'بلا تاريخ' : '$last',
              ),
              _QuickStat(
                label: 'أطول محادثة',
                value: snapshot.longestConversationCount == null
                    ? '—'
                    : '${_formatNumber(snapshot.longestConversationCount!)} رسالة',
              ),
              _QuickStat(
                label: 'أكثر شهر',
                value: month == null ? '—' : _monthNames[month - 1],
              ),
              _QuickStat(
                label: 'المعدل اليومي',
                value: average == null
                    ? '—'
                    : '${_formatNumber(average)} رسالة/اليوم',
              ),
              _QuickStat(
                label: 'أنواع السجلات',
                value: '${snapshot.recordTypes} أنواع',
                last: true,
              ),
              const Divider(),
              const SizedBox(height: TmSpace.s),
              Text(
                'تُحدَّث هذه الأرقام من مجلدك المحلي بمجرد فتح الأرشيف.',
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        _StoryCard(
          key: const Key('story-coverage'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('تغطية الأرشيف', style: TmType.h2Style),
                  ),
                  Text(
                    '${snapshot.coveragePercent}%',
                    key: const Key('story-coverage-percent'),
                    textDirection: TextDirection.ltr,
                    style: TmType.captionStyle.copyWith(
                      color: TmColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.s),
              ClipRRect(
                borderRadius: BorderRadius.circular(TmRadius.pill),
                child: LinearProgressIndicator(
                  key: const Key('story-coverage-bar'),
                  value: snapshot.coveragePercent / 100,
                  minHeight: TmSize.storyStatusBarHeight,
                  backgroundColor: TmColors.bg,
                  color: TmColors.success,
                ),
              ),
              const SizedBox(height: TmSpace.m),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'التغطية الإجمالية',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatNumber(snapshot.datedEvents)} حدث مفهرس',
                    style: TmType.captionStyle,
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'سجلات بلا تاريخ',
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatNumber(snapshot.undatedEvents)} سجل',
                    style: TmType.captionStyle,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _LocalOnlyCard(),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('story-stat-$label'),
      padding: EdgeInsets.only(bottom: last ? 0 : TmSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TmType.captionStyle.copyWith(
                color: TmColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalOnlyCard extends StatelessWidget {
  const _LocalOnlyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('story-local-only'),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.successTint,
        borderRadius: BorderRadius.circular(TmRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: TmSize.storyIcon,
            color: TmColors.success,
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كل الأرقام محسوبة على جهازك',
                  style: TmType.captionStyle.copyWith(
                    color: TmColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  'لا يوجد أي اتصال شبكي ولا إرسال؛ الأرشيف والنسخ '
                  'الاحتياطي مكانها عندك.',
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

// ---------------------------------------------------------------------------
// Empty archive.
// ---------------------------------------------------------------------------

class _StoryEmpty extends StatelessWidget {
  const _StoryEmpty({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return _StoryCard(
      key: const Key('story-empty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ما في أرقام بعد', style: TmType.h1Style),
          const SizedBox(height: TmSpace.s),
          Text(
            'استورد نسخة بياناتك لتبلش تشوف سنينك بالأرقام: أكثر سنة حكيت فيها، '
            'والناس اللي كنت معهم، والكلمات اللي تكررت أكتر.',
            style: TmType.bodyMuted,
          ),
          const SizedBox(height: TmSpace.l),
          SizedBox(
            height: TmHit.min,
            child: FilledButton.icon(
              key: const Key('story-empty-import'),
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('استيراد بيانات جديدة'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared.
// ---------------------------------------------------------------------------

enum _ChipTone { warm, muted }

/// Small pill used for the reference's corner labels.
class _StoryChip extends StatelessWidget {
  const _StoryChip({required this.label, required this.tone, this.icon});

  final String label;
  final _ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final background = tone == _ChipTone.warm
        ? TmColors.warmTint
        : TmColors.bg;
    final foreground = tone == _ChipTone.warm
        ? TmColors.warm
        : TmColors.text2;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.s,
        vertical: TmSpace.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TmRadius.pill),
        border: Border.all(color: TmColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: TmType.caption, color: foreground),
            const SizedBox(width: TmSpace.xs),
          ],
          Text(
            label,
            style: TmType.captionStyle.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TmSize.storyAvatar,
      height: TmSize.storyAvatar,
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TmSpace.l),
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

String _formatDate(DateTime value) {
  return '${value.day} ${_monthNames[value.month - 1]} ${value.year}';
}

String _mediaLabel(String mediaType) => switch (mediaType) {
  'image' => 'صورة محفوظة',
  'video' => 'فيديو محفوظ',
  'audio' => 'صوت محفوظ',
  _ => 'مرفق محفوظ',
};

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}
