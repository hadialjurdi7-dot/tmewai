import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tm_motion.dart';
import '../../core/design/tokens.dart';
import 'media_controller.dart';
import 'media_service.dart';

/// «الصور» — أرشيف الصور، أعيد بناؤه من مرجع المالك
/// `design/reference/user-2026-10-30/05-media.jpg`.
///
/// التخطيط ثلاثة أعمدة: «الاختصارات» يميناً، ثم بطاقة الرأس وفلاتر السنوات
/// وسطر «كل الصور من مجلدك» وشبكة 4×3 وبانر الذكريات في الوسط، ثم «أكثر الناس
/// بالصور» وملاحظة الخصوصية يساراً.
///
/// لا يُفتح أي ملف وسائط ولا تُعرض بايتاته: المربّع يقول ما خزّنه الأرشيف
/// (النوع والسنة وهل المسار محفوظ)، فلا تدّعي الشاشة معاينة لا تقدر تعرضها.
class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key, this.onOpenSection, this.importPageBuilder});

  /// ينقل إلى قسم من الهيكل؛ الشاشة لا تعرف الهيكل بنفسها.
  final ValueChanged<String>? onOpenSection;
  final WidgetBuilder? importPageBuilder;

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  /// المربّع المحدَّد؛ `null` يعني «أول صور الشبكة».
  int? _selectedId;

  void _openImport() {
    final builder = widget.importPageBuilder;
    if (builder == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: builder));
  }

  int? _effectiveSelection(MediaSnapshot snapshot) {
    final items = snapshot.items;
    if (items.isEmpty) return null;
    for (final item in items) {
      if (item.id == _selectedId) return item.id;
    }
    return items.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(mediaSnapshotProvider);

    return snapshot.when(
      loading: () => const Center(
        key: Key('media-loading'),
        child: TmLoader(),
      ),
      error: (_, _) => Center(
        key: const Key('media-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل الصور من الأرشيف المحلي.'),
              const SizedBox(height: TmSpace.m),
              OutlinedButton(
                onPressed: () => ref.invalidate(mediaSnapshotProvider),
                child: const Text('حاول مرة تانية'),
              ),
            ],
          ),
        ),
      ),
      data: (value) => SingleChildScrollView(
        key: const Key('media-screen'),
        padding: const EdgeInsets.all(TmSpace.m),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TmSize.mediaContentMaxWidth,
            ),
            child: value.isEmpty
                ? const _MediaEmpty()
                : _MediaBody(
                    snapshot: value,
                    selectedId: _effectiveSelection(value),
                    onSelect: (id) => setState(() => _selectedId = id),
                    onOpenSection: widget.onOpenSection,
                    onImport: _openImport,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MediaBody extends ConsumerWidget {
  const _MediaBody({
    required this.snapshot,
    required this.selectedId,
    required this.onSelect,
    required this.onOpenSection,
    required this.onImport,
  });

  final MediaSnapshot snapshot;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = snapshot.selectedYear;
    final oldestYear = snapshot.oldestYear;

    final gallery = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MediaHeader(snapshot: snapshot),
        const SizedBox(height: TmSpace.s),
        const _LocalOnlyLine(),
        const SizedBox(height: TmSpace.s),
        _GridCard(
          snapshot: snapshot,
          selectedId: selectedId,
          onSelect: onSelect,
        ),
        if (oldestYear != null) ...[
          const SizedBox(height: TmSpace.m),
          _MemoriesBanner(
            year: oldestYear,
            selected: year == oldestYear,
            onOpen: () =>
                ref.read(mediaYearProvider.notifier).select(oldestYear),
          ),
        ],
      ],
    );

    final people = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.people.isNotEmpty)
          _PeopleCard(
            people: snapshot.people,
            onOpenAll: onOpenSection == null
                ? null
                : () => onOpenSection!('people'),
          ),
        const SizedBox(height: TmSpace.m),
        const _PrivacyNote(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < TmSize.mediaThreeColumnMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gallery,
              const SizedBox(height: TmSpace.m),
              people,
            ],
          );
        }
        // Row follows Directionality: shortcuts at right, the gallery in the
        // middle, and the people ranking at left.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: TmSize.mediaShortcutsFlex,
              child: _MediaShortcuts(
                totalPhotos: snapshot.total,
                onOpenSection: onOpenSection,
                onImport: onImport,
              ),
            ),
            const SizedBox(width: TmSpace.m),
            Expanded(flex: TmSize.mediaGalleryFlex, child: gallery),
            const SizedBox(width: TmSpace.m),
            Expanded(flex: TmSize.mediaPeopleFlex, child: people),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header: title, real counter, and the year filters.
// ---------------------------------------------------------------------------

class _MediaHeader extends ConsumerWidget {
  const _MediaHeader({required this.snapshot});

  final MediaSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = snapshot.selectedYear;

    return _MediaCard(
      key: const Key('media-header'),
      padding: const EdgeInsets.symmetric(
        horizontal: TmSpace.l,
        vertical: TmSpace.m,
      ),
      child: Row(
        children: [
          Text(
            'الصور والفيديو',
            style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: TmSpace.m),
          Text(
            '${_formatNumber(snapshot.selectedCount)} صورة',
            key: const Key('media-count'),
            maxLines: 1,
            style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
          ),
          const SizedBox(width: TmSpace.l),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TmSpace.s,
              runSpacing: TmSpace.s,
              children: [
                _YearChip(
                  key: const Key('media-year-all'),
                  label: 'كل السنوات',
                  selected: year == null,
                  onSelected: () =>
                      ref.read(mediaYearProvider.notifier).select(null),
                ),
                for (final row in snapshot.years)
                  _YearChip(
                    key: Key('media-year-${row.year}'),
                    label: '${row.year}',
                    selected: year == row.year,
                    onSelected: () =>
                        ref.read(mediaYearProvider.notifier).select(row.year),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? TmColors.primary : TmColors.bg,
      borderRadius: BorderRadius.circular(TmRadius.pill),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(TmRadius.pill),
        // A `Container(alignment:)` Would stretch to the whole run width in a
        // Wrap, so the pills hug their label like 05-media.jpg.
        child: SizedBox(
          height: TmHit.min,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TmSpace.l),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: TmType.captionStyle.copyWith(
                    color: selected ? TmColors.card : TmColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalOnlyLine extends StatelessWidget {
  const _LocalOnlyLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('media-local-only'),
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: TmSize.mediaIcon,
          color: TmColors.success,
        ),
        const SizedBox(width: TmSpace.xs),
        Expanded(
          child: Text(
            'كل الصور من مجلدك - ما انرفعت لأي مكان',
            style: TmType.captionStyle.copyWith(color: TmColors.success),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grid: four across, three rows, year badge and one selected tile.
// ---------------------------------------------------------------------------

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.snapshot,
    required this.selectedId,
    required this.onSelect,
  });

  final MediaSnapshot snapshot;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (snapshot.items.isEmpty) {
      return _MediaCard(
        key: const Key('media-grid-empty'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.selectedYear == null
                  ? 'ما في صور بعد'
                  : 'ما في صور بهذه السنة',
              style: TmType.h2Style,
            ),
            const SizedBox(height: TmSpace.xs),
            Text(
              snapshot.selectedYear == null
                  ? 'استورد نسخة بياناتك لتشوف صور أرشيفك هنا، بلا أي رفع.'
                  : 'ما في مرفقات مؤرخة في سنة ${snapshot.selectedYear} '
                        'داخل الأرشيف.',
              style: TmType.bodyMuted,
            ),
          ],
        ),
      );
    }

    final visible = snapshot.items
        .take(TmSize.mediaMaxVisibleTiles)
        .toList(growable: false);

    return _MediaCard(
      key: const Key('media-grid-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            key: const Key('media-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: TmSize.mediaGridColumns,
              crossAxisSpacing: TmSpace.m,
              mainAxisSpacing: TmSpace.m,
              childAspectRatio: TmSize.mediaTileAspectRatio,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) => _MediaTile(
              key: ValueKey('media-item-${visible[index].id}'),
              item: visible[index],
              selected: visible[index].id == selectedId,
              onTap: () => onSelect(visible[index].id),
            ),
          ),
          if (visible.length < snapshot.matched) ...[
            const SizedBox(height: TmSpace.m),
            Text(
              'تظهر أحدث ${_formatNumber(visible.length)} من '
              '${_formatNumber(snapshot.matched)} — الباقي محفوظ على جهازك.',
              key: const Key('media-truncated'),
              style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MediaItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = item.at;

    return Material(
      color: TmColors.bg,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TmRadius.chip),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TmRadius.chip),
            border: Border.all(
              color: selected ? TmColors.primary : TmColors.border,
              width: selected ? TmSize.mediaSelectedBorderWidth : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TmRadius.chip),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _mediaIcon(item.mediaType),
                          size: TmSize.mediaGridIcon,
                          color: TmColors.text2,
                        ),
                        if (!item.hasPath) ...[
                          const SizedBox(height: TmSpace.xs),
                          Text(
                            'بلا مسار في الأرشيف',
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
                ),
                if (at != null)
                  PositionedDirectional(
                    top: TmSpace.s,
                    start: TmSpace.s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TmSpace.s,
                        vertical: TmSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: TmColors.text,
                        borderRadius: BorderRadius.circular(TmRadius.chip),
                      ),
                      child: Text(
                        '${at.year}',
                        textDirection: TextDirection.ltr,
                        style: TmType.captionStyle.copyWith(
                          color: TmColors.card,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (selected)
                  PositionedDirectional(
                    bottom: TmSpace.s,
                    end: TmSpace.s,
                    child: Container(
                      key: ValueKey('media-selected-${item.id}'),
                      width: TmSize.mediaSelectionMark,
                      height: TmSize.mediaSelectionMark,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: TmColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: TmSize.mediaSelectionIcon,
                        color: TmColors.card,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Memories banner.
// ---------------------------------------------------------------------------

class _MemoriesBanner extends StatelessWidget {
  const _MemoriesBanner({
    required this.year,
    required this.selected,
    required this.onOpen,
  });

  final int year;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('media-memories'),
      padding: const EdgeInsets.all(TmSpace.m),
      decoration: BoxDecoration(
        color: TmColors.warmSurface,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.warmBorder),
      ),
      child: Row(
        children: [
          Container(
            width: TmSize.mediaBannerIcon,
            height: TmSize.mediaBannerIcon,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TmColors.card,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              color: TmColors.warm,
              size: TmSize.mediaIcon,
            ),
          ),
          const SizedBox(width: TmSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هالصور من $year - ما حدا شافها من زمان',
                  key: const Key('media-memories-title'),
                  style: TmType.h2Style.copyWith(
                    color: TmColors.warmText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  'أرشيف محلي محفوظ تلقائياً من محادثاتك وصورك القديمة',
                  style: TmType.captionStyle.copyWith(
                    color: TmColors.warmTextSoft,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TmSpace.m),
          OutlinedButton(
            key: const Key('media-memories-open'),
            onPressed: selected ? null : onOpen,
            style: OutlinedButton.styleFrom(
              backgroundColor: TmColors.card,
              foregroundColor: TmColors.warmText,
              minimumSize: const Size(TmHit.min, TmHit.min),
              padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
              side: const BorderSide(color: TmColors.warmBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TmRadius.chip),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'افتح ذكريات $year',
                  style: TmType.captionStyle.copyWith(
                    color: selected ? TmColors.text2 : TmColors.warmText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: TmSpace.xs),
                Icon(
                  Icons.chevron_left,
                  size: TmSize.mediaIcon,
                  color: selected ? TmColors.text2 : TmColors.warmText,
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
// Side columns.
// ---------------------------------------------------------------------------

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.people, required this.onOpenAll});

  final List<MediaPerson> people;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _MediaCard(
      key: const Key('media-people'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'أكثر الناس بالصور',
                  style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                key: const Key('media-people-all'),
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(TmHit.min, TmHit.min),
                  padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
                  foregroundColor: TmColors.primary,
                  textStyle: TmType.captionStyle,
                ),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const Divider(height: TmSize.hairline),
          const SizedBox(height: TmSpace.m),
          for (var index = 0; index < people.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == people.length - 1 ? 0 : TmSpace.m,
              ),
              child: _PersonRow(person: people[index]),
            ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final MediaPerson person;

  @override
  Widget build(BuildContext context) {
    final tone = _avatarIndex(person.name);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TmHit.min),
      child: Row(
        key: ValueKey('media-person-${person.id}'),
        children: [
          Container(
            width: TmSize.mediaAvatar,
            height: TmSize.mediaAvatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TmColors.avatarTints[tone],
              shape: BoxShape.circle,
            ),
            child: Text(
              _initial(person.name),
              style: TmType.captionStyle.copyWith(
                color: TmColors.avatarForegrounds[tone],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TmType.bodyStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TmSpace.s,
              vertical: TmSpace.xs,
            ),
            decoration: BoxDecoration(
              color: TmColors.bg,
              borderRadius: BorderRadius.circular(TmRadius.pill),
            ),
            child: Text(
              '${_formatNumber(person.count)} صورة',
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

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  static const String _body =
      'بيقرأ صورك فقط من الذاكرة المحلية لجهازك، بدون أي رفع أو استهلاك '
      'للإنترنت.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('media-privacy-note'),
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
            width: TmSize.mediaNoteIcon,
            height: TmSize.mediaNoteIcon,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TmColors.successTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: TmColors.success,
              size: TmSize.mediaIcon,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'تطبيق Tmewai ',
                    style: TmType.captionStyle.copyWith(
                      color: TmColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: _body,
                    style: TmType.captionStyle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaShortcuts extends StatelessWidget {
  const _MediaShortcuts({
    required this.totalPhotos,
    required this.onOpenSection,
    required this.onImport,
  });

  final int totalPhotos;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MediaCard(
          key: const Key('media-shortcuts'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'الاختصارات',
                style: TmType.h2Style.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: TmSpace.s),
              const Divider(height: TmSize.hairline),
              const SizedBox(height: TmSpace.s),
              for (final entry in _shortcuts)
                Padding(
                  padding: const EdgeInsets.only(bottom: TmSpace.xs),
                  child: _ShortcutRow(
                    key: ValueKey('media-shortcut-${entry.label}'),
                    label: entry.label,
                    icon: entry.icon,
                    selected: entry.section == 'media',
                    badge: entry.section == 'media'
                        ? _formatNumber(totalPhotos)
                        : null,
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
                  key: const Key('media-import'),
                  onPressed: onImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: TmColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TmRadius.chip),
                    ),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(
                    'استيراد بيانات جديدة',
                    style: TmType.bodyStyle.copyWith(color: TmColors.card),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TmSpace.m),
        const _ArchiveNote(),
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
                size: TmSize.mediaIcon,
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

class _ArchiveNote extends StatelessWidget {
  const _ArchiveNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('media-archive-note'),
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
            width: TmSize.mediaNoteIcon,
            height: TmSize.mediaNoteIcon,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: TmColors.successTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: TmColors.success,
              size: TmSize.mediaIcon,
            ),
          ),
          const SizedBox(width: TmSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أرشيفك مالكك بالكامل',
                  style: TmType.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: TmSpace.xs),
                Text(
                  'الملفات مخزنة ومفهرسة على قرصك الصلب دون حاجة لأي اتصال '
                  'خارجي. بياناتك ما بتغادر كمبيوترك أبداً.',
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

class _MediaEmpty extends StatelessWidget {
  const _MediaEmpty();

  @override
  Widget build(BuildContext context) {
    return _MediaCard(
      key: const Key('media-empty'),
      padding: const EdgeInsets.all(TmSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ما في صور بعد', style: TmType.h1Style),
          const SizedBox(height: TmSpace.s),
          Text(
            'استورد نسخة بياناتك لتشوف صور أرشيفك هنا. كل شي ينقرأ من جهازك، '
            'وما في أي رفع.',
            style: TmType.bodyMuted,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared.
// ---------------------------------------------------------------------------

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TmSpace.m),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TmColors.card,
        borderRadius: BorderRadius.circular(TmRadius.card),
        border: Border.all(color: TmColors.border),
      ),
      child: child,
    );
  }
}

const List<({String label, IconData icon, String section})> _shortcuts = [
  (label: 'ملفي', icon: Icons.person_outline, section: 'people'),
  (label: 'الرئيسية', icon: Icons.home_outlined, section: 'home'),
  (label: 'قصتك بالأرقام', icon: Icons.bolt_outlined, section: 'story'),
  (label: 'التحليلات', icon: Icons.bar_chart, section: 'analytics'),
  (label: 'الرسائل', icon: Icons.chat_bubble_outline, section: 'messages'),
  (label: 'الصور', icon: Icons.image_outlined, section: 'media'),
  (label: 'الأشخاص', icon: Icons.people_outline, section: 'people'),
  (label: 'الإعدادات', icon: Icons.settings_outlined, section: 'settings'),
];

String _formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
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
