import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tm_motion.dart';
import '../../core/design/tokens.dart';
import 'analytics_controller.dart';
import 'analytics_service.dart';

/// «التحليلات» — the deep read of the archive, filtered by year.
///
/// Rebuilt from the owner reference
/// `design/reference/user-2026-10-30/03-analytics.jpg`: the year filter strip,
/// four indicator cards, messages per month, the hours the user talks, the
/// share breakdown beside the words ranking, and the local-only footer. Counts
/// and percentages are computed from the local rows only; a filter with no
/// rows says so instead of drawing a zero chart as if it were data.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({
    super.key,
    this.importPageBuilder,
    this.onOpenSection,
  });

  /// فتح صفحة الاستيراد من عمود «الاختصارات»؛ تُحقن من الهيكل.
  final WidgetBuilder? importPageBuilder;

  /// اسم القسم المطلوب من اختصارات الشاشة (home/story/…)، والشاشة لا تعرف
  /// الهيكل بل تُمرّر الاسم فقط.
  final ValueChanged<String>? onOpenSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(analyticsSnapshotProvider);

    return snapshot.when(
      loading: () => const Center(
        key: Key('analytics-loading'),
        child: TmLoader(),
      ),
      error: (_, _) => Center(
        key: const Key('analytics-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل التحليلات من الأرشيف المحلي.'),
              const SizedBox(height: TmSpace.m),
              OutlinedButton(
                onPressed: () => ref.invalidate(analyticsSnapshotProvider),
                child: const Text('حاول مرة تانية'),
              ),
            ],
          ),
        ),
      ),
      data: (value) => ListView(
        key: const Key('analytics-screen'),
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
                maxWidth: TmSize.analyticsContentMaxWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final main = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _YearFilterCard(snapshot: value),
                      const SizedBox(height: TmSpace.m),
                      if (value.isEmpty)
                        _AnalyticsEmpty(
                          selectedYear: value.selectedYear,
                          onShowAll: () => ref
                              .read(analyticsYearProvider.notifier)
                              .select(null),
                        )
                      else ...[
                        _KpiStrip(snapshot: value),
                        const SizedBox(height: TmSpace.m),
                        _MonthlyCard(snapshot: value),
                        const SizedBox(height: TmSpace.m),
                        _HourlyCard(snapshot: value),
                        const SizedBox(height: TmSpace.m),
                        _BottomCards(snapshot: value),
                        const SizedBox(height: TmSpace.m),
                        const _LocalOnlyFooter(),
                      ],
                    ],
                  );

                  // 03-analytics.jpg keeps its shortcuts rail on the right of
                  // the charts; below the three-column width the rail is
                  // dropped so the charts stay readable.
                  if (constraints.maxWidth < TmSize.analyticsColumnMinWidth) {
                    return main;
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: TmSize.analyticsSideFlex,
                        child: _AnalyticsShortcuts(
                          snapshot: value,
                          onOpenSection: onOpenSection,
                          onImport: importPageBuilder == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: importPageBuilder!,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: TmSpace.m),
                      Expanded(flex: TmSize.analyticsMainFlex, child: main),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Year filter.
// ---------------------------------------------------------------------------

class _YearFilterCard extends ConsumerWidget {
  const _YearFilterCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The reference shows the three newest years beside «كل السنوات»; the
    // snapshot keeps five so a deep archive still offers older filters.
    final years = snapshot.years.reversed
        .take(3)
        .toList(growable: false);

    return _AnalyticsCard(
      key: const Key('analytics-filters'),
      // The reference draws one row: label and chips at the start, then the
      // evidence line pinned to the far end with its info glyph after it.
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: TmSpace.s,
              runSpacing: TmSpace.s,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('تصفية بالسنة:', style: TmType.captionStyle),
                const SizedBox(width: TmSpace.xs),
                _FilterChip(
                  key: const Key('analytics-year-all'),
                  label: 'كل السنوات',
                  selected: snapshot.selectedYear == null,
                  onTap: () =>
                      ref.read(analyticsYearProvider.notifier).select(null),
                ),
                for (final year in years)
                  _FilterChip(
                    key: Key('analytics-year-$year'),
                    label: '$year',
                    selected: snapshot.selectedYear == year,
                    onTap: () =>
                        ref.read(analyticsYearProvider.notifier).select(year),
                  ),
              ],
            ),
          ),
          const SizedBox(width: TmSpace.m),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TmSize.analyticsEvidenceMaxWidth,
            ),
            child: Text(
              'الأرقام محسوبة من '
              '${_formatNumber(snapshot.totals.events)} حدث على جهازك',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: TmSpace.xs),
          const Icon(
            Icons.info_outline,
            size: TmSize.analyticsIcon,
            color: TmColors.text2,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TmColors.primary : TmColors.card,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? TmColors.primary : TmColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        // The chip hugs its label: a `Container` with an alignment would stretch
        // to the whole `Wrap` width and stack the years into a column.
        child: Container(
          constraints: const BoxConstraints(minHeight: TmHit.min),
          padding: const EdgeInsets.symmetric(horizontal: TmSpace.l),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: TmType.captionStyle.copyWith(
                color: selected ? TmColors.card : TmColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Indicator cards.
// ---------------------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final kpis = <({
      Key key,
      IconData icon,
      Color iconColor,
      Color iconTint,
      String label,
      String value,
      String? unit,
    })>[
      (
        key: const Key('analytics-kpi-longest'),
        icon: Icons.chat_bubble_outline,
        iconColor: TmColors.primary,
        iconTint: TmColors.primaryTint,
        label: 'أطول محادثة',
        value: snapshot.longestConversationCount == null
            ? '—'
            : _formatNumber(snapshot.longestConversationCount!),
        unit: 'رسالة',
      ),
      (
        key: const Key('analytics-kpi-daily'),
        icon: Icons.access_time,
        iconColor: TmColors.warm,
        iconTint: TmColors.warmTint,
        label: 'المعدل اليومي',
        value: snapshot.dailyAverage == null
            ? '—'
            : _formatNumber(snapshot.dailyAverage!),
        unit: 'رسالة/يوم',
      ),
      (
        key: const Key('analytics-kpi-year'),
        icon: Icons.star_border,
        iconColor: TmColors.warm,
        iconTint: TmColors.warmTint,
        label: 'أكثر سنة',
        value: snapshot.busiestYear == null ? '—' : '${snapshot.busiestYear}',
        unit: null,
      ),
      (
        key: const Key('analytics-kpi-types'),
        icon: Icons.insert_drive_file_outlined,
        iconColor: TmColors.text2,
        iconTint: TmColors.bg,
        label: 'أنواع السجلات',
        value: '${snapshot.recordTypeCount}',
        unit: 'أنواع',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < TmSize.analyticsKpiWrapWidth
            ? 2
            : kpis.length;
        final width =
            (constraints.maxWidth - TmSpace.m * (columns - 1)) / columns;
        return Wrap(
          spacing: TmSpace.m,
          runSpacing: TmSpace.m,
          children: [
            for (final kpi in kpis)
              SizedBox(
                width: width,
                child: _KpiCard(
                  key: kpi.key,
                  icon: kpi.icon,
                  iconColor: kpi.iconColor,
                  iconTint: kpi.iconTint,
                  label: kpi.label,
                  value: kpi.value,
                  unit: kpi.unit,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconTint;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: TmSize.analyticsKpiHeight,
        minWidth: TmSize.analyticsKpiMinWidth,
      ),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TmType.captionStyle),
                const SizedBox(height: TmSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: TmType.metricStyle,
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: TmSpace.xs),
                      Text(unit!, style: TmType.captionStyle),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Container(
            width: TmSize.analyticsKpiIcon,
            height: TmSize.analyticsKpiIcon,
            decoration: BoxDecoration(
              color: iconTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: TmSize.analyticsIcon, color: iconColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages per month.
// ---------------------------------------------------------------------------

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final busiest = snapshot.busiestMonth;
    final total = snapshot.months.fold<int>(0, (sum, month) => sum + month.count);
    final ranked = [...snapshot.months]
      ..sort((a, b) => b.count.compareTo(a.count));
    final rankOf = {
      for (var index = 0; index < ranked.length; index++)
        ranked[index].month: index,
    };

    return _AnalyticsCard(
      key: const Key('analytics-months'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'رسائلك حسب الشهر',
            subtitle: 'توزيع رسائلك على أشهر السنة ضمن الفترة المختارة.',
            chip: busiest == null
                ? 'لا ذروة'
                : 'أعلى شهر: ${_monthNames[busiest - 1]} – '
                      '${_formatNumber(snapshot.monthMax)} رسالة',
            tone: _PillTone.warm,
          ),
          const SizedBox(height: TmSpace.l),
          _BarChart(
            max: snapshot.monthMax,
            bars: [
              for (final month in snapshot.months)
                _BarSpec(
                  key: Key('analytics-month-${month.month}'),
                  value: month.count,
                  label: _monthShort[month.month - 1],
                  color: _rankColor(rankOf[month.month] ?? 0),
                  showValue: (rankOf[month.month] ?? 0) <= 2 && month.count > 0,
                ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          const Divider(),
          const SizedBox(height: TmSpace.s),
          Text(
            'المجموع: ${_formatNumber(total)} رسالة',
            key: const Key('analytics-month-total'),
            style: TmType.captionStyle,
          ),
        ],
      ),
    );
  }
}

Color _rankColor(int rank) {
  if (rank == 0) return TmColors.primary;
  if (rank <= 2) return TmColors.primarySoft;
  return TmColors.border;
}

// ---------------------------------------------------------------------------
// Hours.
// ---------------------------------------------------------------------------

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final peak = snapshot.busiestHour;

    return _AnalyticsCard(
      key: const Key('analytics-hours'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'أي ساعة بتتكي أكثر',
            subtitle: 'نمط ساعاتك موزّع على مدار 24 ساعة.',
            chip: peak == null
                ? 'لا ذروة'
                : 'ذروة اليوم: ${_hourLabel(peak)} – '
                      '${_formatNumber(snapshot.hourMax)} رسالة',
            tone: _PillTone.warm,
          ),
          const SizedBox(height: TmSpace.l),
          _BarChart(
            max: snapshot.hourMax,
            bars: [
              for (final hour in snapshot.hours)
                _BarSpec(
                  key: Key('analytics-hour-${hour.hour}'),
                  value: hour.count,
                  // Labelling every hour would be unreadable; every third hour
                  // carries a label and all 24 bars stay in place.
                  label: hour.hour % 3 == 0 ? _hourLabel(hour.hour) : '',
                  color: hour.hour == peak
                      ? TmColors.warm
                      : TmColors.border,
                  showValue: hour.hour == peak && hour.count > 0,
                ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          const Divider(),
          const SizedBox(height: TmSpace.s),
          Text(
            'أربع وعشرون ساعة بتوقيت UTC، كما يخزّنها الأرشيف.',
            style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Words and shares, side by side in the reference.
// ---------------------------------------------------------------------------

class _BottomCards extends StatelessWidget {
  const _BottomCards({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final words = _WordsCard(snapshot: snapshot);
    final shares = _SharesCard(snapshot: snapshot);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The words and shares cards sit side by side beside the rail, as they
        // do in 03-analytics.jpg; only a genuinely narrow column stacks them.
        if (constraints.maxWidth < TmSize.analyticsBottomWrapWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              words,
              const SizedBox(height: TmSpace.m),
              shares,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: words),
            const SizedBox(width: TmSpace.m),
            Expanded(child: shares),
          ],
        );
      },
    );
  }
}

class _WordsCard extends StatelessWidget {
  const _WordsCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final terms = snapshot.terms;
    final max = terms.fold<int>(
      0,
      (value, term) => term.occurrences > value ? term.occurrences : value,
    );

    return _AnalyticsCard(
      key: const Key('analytics-words'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'أكثر الكلمات اللي كتبتها',
            subtitle: 'من فهرس البحث المحلي، بلا أي إرسال.',
            chip: 'مرتبة تنازلياً',
          ),
          const SizedBox(height: TmSpace.l),
          if (terms.isEmpty)
            Text('ما في كلمات مفهرسة بعد.', style: TmType.bodyMuted)
          else
            for (var index = 0; index < terms.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: TmSpace.m),
                child: _WordRow(
                  rank: index + 1,
                  term: terms[index],
                  max: max,
                ),
              ),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.rank, required this.term, required this.max});

  final int rank;
  final AnalyticsTerm term;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (term.occurrences / max).clamp(0.0, 1.0);
    final color = rank == 1
        ? TmColors.warm
        : rank <= 3
        ? TmColors.primary
        : TmColors.primarySoft;

    return Column(
      key: ValueKey('analytics-word-${term.term}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '#$rank',
              textDirection: TextDirection.ltr,
              style: TmType.captionStyle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: TmSpace.s),
            Expanded(
              child: Text(
                term.term,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TmType.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: TmSpace.s),
            Text(
              _formatNumber(term.occurrences),
              textDirection: TextDirection.ltr,
              style: TmType.captionStyle.copyWith(color: TmColors.text),
            ),
          ],
        ),
        const SizedBox(height: TmSpace.xs),
        _Track(fraction: ratio, color: color),
      ],
    );
  }
}

class _SharesCard extends StatelessWidget {
  const _SharesCard({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final shares = snapshot.shareTypes;
    final total = snapshot.shareTotal;

    return _AnalyticsCard(
      key: const Key('analytics-shares'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            title: 'شو أكثر شي بتشارك',
            subtitle: 'كل ما نشرته وتفاعلت معه، بلا الرسائل.',
            chip: '${shares.length} فئات',
          ),
          const SizedBox(height: TmSpace.l),
          if (shares.isEmpty)
            Text('ما في مشاركات محفوظة بعد.', style: TmType.bodyMuted)
          else
            for (final type in shares)
              Padding(
                padding: const EdgeInsets.only(bottom: TmSpace.m),
                child: _ShareRow(type: type, total: total),
              ),
          const SizedBox(height: TmSpace.xs),
          const Divider(),
          const SizedBox(height: TmSpace.s),
          Text(
            'إجمالي المشاركات: ${_formatNumber(total)}',
            key: const Key('analytics-share-total'),
            style: TmType.captionStyle,
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.type, required this.total});

  final AnalyticsType type;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : type.count / total;
    final percent = (share * 100).round();

    return Column(
      key: ValueKey('analytics-share-${type.type}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              _eventTypeIcon(type.type),
              size: TmSize.analyticsIcon,
              color: TmColors.text2,
            ),
            const SizedBox(width: TmSpace.s),
            Expanded(
              child: Text(
                _eventTypeLabel(type.type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TmType.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: TmSpace.s),
            Text(
              '${_formatNumber(type.count)} ($percent%)',
              key: ValueKey('analytics-share-count-${type.type}'),
              textDirection: TextDirection.ltr,
              style: TmType.captionStyle,
            ),
          ],
        ),
        const SizedBox(height: TmSpace.xs),
        _Track(fraction: share.clamp(0.0, 1.0), color: TmColors.primary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Local-only footer.
// ---------------------------------------------------------------------------

class _LocalOnlyFooter extends StatelessWidget {
  const _LocalOnlyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('analytics-local-footer'),
      constraints: const BoxConstraints(minHeight: TmSize.analyticsFooterMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.m,
        vertical: TmSpace.s,
      ),
      decoration: BoxDecoration(
        color: TmColors.successTint,
        borderRadius: BorderRadius.circular(TmRadius.card),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: TmSize.analyticsIcon,
            color: TmColors.success,
          ),
          const SizedBox(width: TmSpace.s),
          const Expanded(
            child: Text(
              'كل بياناتك مخزّنة ومفهرسة محلياً في SQLite على قرصك الصلب — '
              'بلا اتصال بأي خادم سحابي.',
              style: TextStyle(
                fontSize: TmType.caption,
                fontWeight: FontWeight.w600,
                height: TmType.height,
                color: TmColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits.
// ---------------------------------------------------------------------------

class _BarSpec {
  const _BarSpec({
    required this.key,
    required this.value,
    required this.label,
    required this.color,
    required this.showValue,
  });

  final Key key;
  final int value;
  final String label;
  final Color color;
  final bool showValue;
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars, required this.max});

  final List<_BarSpec> bars;
  final int max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TmSize.analyticsChartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(child: _BarColumn(key: bar.key, spec: bar, max: max)),
        ],
      ),
    );
  }
}

/// One column of a bar chart: value above, bar filling the remaining height,
/// label underneath. The bar grows with [max], never past the card.
class _BarColumn extends StatelessWidget {
  const _BarColumn({super.key, required this.spec, required this.max});

  final _BarSpec spec;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 || spec.value == 0
        ? 0.0
        : (spec.value / max).clamp(0.02, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TmSize.hairline),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: TmType.caption * TmType.height,
            child: spec.showValue
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatNumber(spec.value),
                      textDirection: TextDirection.ltr,
                      style: TmType.captionStyle.copyWith(
                        color: TmColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: TmSpace.xs),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio,
                child: Container(
                  width: TmSize.analyticsBarWidth,
                  decoration: BoxDecoration(
                    color: spec.color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TmRadius.chip),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TmSpace.xs),
          SizedBox(
            height: TmType.caption * TmType.height,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                spec.label,
                textDirection: TextDirection.rtl,
                style: TmType.captionStyle.copyWith(
                  color: spec.color == TmColors.border
                      ? TmColors.text2
                      : TmColors.text,
                  fontWeight: spec.color == TmColors.border
                      ? FontWeight.w400
                      : FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded progress track shared by the words and shares lists.
class _Track extends StatelessWidget {
  const _Track({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TmRadius.pill),
      child: SizedBox(
        height: TmSize.analyticsProgressHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: TmColors.bg),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PillTone { warm, neutral }

/// Small pill for the reference's corner labels.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.tone = _PillTone.neutral});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final background = tone == _PillTone.warm
        ? TmColors.warmTint
        : TmColors.bg;
    final foreground = tone == _PillTone.warm
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
      child: Text(
        label,
        style: TmType.captionStyle.copyWith(color: foreground),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.subtitle,
    required this.chip,
    this.tone = _PillTone.neutral,
  });

  final String title;
  final String subtitle;
  final String chip;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TmType.h2Style),
              const SizedBox(height: TmSpace.xs),
              Text(
                subtitle,
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: TmSpace.s),
        _Pill(label: chip, tone: tone),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({super.key, required this.child});

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

// ---------------------------------------------------------------------------
// Shortcuts rail — the right column of 03-analytics.jpg.
// ---------------------------------------------------------------------------

/// صفوف العمود الأيمن بترتيب الصورة. «ملفي» و«الرئيسية» بلا رقم، والرسائل
/// والصور والأشخاص بأعداد القراءة الحقيقية.
const List<({String label, IconData icon, String section})> _railRows = [
  (label: 'ملفي', icon: Icons.person_outline, section: 'people'),
  (label: 'الرئيسية', icon: Icons.home_outlined, section: 'home'),
  (label: 'قصتك بالأرقام', icon: Icons.bar_chart, section: 'story'),
  (label: 'التحليلات', icon: Icons.insights, section: 'analytics'),
  (label: 'الرسائل', icon: Icons.forum_outlined, section: 'messages'),
  (label: 'الصور', icon: Icons.image_outlined, section: 'media'),
  (label: 'الأشخاص', icon: Icons.people_outline, section: 'people'),
  (label: 'الإعدادات', icon: Icons.settings_outlined, section: 'settings'),
];

class _AnalyticsShortcuts extends StatelessWidget {
  const _AnalyticsShortcuts({
    required this.snapshot,
    required this.onOpenSection,
    required this.onImport,
  });

  final AnalyticsSnapshot snapshot;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback? onImport;

  /// «ملفي» and «الأشخاص» open the same section, so the count hangs on the
  /// label the reference puts it beside, not on the destination.
  String? _badgeOf(String label) => switch (label) {
    'الرسائل' => _formatNumber(snapshot.totals.messages),
    'الصور' => _formatNumber(snapshot.totals.photos),
    'الأشخاص' => _formatNumber(snapshot.totals.people),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnalyticsCard(
          key: const Key('analytics-shortcuts'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'الاختصارات',
                    style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: TmSpace.s),
                  Container(
                    key: const Key('analytics-shortcut-account'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TmSpace.s,
                      vertical: TmSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: TmColors.bg,
                      borderRadius: BorderRadius.circular(TmRadius.chip),
                    ),
                    child: Text(
                      _formatNumber(snapshot.totals.events),
                      textDirection: TextDirection.ltr,
                      style: TmType.captionStyle.copyWith(
                        color: TmColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.s),
              const Divider(height: TmSize.hairline),
              const SizedBox(height: TmSpace.s),
              for (final entry in _railRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: TmSpace.xs),
                  child: _AnalyticsShortcutRow(
                    key: ValueKey('analytics-shortcut-${entry.label}'),
                    label: entry.label,
                    icon: entry.icon,
                    selected: entry.section == 'analytics',
                    badge: _badgeOf(entry.label),
                    onTap: onOpenSection == null
                        ? null
                        : () => onOpenSection!(entry.section),
                  ),
                ),
              const SizedBox(height: TmSpace.s),
              const Divider(height: TmSize.hairline),
              const SizedBox(height: TmSpace.m),
              SizedBox(
                height: TmHit.min,
                child: FilledButton.icon(
                  key: const Key('analytics-import'),
                  onPressed: onImport,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(
                    'استيراد بيانات جديدة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TmType.bodyStyle.copyWith(color: TmColors.card),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _AnalyticsArchiveNote(),
      ],
    );
  }
}

class _AnalyticsShortcutRow extends StatelessWidget {
  const _AnalyticsShortcutRow({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TmColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TmRadius.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: TmHit.min),
          padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
          decoration: BoxDecoration(
            color: selected ? TmColors.primaryTint : TmColors.transparent,
            borderRadius: BorderRadius.circular(TmRadius.chip),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: TmSize.analyticsIcon,
                color: selected ? TmColors.primary : TmColors.text2,
              ),
              const SizedBox(width: TmSpace.s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TmType.bodyStyle.copyWith(
                    color: selected ? TmColors.primary : TmColors.text,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: TmSpace.s),
                Text(
                  badge!,
                  textDirection: TextDirection.ltr,
                  style: TmType.captionStyle.copyWith(
                    color: selected ? TmColors.primary : TmColors.text2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsArchiveNote extends StatelessWidget {
  const _AnalyticsArchiveNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('analytics-archive-note'),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.successSurface,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.successBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: TmSize.analyticsKpiIcon,
            height: TmSize.analyticsKpiIcon,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TmColors.successTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: TmColors.success,
              size: TmSize.analyticsIcon,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الملفات مالكك بالكامل',
                  style: TmType.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  'تم فحص جميع عمليات العدّ والفهر محلياً على قرصك، ولم تُرسل '
                  'أي بيانات إلى الإنترنت.',
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

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty({required this.selectedYear, required this.onShowAll});

  final int? selectedYear;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      key: const Key('analytics-empty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedYear == null
                ? 'ما في تحليلات بعد'
                : 'ما في بيانات لهذه السنة',
            style: TmType.h1Style,
          ),
          const SizedBox(height: TmSpace.s),
          Text(
            selectedYear == null
                ? 'استورد نسخة بياناتك ليبلش الأرشيف يحكي: رسائل، منشورات '
                      'وتفاعلات، كلها على جهازك.'
                : 'ما في سجلات مؤرخة بهذه السنة في أرشيفك المحلي.',
            style: TmType.bodyMuted,
          ),
          if (selectedYear != null) ...[
            const SizedBox(height: TmSpace.m),
            SizedBox(
              height: TmHit.min,
              child: OutlinedButton(
                key: const Key('analytics-show-all'),
                onPressed: onShowAll,
                child: const Text('اعرض كل السنين'),
              ),
            ),
          ],
        ],
      ),
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

const List<String> _monthShort = [
  'كانون 2',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين 1',
  'تشرين 2',
  'كانون 1',
];

String _hourLabel(int hour) {
  final short = hour % 12 == 0 ? 12 : hour % 12;
  return '$short${hour < 12 ? 'ص' : 'م'}';
}

String _eventTypeLabel(String type) => switch (type) {
  'message' => 'رسائل',
  'post' => 'منشورات',
  'comment' => 'تعليقات',
  'reaction' => 'إعجابات',
  'attachment' => 'صور ومرفقات',
  _ => 'سجلات أخرى',
};

IconData _eventTypeIcon(String type) => switch (type) {
  'message' => Icons.chat_bubble_outline,
  'post' => Icons.article_outlined,
  'comment' => Icons.mode_comment_outlined,
  'reaction' => Icons.favorite_border,
  'attachment' => Icons.image_outlined,
  _ => Icons.insert_drive_file_outlined,
};
