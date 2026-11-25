/// One import label in both app languages.
///
/// The importer, the preview and the timeline all read this vocabulary, so a
/// payload kind cannot be Arabic on one screen and untranslated on another.
class ImportLabel {
  const ImportLabel({required this.en, required this.ar});

  final String en;
  final String ar;

  String inLocale({required bool isRtl}) => isRtl ? ar : en;
}

/// Stored event types for a message whose body carries no text.
///
/// A text message stays `message`; these types exist so stored data - not only
/// a rendered label - can tell a photo from a link, and so the timeline can
/// group them honestly. Every one starts with `message_`, which is what the
/// message aggregates match.
const String messagePhotoEventType = 'message_photo';
const String messageVideoEventType = 'message_video';
const String messageGifEventType = 'message_gif';
const String messageAudioEventType = 'message_audio';
const String messageFileEventType = 'message_file';
const String messageLinkEventType = 'message_link';
const String messageStickerEventType = 'message_sticker';
const String messageCallEventType = 'message_call';
const String messageDeletedEventType = 'message_deleted';
const String messagePollEventType = 'message_poll';
const String messagePlanEventType = 'message_plan';
const String messageEmptyEventType = 'message_empty';

/// Labels of the typed message payloads, keyed by their stored event type.
const Map<String, ImportLabel> messagePayloadLabels = {
  messagePhotoEventType: ImportLabel(en: 'Photo', ar: 'صورة'),
  messageVideoEventType: ImportLabel(en: 'Video', ar: 'فيديو'),
  messageGifEventType: ImportLabel(en: 'GIF', ar: 'صورة متحركة'),
  messageAudioEventType: ImportLabel(en: 'Audio clip', ar: 'ملف صوتي'),
  messageFileEventType: ImportLabel(en: 'File', ar: 'ملف'),
  messageLinkEventType: ImportLabel(en: 'Shared link', ar: 'رابط مشارَك'),
  messageStickerEventType: ImportLabel(en: 'Sticker', ar: 'ملصق'),
  messageCallEventType: ImportLabel(en: 'Call', ar: 'مكالمة'),
  messageDeletedEventType: ImportLabel(en: 'Unsent message', ar: 'رسالة محذوفة'),
  messagePollEventType: ImportLabel(en: 'Poll', ar: 'استطلاع'),
  messagePlanEventType: ImportLabel(en: 'Plan', ar: 'خطة'),
  messageEmptyEventType: ImportLabel(
    en: 'Empty message — no content',
    ar: 'رسالة فارغة — بلا محتوى',
  ),
};

/// The label of a stored event type, or null when the type has none.
///
/// [callSeconds] is the duration stated by the export; it is appended only to
/// a call, so "42" never decorates a photo. The number is quoted, not
/// interpreted.
String? importEventLabel(
  String eventType, {
  required bool isRtl,
  int? callSeconds,
}) {
  final label = messagePayloadLabels[eventType];
  if (label == null) return null;
  if (eventType == messageCallEventType &&
      callSeconds != null &&
      callSeconds > 0) {
    return isRtl
        ? '${label.ar} — $callSeconds ثانية'
        : '${label.en} — $callSeconds seconds';
  }
  return label.inLocale(isRtl: isRtl);
}

/// True when [eventType] is a message, whatever payload it carried.
bool isMessageEventType(String eventType) =>
    eventType == 'message' || eventType.startsWith('message_');
