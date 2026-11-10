import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:historiai/core/widgets/battle_slash_effect.dart';
import 'package:historiai/core/widgets/royal_edict_scroll.dart';
import 'package:historiai/core/widgets/vietnamese_decorations.dart';
import 'package:historiai/features/chat/widgets/chat_bubble.dart';
import 'package:historiai/features/timeline/widgets/animated_timeline_node.dart';

void main() {
  testWidgets('RoyalSealStamp finishes and honors reduced motion',
      (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: RoyalSealStamp(
              text: 'HOÀN THÀNH',
              onCompleted: () => completed++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('HOÀN THÀNH'), findsOneWidget);
    expect(completed, 1);
  });

  // 21/10: bỏ lớp hạt lửa khỏi DongSonBackground (làm app giật) — còn trống đồng + nội dung.
  testWidgets('DongSonBackground preserves drum -> content order',
      (tester) async {
    const contentKey = Key('motion-content');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DongSonBackground(child: SizedBox(key: contentKey)),
        ),
      ),
    );
    final stack = tester.widget<Stack>(find.byType(Stack).first);
    expect(stack.children.length, 2);
    expect(stack.children.last.key, contentKey);
  });

  testWidgets(
      'Timeline list keeps lesson nodes visible without intrinsic errors',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: List.generate(
              3,
              (index) => AnimatedTimelineNode(
                revealed: index == 0,
                lineProgress: index == 0 ? 0.8 : 0,
                isLast: index == 2,
                child: SizedBox(
                  key: Key('timeline-lesson-card-$index'),
                  height: 280,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    final first =
        tester.getRect(find.byKey(const Key('timeline-lesson-card-0')));
    expect(first.height, 280);
    expect(find.byType(AnimatedTimelineNode), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chiếu Thư opens vertically and closes through its action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return TextButton(
          onPressed: () => showRoyalEdictDialog(
            context,
            title: 'CHIẾU THƯ',
            recipient: 'Sĩ tử',
            rankTitle: 'Trạng nguyên',
            body: 'Nội dung chiếu thư.',
          ),
          child: const Text('Mở'),
        );
      }),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(find.text('CHIẾU THƯ'), findsOneWidget);
    await tester.tap(find.byTooltip('Kính Tuân Chỉ'));
    await tester.pump();
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RoyalEdictScrollDialog), findsNothing);
  });

  testWidgets('Battle slash does not block answer tap', (tester) async {
    var tapped = false;
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => tapped = true,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
            Positioned.fill(
              child: BattleSlashEffect(
                animation: controller,
                isCorrect: true,
              ),
            ),
          ],
        ),
      ),
    ));
    controller.forward();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(const Offset(20, 20));
    expect(tapped, isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    controller.dispose();
  });

  testWidgets('AI ink reveal keeps the full message readable', (tester) async {
    const message = 'Dòng thứ nhất. Dòng thứ hai vẫn đọc được.';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ChatBubble(
          text: message,
          sealText: 'ĐẠI VIỆT DANH NHÂN',
        ),
      ),
    ));
    expect(find.text(message), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(message), findsOneWidget);
  });
}
