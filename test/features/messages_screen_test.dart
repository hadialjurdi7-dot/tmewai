import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_screen.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';

MessageBubble _bubble(
  int id,
  String? text, {
  bool fromPrimary = true,
  String sender = 'ليلى خالد',
  DateTime? at,
  int attachments = 0,
  String? mediaType,
  int? actorId,
}) => MessageBubble(
  id: id,
  text: text,
  at: at ?? DateTime.utc(2019, 3, 12, 10, 14),
  senderName: sender,
  fromPrimarySender: fromPrimary,
  attachmentCount: attachments,
  attachmentMediaType: mediaType,
  actorId: actorId,
);

final _leilaThread = ConversationThread(
  id: 1,
  title: 'ليلى خالد',
  messageCount: 4,
  firstAt: DateTime.utc(2019, 3, 12, 10, 14),
  lastAt: DateTime.utc(2021, 8, 24, 9, 5),
  platform: 'facebook',
  senderCount: 2,
  loadedCount: 4,
  primarySenderId: 1,
  days: [
    MessageDay(
      date: DateTime.utc(2021, 8, 24),
      bubbles: [
        _bubble(14, 'ذكرى السنة', at: DateTime.utc(2021, 8, 24, 9, 5)),
      ],
    ),
    MessageDay(
      date: DateTime.utc(2019, 3, 12),
      bubbles: [
        _bubble(
          13,
          null,
          at: DateTime.utc(2019, 3, 12, 10, 22),
          attachments: 1,
          mediaType: 'image',
        ),
        _bubble(
          12,
          'صباح الورد ليلى',
          at: DateTime.utc(2019, 3, 12, 10, 18),
          fromPrimary: false,
          sender: 'سامر',
        ),
        _bubble(11, 'صباح الخير يا صديقي', at: DateTime.utc(2019, 3, 12, 10, 14)),
      ],
    ),
  ],
);

final _omarThread = ConversationThread(
  id: 2,
  title: 'عمر بيطار',
  messageCount: 2,
  firstAt: DateTime.utc(2020, 1, 2, 8),
  lastAt: DateTime.utc(2020, 1, 2, 9),
  platform: 'facebook',
  senderCount: 1,
  loadedCount: 2,
  primarySenderId: 2,
  days: [
    MessageDay(
      date: DateTime.utc(2020, 1, 2),
      bubbles: [
        _bubble(
          22,
          'وأنت سالم',
          at: DateTime.utc(2020, 1, 2, 9),
          sender: 'عمر بيطار',
        ),
        _bubble(
          21,
          'كل سنة وأنت سالم',
          at: DateTime.utc(2020, 1, 2, 8),
          sender: 'عمر بيطار',
        ),
      ],
    ),
  ],
);

const _conversations = [
  ConversationSummary(
    id: 1,
    title: 'ليلى خالد',
    snippet: 'ذكرى السنة',
    messageCount: 4,
    firstAt: null,
    lastAt: null,
    platform: 'facebook',
  ),
  ConversationSummary(
    id: 2,
    title: 'عمر بيطار',
    snippet: 'وأنت سالم',
    messageCount: 2,
    firstAt: null,
    lastAt: null,
    platform: 'facebook',
  ),
];

MessagesSnapshot _snapshotFor(int? selectedId) {
  final thread = selectedId == 2 ? _omarThread : _leilaThread;
  return MessagesSnapshot(
    conversations: _conversations,
    totalConversations: 2,
    selected: thread,
  );
}

const _emptySnapshot = MessagesSnapshot(
  conversations: [],
  totalConversations: 0,
  selected: null,
);

Future<void> _pumpMessages(
  WidgetTester tester, {
  MessagesSnapshot Function(int? selectedId)? snapshot,
  ValueChanged<int>? onOpenPerson,
}) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The fake reads the selection, so tapping a row walks the same path
        // the real provider uses.
        messagesSnapshotProvider.overrideWith((ref) async {
          final selected = ref.watch(messagesSelectionProvider);
          return (snapshot ?? _snapshotFor)(selected);
        }),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MessagesScreen(onOpenPerson: onOpenPerson),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('draws the conversation list and the newest thread', (
    tester,
  ) async {
    await _pumpMessages(tester);

    expect(find.byKey(const Key('messages-count')), findsOneWidget);
    expect(find.text('2 محادثة'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('messages-conversation-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('messages-conversation-2')),
      findsOneWidget,
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('messages-thread-title'))).data,
      'ليلى خالد',
    );
    expect(find.text('من 2019 · 4 رسالة · فيسبوك'), findsOneWidget);

    expect(find.text('12 آذار 2019'), findsOneWidget);
    expect(find.text('24 آب 2021'), findsOneWidget);
    expect(find.text('Loaded 4 of 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('messages-bubble-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('messages-bubble-14')), findsOneWidget);
    // A thread with two senders labels each bubble it draws.
    expect(find.text('سامر'), findsOneWidget);
    expect(
      find.byKey(const Key('messages-attachment-placeholder')),
      findsOneWidget,
    );
  });

  testWidgets('selecting a conversation swaps the thread', (tester) async {
    await _pumpMessages(tester);

    await tester.tap(find.byKey(const ValueKey('messages-conversation-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Text>(find.byKey(const Key('messages-thread-title'))).data,
      'عمر بيطار',
    );
    expect(find.byKey(const ValueKey('messages-bubble-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('messages-bubble-11')), findsNothing);
    expect(find.text('2 كانون الثاني 2020'), findsOneWidget);

    expect(find.byKey(const ValueKey('messages-bubble-11')), findsNothing);
  });

  testWidgets('desktop matches the owner layout and shortcut list', (
    tester,
  ) async {
    await _pumpMessages(tester);

    expect(find.byKey(const Key('messages-shortcuts')), findsOneWidget);
    expect(find.byKey(const Key('messages-list-panel')), findsOneWidget);
    expect(find.byKey(const Key('messages-thread-panel')), findsOneWidget);
    for (final label in [
      'ملفي',
      'الرئيسية',
      'قصتك بالأرقام',
      'التحليلات',
      'الرسائل',
      'الصور',
      'الأشخاص',
      'الإعدادات',
    ]) {
      expect(find.byKey(ValueKey('messages-shortcut-$label')), findsOneWidget);
    }
    expect(find.byKey(const Key('messages-count-badge-1')), findsOneWidget);
    expect(find.byKey(const Key('messages-count-badge-2')), findsOneWidget);
  });

  testWidgets('the reply field is disabled and says so', (tester) async {
    await _pumpMessages(tester);

    final composer = tester.widget<TextField>(
      find.byKey(const Key('messages-composer')),
    );
    expect(composer.enabled, isFalse);
    expect(
      find.text('هاي محادثة من ماضيك — للقراءة بس، لا يتم إرسال أي رسائل'),
      findsOneWidget,
    );
  });

  testWidgets('search narrows the list without touching the thread', (
    tester,
  ) async {
    await _pumpMessages(tester);

    await tester.enterText(find.byKey(const Key('messages-search')), 'عمر');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('messages-conversation-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('messages-conversation-1')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('messages-search')),
      'nothing-matches',
    );
    await tester.pump();

    expect(find.byKey(const Key('messages-no-match')), findsOneWidget);
  });

  testWidgets('an empty archive shows one honest card', (tester) async {
    await _pumpMessages(tester, snapshot: (_) => _emptySnapshot);

    expect(find.byKey(const Key('messages-empty')), findsOneWidget);
    expect(find.text('ما في محادثات بعد'), findsOneWidget);
    expect(find.byKey(const Key('messages-list-panel')), findsNothing);
  });

  testWidgets('a sender name opens that participant’s profile', (tester) async {
    final opened = <int>[];
    final thread = ConversationThread(
      id: 1,
      title: 'ليلى خالد',
      messageCount: 1,
      firstAt: null,
      lastAt: null,
      platform: 'facebook',
      senderCount: 2,
      loadedCount: 1,
      primarySenderId: 1,
      days: [
        MessageDay(
          date: DateTime.utc(2019, 3, 12),
          bubbles: [
            _bubble(
              77,
              'شو أخبارك؟',
              fromPrimary: false,
              sender: 'عمر بيطار',
              actorId: 42,
            ),
          ],
        ),
      ],
    );
    await _pumpMessages(
      tester,
      onOpenPerson: opened.add,
      snapshot: (_) => MessagesSnapshot(
        conversations: _conversations,
        totalConversations: 2,
        selected: thread,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('messages-sender-77')));
    await tester.pump();

    // The bubble carries the stored actor id; the host opens that profile.
    expect(opened, [42]);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('messages-bubble-77')),
        matching: find.text('عمر بيطار'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Arabic renders right-to-left with 44px rows', (tester) async {
    await _pumpMessages(tester);

    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('messages-thread-panel'))),
      ),
      TextDirection.rtl,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('messages-conversation-1')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('messages-search'))).height,
      greaterThanOrEqualTo(44),
    );
  });
}
