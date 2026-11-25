import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tm_motion.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_strings.dart';
import '../media/media_service.dart';
import 'person_controller.dart';
import 'person_service.dart';
import 'person_strings.dart';

/// «الأشخاص / ملف شخص» — أعيد بناؤه من مرجع المالك
/// `design/reference/user-2026-10-30/06-person.jpg`.
///
/// ثلاثة أعمدة: «الاختصارات» يميناً، ثم الغلاف وبطاقة الملف والأرقام وآخر ما
/// قاله ومعرض الصور والمخطط السنوي في الوسط، ثم «ناس قريبين» و«معلومات
/// الأرشيف المحلي» وبطاقة ذكرى يساراً.
///
/// الغلاف شريط توكنز لا صورة: الأرشيف يخزّن بيانات وصفية للمرفقات ولا يخزّن
/// صورة ملف شخصي، فلا تُوضع صورة مخترعة ولا يُفتح ملف وسائط.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({
    super.key,
    this.onOpenConversation,
    this.onOpenPhotos,
    this.onOpenSection,
    this.importPageBuilder,
  });

  /// Opens the conversation the profile points at; null disables the button.
  final ValueChanged<int>? onOpenConversation;

  /// Opens the whole gallery; null disables the photo button.
  final VoidCallback? onOpenPhotos;

  /// Opens a shell section from the shortcuts column.
  final ValueChanged<String>? onOpenSection;

  /// The import page, pushed from the shortcuts card.
  final WidgetBuilder? importPageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(personSnapshotProvider);
    final copy = PersonCopy(ref.watch(appStringsProvider));

    return snapshot.when(
      loading: () =>
          const Center(key: Key('person-loading'), child: TmLoader()),
      error: (_, _) => Center(
        key: const Key('person-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(copy.failed),
              const SizedBox(height: TmSpace.m),
              OutlinedButton(
                onPressed: () => ref.invalidate(personSnapshotProvider),
                child: Text(copy.retry),
              ),
            ],
          ),
        ),
      ),
      data: (value) => PersonCopyScope(
        copy: copy,
        child: SingleChildScrollView(
          key: const Key('person-screen'),
          padding: const EdgeInsets.all(TmSpace.m),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TmSize.personContentMaxWidth,
              ),
              child: value.isEmpty
                  ? const _PersonEmpty()
                  : _PersonBody(
                      snapshot: value,
                      onOpenConversation: onOpenConversation,
                      onOpenPhotos: onOpenPhotos,
                      onOpenSection: onOpenSection,
                      onImport: () {
                        final builder = importPageBuilder;
                        if (builder == null) return;
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: builder),
                        );
                      },
                      onSelect: (id) => ref
                          .read(personSelectionProvider.notifier)
                          .select(id),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonBody extends StatelessWidget {
  const _PersonBody({
    required this.snapshot,
    required this.onOpenConversation,
    required this.onOpenPhotos,
    required this.onOpenSection,
    required this.onImport,
    required this.onSelect,
  });

  final PersonSnapshot snapshot;
  final ValueChanged<int>? onOpenConversation;
  final VoidCallback? onOpenPhotos;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final profile = snapshot.selected;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile == null)
          const _PersonEmpty()
        else ...[
          _ProfileHero(
            profile: profile,
            onOpenConversation: onOpenConversation,
            onOpenPhotos: onOpenPhotos,
          ),
          const SizedBox(height: TmSpace.m),
          _StatsCard(profile: profile),
          const SizedBox(height: TmSpace.m),
          _RecentCard(profile: profile),
          const SizedBox(height: TmSpace.m),
          _PhotosCard(profile: profile, onOpenPhotos: onOpenPhotos),
          const SizedBox(height: TmSpace.m),
          _YearChartCard(profile: profile),
        ],
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NearbyCard(
          people: snapshot.people,
          selectedId: profile?.id,
          onSelect: onSelect,
        ),
        const SizedBox(height: TmSpace.m),
        _ArchiveInfoCard(snapshot: snapshot),
        const SizedBox(height: TmSpace.m),
        _MemoryCard(profile: profile),
      ],
    );

    final shortcuts = _ShortcutsColumn(
      snapshot: snapshot,
      onOpenSection: onOpenSection,
      onImport: onImport,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < TmSize.personThreeColumnMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              const SizedBox(height: TmSpace.m),
              side,
              const SizedBox(height: TmSpace.m),
              shortcuts,
            ],
          );
        }
        // Row follows Directionality: shortcuts at right, the profile in the
        // middle, and the archive cards at left.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: TmSize.personShortcutsFlex, child: shortcuts),
            const SizedBox(width: TmSpace.m),
            Expanded(flex: TmSize.personMainFlex, child: main),
            const SizedBox(width: TmSpace.m),
            Expanded(flex: TmSize.personSideFlex, child: side),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: cover, avatar, name and the two actions.
// ---------------------------------------------------------------------------

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.onOpenConversation,
    required this.onOpenPhotos,
  });

  final PersonProfile profile;
  final ValueChanged<int>? onOpenConversation;
  final VoidCallback? onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final conversationId = profile.conversationId;
    final openConversation = onOpenConversation;
    final canChat = conversationId != null && openConversation != null;
    final platformId = copy.platformId(profile.platformPersonId);

    return Container(
      key: const Key('person-hero'),
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('person-cover'),
                height: TmSize.personCoverHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topCenter,
                    end: AlignmentDirectional.bottomCenter,
                    colors: [
                      TmColors.primarySoft,
                      TmColors.primaryTint,
                      TmColors.card,
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(TmRadius.card),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  TmSpace.l,
                  TmSize.personAvatar / 2 + TmSpace.s,
                  TmSpace.l,
                  TmSpace.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 06-person.jpg keeps the name beside the overlapping
                    // avatar and both actions on the same row, at the far end.
                    Row(
                      children: [
                        const SizedBox(width: TmSize.personAvatar + TmSpace.m),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile.name,
                                key: const Key('person-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TmType.h1Style,
                              ),
                              const SizedBox(height: TmSpace.xs),
                              Text(
                                _rangeLine(profile, copy),
                                key: const Key('person-range'),
                                maxLines: 2,
                                style: TmType.captionStyle.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (platformId != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  platformId,
                                  key: const Key('person-platform-id'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TmType.captionStyle.copyWith(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: TmSpace.s),
                        Flexible(
                          flex: 7,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: TmSpace.s,
                            runSpacing: TmSpace.s,
                            children: [
                              OutlinedButton.icon(
                                key: const Key('person-hero-photos'),
                                onPressed: onOpenPhotos,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, TmHit.min),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: TmSpace.m,
                                  ),
                                ),
                                icon: const Icon(Icons.image_outlined),
                                label: Text(
                                  copy.heroPhotos(profile.photoCount),
                                ),
                              ),
                              FilledButton.icon(
                                key: const Key('person-hero-chat'),
                                onPressed: canChat
                                    ? () => openConversation(conversationId)
                                    : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, TmHit.min),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: TmSpace.m,
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(copy.openConversation),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          PositionedDirectional(
            start: TmSpace.l,
            top: TmSize.personCoverHeight - TmSize.personAvatar / 2,
            child: Container(
              width: TmSize.personAvatar,
              height: TmSize.personAvatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TmColors.primaryTint,
                shape: BoxShape.circle,
                border: Border.all(
                  color: TmColors.card,
                  width: TmSize.personAvatarRing,
                ),
              ),
              child: Text(
                _initial(profile.name),
                style: TmType.metricStyle.copyWith(color: TmColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The four numbers of the profile, one card split by hairlines.
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.profile});

  final PersonProfile profile;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    // Four separate white cards, not one card split by hairlines.
    return IntrinsicHeight(
      child: Row(
        key: const Key('person-stats'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              key: const Key('person-stat-messages'),
              label: copy.statMessages,
              value: copy.number(profile.messageCount),
              icon: Icons.chat_bubble_outline,
              iconColor: TmColors.primary,
              iconTint: TmColors.primaryTint,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: _StatTile(
              key: const Key('person-stat-photos'),
              label: copy.statPhotos,
              value: copy.number(profile.photoCount),
              icon: Icons.image_outlined,
              iconColor: TmColors.warm,
              iconTint: TmColors.warmTint,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: _StatTile(
              key: const Key('person-stat-first'),
              label: copy.statFirst,
              value: copy.day(profile.firstAt),
              icon: Icons.calendar_month_outlined,
              iconColor: TmColors.text2,
              iconTint: TmColors.bg,
              compact: true,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: _StatTile(
              key: const Key('person-stat-last'),
              label: copy.statLast,
              value: copy.day(profile.lastAt),
              icon: Icons.schedule,
              iconColor: TmColors.success,
              iconTint: TmColors.successTint,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconTint;

  /// Dates are set smaller than counts so a full date stays inside the tile.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      child: Row(
        children: [
          // The icon leads the tile on the start edge, as in 06-person.jpg.
          Container(
            width: TmSize.personStatIconBox,
            height: TmSize.personStatIconBox,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(TmRadius.chip),
            ),
            child: Icon(icon, size: TmSize.personIcon, color: iconColor),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? TmType.captionStyle.copyWith(
                          color: TmColors.text,
                          fontWeight: FontWeight.w700,
                        )
                      : TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
// Last things they said.
// ---------------------------------------------------------------------------

/// The person's messages, newest first, with one page loaded at a time.
///
/// The first page comes with the profile; older pages are appended on demand
/// through [personMessagePageProvider], reusing the repository's newest-first
/// read. Nothing is loaded until the button is pressed, so opening a profile
/// with tens of thousands of messages stays one bounded query.
class _RecentCard extends ConsumerStatefulWidget {
  const _RecentCard({required this.profile});

  final PersonProfile profile;

  @override
  ConsumerState<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends ConsumerState<_RecentCard> {
  final List<PersonLine> _older = [];
  bool _loading = false;
  bool _failed = false;

  /// The person the appended pages belong to; changing the open profile drops
  /// them instead of showing one person's rows under another person's name.
  int? _boundPersonId;

  Future<void> _loadOlder() async {
    final profile = widget.profile;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final offset = profile.lines.length + _older.length;
    try {
      final page = await ref.read(
        personMessagePageProvider((
          personId: profile.id,
          offset: offset,
        )).future,
      );
      if (!mounted) return;
      setState(() {
        _older.addAll(page.lines);
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final profile = widget.profile;
    if (_boundPersonId != profile.id) {
      _boundPersonId = profile.id;
      _older.clear();
      _loading = false;
      _failed = false;
    }

    final lines = [...profile.lines, ..._older];
    final hasMore = lines.length < profile.messageTotal;

    return _PersonCard(
      key: const Key('person-recent'),
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
                    Text(
                      copy.recentTitle,
                      style: TmType.h2Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      copy.recentSubtitle,
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              _LabelChip(copy.recentBadge),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          if (lines.isEmpty)
            Text(copy.recentEmpty, style: TmType.bodyMuted)
          else
            for (var index = 0; index < lines.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == lines.length - 1 ? 0 : TmSpace.s,
                ),
                child: _LineRow(line: lines[index], name: profile.name),
              ),
          // Paging controls appear only once the archive holds more text
          // messages than the loaded pages; with a single page the card stays
          // exactly as the reference draws it. After a page is appended the
          // loaded count stays visible, so the end of the list is stated.
          if (lines.isNotEmpty && (hasMore || _failed || _older.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: TmSpace.s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.loadedCount(lines.length, profile.messageTotal),
                      key: const Key('person-loaded-count'),
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (hasMore) ...[
                    const SizedBox(width: TmSpace.s),
                    TextButton(
                      key: const Key('person-load-older'),
                      onPressed: _loading ? null : _loadOlder,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(TmHit.min, TmHit.min),
                        padding: const EdgeInsets.symmetric(
                          horizontal: TmSpace.s,
                        ),
                        textStyle: TmType.captionStyle,
                      ),
                      child: Text(_failed ? copy.pageFailed : copy.loadOlder),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.name});

  final PersonLine line;
  final String name;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final text = line.text?.trim() ?? '';

    return Container(
      key: ValueKey('person-line-${line.id}'),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.bg,
        borderRadius: BorderRadius.circular(TmRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TmType.captionStyle.copyWith(
                    color: TmColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                copy.moment(line.at),
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: TmSpace.xs),
          Text('«$text»', style: TmType.bodyStyle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared photos.
// ---------------------------------------------------------------------------

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.profile, required this.onOpenPhotos});

  final PersonProfile profile;
  final VoidCallback? onOpenPhotos;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    return _PersonCard(
      key: const Key('person-photos'),
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
                    Text(
                      copy.photosTitle(profile.photoCount),
                      style: TmType.h2Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      copy.photosSubtitle,
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('person-all-photos'),
                onPressed: onOpenPhotos,
                style: TextButton.styleFrom(
                  minimumSize: const Size(TmHit.min, TmHit.min),
                  padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
                  foregroundColor: TmColors.primary,
                  textStyle: TmType.captionStyle,
                ),
                child: Text(copy.allPhotos),
              ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          if (profile.photos.isEmpty)
            Text(copy.photosEmpty, style: TmType.bodyMuted)
          else
            GridView.builder(
              key: const Key('person-photo-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: TmSize.personPhotoColumns,
                crossAxisSpacing: TmSpace.s,
                mainAxisSpacing: TmSpace.s,
                childAspectRatio: TmSize.personPhotoAspectRatio,
              ),
              itemCount: profile.photos.length,
              itemBuilder: (context, index) =>
                  _PhotoTile(photo: profile.photos[index]),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});

  final MediaItem photo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('person-photo-${photo.id}'),
      decoration: BoxDecoration(
        color: TmColors.bg,
        borderRadius: BorderRadius.circular(TmRadius.chip),
        border: Border.all(color: TmColors.border),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              _mediaIcon(photo.mediaType),
              size: TmSize.personPhotoIcon,
              color: TmColors.text2,
            ),
          ),
          // 06-person.jpg has no year pill on the profile gallery tiles.
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages per year between the two of you.
// ---------------------------------------------------------------------------

class _YearChartCard extends StatelessWidget {
  const _YearChartCard({required this.profile});

  final PersonProfile profile;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final years = profile.years;
    final first = profile.firstYear;
    final last = profile.lastYear;
    final total = years.fold<int>(0, (sum, year) => sum + year.count);
    final busiest = profile.busiestYear;
    final labelled = _labelledYears(years);

    return _PersonCard(
      key: const Key('person-years'),
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
                    Text(
                      copy.yearsTitle,
                      style: TmType.h2Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      copy.yearsSubtitle,
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (first != null && last != null)
                _LabelChip('$first - $last', ltr: true),
            ],
          ),
          const SizedBox(height: TmSpace.l),
          if (years.isEmpty)
            Text(copy.yearsEmpty, style: TmType.bodyMuted)
          else
            SizedBox(
              height: TmSize.personChartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Oldest first inside the RTL row, so the timeline grows
                  // leftwards exactly as in the reference.
                  for (final year in years)
                    Expanded(
                      child: _YearBar(
                        year: year,
                        max: profile.yearMax,
                        highlighted: year.year == busiest,
                        labelled: labelled.contains(year.year),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: TmSpace.m),
          const Divider(height: TmSize.hairline),
          const SizedBox(height: TmSpace.s),
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.yearsTotal(total),
                  style: TmType.captionStyle,
                ),
              ),
              if (busiest != null) ...[
                Container(
                  width: TmSize.personDot,
                  height: TmSize.personDot,
                  decoration: const BoxDecoration(
                    color: TmColors.warm,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: TmSpace.xs),
                Text(
                  copy.yearsPeak(busiest),
                  style: TmType.captionStyle.copyWith(color: TmColors.warmText),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The two busiest years get their count printed above the bar, as in the
/// reference; printing all of them would crowd the axis.
Set<int> _labelledYears(List<PersonYear> years) {
  final ranked = [...years]..sort((a, b) => b.count.compareTo(a.count));
  return {
    for (final year in ranked.take(TmSize.personChartValueCount))
      if (year.count > 0) year.year,
  };
}

class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.year,
    required this.max,
    required this.highlighted,
    required this.labelled,
  });

  final PersonYear year;
  final int max;
  final bool highlighted;
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final ratio = max == 0 || year.count == 0
        ? 0.0
        : (year.count / max).clamp(0.02, 1.0);
    final barColor = highlighted
        ? TmColors.warm
        : year.count == 0
        ? TmColors.border
        : TmColors.primarySoft;

    return Padding(
      key: ValueKey('person-year-${year.year}'),
      padding: const EdgeInsets.symmetric(horizontal: TmSpace.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: TmType.caption * TmType.height,
            child: labelled
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      copy.number(year.count),
                      textDirection: TextDirection.ltr,
                      style: TmType.captionStyle.copyWith(
                        color: highlighted ? TmColors.text : TmColors.primary,
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
                  width: TmSize.personBarWidth,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(TmRadius.chip),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TmSpace.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              // Two digits keep ten years readable; the card header states the
              // full range the two digits belong to.
              year.year.toString().substring(2),
              textDirection: TextDirection.ltr,
              style: TmType.captionStyle.copyWith(
                color: highlighted ? TmColors.text : TmColors.text2,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nearby people.
// ---------------------------------------------------------------------------

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.people,
    required this.selectedId,
    required this.onSelect,
  });

  final List<PersonSummary> people;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    return _PersonCard(
      key: const Key('person-nearby'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  copy.nearbyTitle,
                  style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: TmSpace.s),
              _LabelChip(copy.nearbyBadge),
            ],
          ),
          const SizedBox(height: TmSpace.s),
          const Divider(height: TmSize.hairline),
          const SizedBox(height: TmSpace.s),
          if (people.isEmpty)
            Text(copy.nearbyEmpty, style: TmType.bodyMuted)
          else
            for (var index = 0; index < people.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == people.length - 1 ? 0 : TmSpace.xs,
                ),
                child: _NearbyRow(
                  person: people[index],
                  rank: index + 1,
                  selected: people[index].id == selectedId,
                  onTap: () => onSelect(people[index].id),
                ),
              ),
          const SizedBox(height: TmSpace.m),
          Text(
            copy.nearbyNote,
            style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.person,
    required this.rank,
    required this.selected,
    required this.onTap,
  });

  final PersonSummary person;
  final int rank;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final tone = _avatarIndex(person.name);

    return Material(
      color: selected ? TmColors.primaryTint : TmColors.transparent,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      child: InkWell(
        key: ValueKey('person-people-${person.id}'),
        borderRadius: BorderRadius.circular(TmRadius.chip),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: TmHit.min),
          padding: const EdgeInsets.symmetric(
            horizontal: TmSpace.s,
            vertical: TmSpace.xs,
          ),
          child: Row(
            children: [
              Container(
                width: TmSize.personAvatarSmall,
                height: TmSize.personAvatarSmall,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? TmColors.card : TmColors.avatarTints[tone],
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initial(person.name),
                  style: TmType.captionStyle.copyWith(
                    color: selected
                        ? TmColors.primary
                        : TmColors.avatarForegrounds[tone],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TmSpace.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TmType.bodyStyle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      copy.nearbyRank(rank),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    copy.number(person.messageCount),
                    textDirection: TextDirection.ltr,
                    style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    copy.statMessages,
                    style: TmType.captionStyle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Local archive facts.
// ---------------------------------------------------------------------------

class _ArchiveInfoCard extends StatelessWidget {
  const _ArchiveInfoCard({required this.snapshot});

  final PersonSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    return _PersonCard(
      key: const Key('person-archive-info'),
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
                    Text(
                      copy.archiveTitle,
                      style: TmType.h2Style.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: TmSpace.xs),
                    Text(
                      copy.archiveSubtitle,
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TmSpace.s),
              Container(
                width: TmSize.personNoteIcon,
                height: TmSize.personNoteIcon,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: TmColors.successTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: TmColors.success,
                  size: TmSize.personIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TmSpace.s,
              vertical: TmSpace.xs,
            ),
            decoration: BoxDecoration(
              color: TmColors.bg,
              borderRadius: BorderRadius.circular(TmRadius.chip),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: copy.archiveIndexType,
                  value: 'SQLite On-Device',
                  ltr: true,
                ),
                const Divider(height: TmSize.hairline),
                _InfoRow(
                  label: copy.archiveRecords,
                  value: copy.number(snapshot.events),
                ),
                const Divider(height: TmSize.hairline),
                _InfoRow(
                  label: copy.archiveLast,
                  value: copy.day(snapshot.lastDatedAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;

  /// Archive paths and engine names are Latin, so they keep LTR order.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: TmSize.personInfoRowMinHeight,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              textDirection: ltr ? TextDirection.ltr : null,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TmType.bodyStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One stored line, framed as a memory.
// ---------------------------------------------------------------------------

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.profile});

  final PersonProfile? profile;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final lines = profile?.lines ?? const <PersonLine>[];
    // The oldest of the stored lines is the one furthest from today, so it is
    // the one the memory card quotes; no line is invented.
    final line = lines.isEmpty ? null : lines.last;
    final text = line?.text?.trim() ?? '';

    return Container(
      key: const Key('person-memory'),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.warmSurface,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.warmBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  copy.memoryTitle,
                  style: TmType.h2Style.copyWith(
                    color: TmColors.warmText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TmSpace.s),
              Container(
                width: TmSize.personNoteIcon,
                height: TmSize.personNoteIcon,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: TmColors.card,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: TmColors.warm,
                  size: TmSize.personIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: TmSpace.s),
          if (line == null || text.isEmpty)
            Text(
              copy.memoryEmpty,
              style: TmType.captionStyle.copyWith(
                color: TmColors.warmTextSoft,
                fontWeight: FontWeight.w400,
              ),
            )
          else ...[
            Text(
              '«$text»',
              style: TmType.bodyStyle.copyWith(color: TmColors.warmTextSoft),
            ),
            const SizedBox(height: TmSpace.s),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                copy.memoryAge(line.at),
                style: TmType.captionStyle.copyWith(
                  color: TmColors.warmTextSoft,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shortcuts column (right).
// ---------------------------------------------------------------------------

class _ShortcutsColumn extends StatelessWidget {
  const _ShortcutsColumn({
    required this.snapshot,
    required this.onOpenSection,
    required this.onImport,
  });

  final PersonSnapshot snapshot;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    final badges = <String, String>{
      'messages': copy.number(snapshot.messages),
      'media': copy.number(snapshot.photos),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PersonCard(
          key: const Key('person-shortcuts'),
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
                        Text(
                          copy.shortcutsTitle,
                          style: TmType.h2Style.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: TmSpace.xs),
                        Text(
                          copy.shortcutsSubtitle,
                          style: TmType.captionStyle.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TmSpace.s),
                  _LabelChip(
                    copy.number(snapshot.events),
                    key: const Key('person-archive-total'),
                    ltr: true,
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.s),
              const Divider(height: TmSize.hairline),
              const SizedBox(height: TmSpace.s),
              for (final entry in _shortcuts)
                Padding(
                  padding: const EdgeInsets.only(bottom: TmSpace.xs),
                  child: _ShortcutRow(
                    key: ValueKey('person-shortcut-${entry.id}'),
                    label: copy.shortcut(entry.id),
                    icon: entry.icon,
                    selected: entry.id == 'people',
                    badge: badges[entry.section],
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
                  key: const Key('person-import'),
                  onPressed: onImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: TmColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TmRadius.chip),
                    ),
                  ),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(
                    copy.importAction,
                    style: TmType.bodyStyle.copyWith(color: TmColors.card),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _OwnershipNote(),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
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
                size: TmSize.personIcon,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
                  decoration: BoxDecoration(
                    color: selected ? TmColors.primary : TmColors.bg,
                    borderRadius: BorderRadius.circular(TmRadius.pill),
                  ),
                  child: Text(
                    badge!,
                    textDirection: TextDirection.ltr,
                    style: TmType.captionStyle.copyWith(
                      color: selected ? TmColors.card : TmColors.text,
                      fontWeight: FontWeight.w700,
                    ),
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

class _OwnershipNote extends StatelessWidget {
  const _OwnershipNote();

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    return Container(
      key: const Key('person-ownership'),
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
            width: TmSize.personNoteIcon,
            height: TmSize.personNoteIcon,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TmColors.successTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: TmColors.success,
              size: TmSize.personIcon,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.ownershipTitle,
                  style: TmType.bodyStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  copy.ownershipBody,
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

class _PersonEmpty extends StatelessWidget {
  const _PersonEmpty();

  @override
  Widget build(BuildContext context) {
    final copy = PersonCopy.of(context);
    return _PersonCard(
      key: const Key('person-empty'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.emptyTitle, style: TmType.h1Style),
          const SizedBox(height: TmSpace.s),
          Text(copy.emptyBody, style: TmType.bodyMuted),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared.
// ---------------------------------------------------------------------------

class _PersonCard extends StatelessWidget {
  const _PersonCard({super.key, required this.child});

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

class _LabelChip extends StatelessWidget {
  const _LabelChip(this.label, {super.key, this.ltr = false});

  final String label;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.s,
        vertical: TmSpace.xs,
      ),
      decoration: BoxDecoration(
        color: TmColors.bg,
        borderRadius: BorderRadius.circular(TmRadius.pill),
      ),
      child: Text(
        label,
        textDirection: ltr ? TextDirection.ltr : null,
        style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The shortcuts of the person screen, in the reference's order: «ملفي» first,
/// then the sections, with «الأشخاص» active. Labels come from [PersonCopy], so
/// the list keeps its shape in both languages.
const List<({String id, IconData icon, String section})> _shortcuts = [
  (id: 'me', icon: Icons.person_outline, section: 'people'),
  (id: 'home', icon: Icons.home_outlined, section: 'home'),
  (id: 'story', icon: Icons.bolt_outlined, section: 'story'),
  (id: 'analytics', icon: Icons.bar_chart, section: 'analytics'),
  (id: 'messages', icon: Icons.chat_bubble_outline, section: 'messages'),
  (id: 'media', icon: Icons.image_outlined, section: 'media'),
  (id: 'people', icon: Icons.people_outline, section: 'people'),
  (id: 'settings', icon: Icons.settings_outlined, section: 'settings'),
];

String _rangeLine(PersonProfile profile, PersonCopy copy) {
  final first = profile.firstYear;
  final last = profile.lastYear;
  final parts = <String>[copy.rangeMessages(profile.messageCount)];
  if (first != null && last != null) {
    parts.add(first == last ? copy.rangeYear(first) : copy.rangeYears(first, last));
  }
  parts.add(copy.platformLabel(profile.platform));
  return parts.join(' · ');
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}

int _avatarIndex(String name) => name.runes.fold<int>(
  0,
  (hash, rune) => (hash * 31 + rune) % TmColors.avatarTints.length,
);

IconData _mediaIcon(String mediaType) => switch (mediaType) {
  'image' => Icons.image_outlined,
  'video' => Icons.videocam_outlined,
  'audio' => Icons.audiotrack_outlined,
  _ => Icons.insert_drive_file_outlined,
};
