import 'package:flutter_test/flutter_test.dart';
import 'package:devcase_test/providers/app_state.dart';
import 'package:devcase_test/models/app_models.dart';

void main() {
  group('Order Card Grouping by Assignee & Date Tests', () {
    late AppState appState;
    late UserModel john;
    late UserModel patis;

    setUp(() {
      appState = AppState();
      appState.orders.clear();
      john = const UserModel(id: 'EMP-002', name: 'John', role: 'Developer', email: 'john@company.com', password: '', avatarUrl: 'J');
      patis = const UserModel(id: 'EMP-001', name: 'Patis', role: 'Admin', email: 'patis@company.com', password: '', avatarUrl: 'P');
    });

    test('1. Two orders created by John on the same day should be grouped into 1 card', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '891934',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 1);
      expect(appState.orders.first.assignee?.id, john.id);
      expect(appState.orders.first.allItems.length, 2);
      expect(appState.orders.first.allItems.map((i) => i.id), ['870213', '891934']);
    });

    test('2. Order created by Patis on the same day must be a separate card', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '849201',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: patis,
        createBy: 'Patis',
      );

      expect(appState.orders.length, 2);
      expect(appState.orders[0].assignee?.id, patis.id);
      expect(appState.orders[0].allItems.map((i) => i.id), ['849201']);
      expect(appState.orders[1].assignee?.id, john.id);
      expect(appState.orders[1].allItems.map((i) => i.id), ['870213']);
    });

    test('3. Creating another order for John goes back to John card', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '849201',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: patis,
        createBy: 'Patis',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '891934',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 2);
      final johnCard = appState.orders.firstWhere((o) => o.assignee?.id == john.id);
      expect(johnCard.allItems.map((i) => i.id), ['870213', '891934']);
    });

    test('4 & 5. Bank Issue vs Order Diff and different assignees separate cards', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.bankIssue,
        orderNo: '392810',
        deliveryType: DeliveryType.sameday,
        priority: CasePriority.critical,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.bankIssue,
        orderNo: '492810',
        deliveryType: DeliveryType.sameday,
        priority: CasePriority.critical,
        assignee: patis,
        createBy: 'Patis',
      );

      expect(appState.orders.length, 3);
      expect(appState.orders.any((o) => o.cardType == OrderCardType.orderDiff && o.assignee?.id == john.id), true);
      expect(appState.orders.any((o) => o.cardType == OrderCardType.bankIssue && o.assignee?.id == john.id), true);
      expect(appState.orders.any((o) => o.cardType == OrderCardType.bankIssue && o.assignee?.id == patis.id), true);
    });

    test('6. Different date creates new card', () {
      appState.orders.add(OrderModel(
        id: '111111',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
        dateText: '10 พ.ย. 2569',
        standardDate: '2026-11-09',
        items: [const OrderItemModel(id: '111111', deliveryType: DeliveryType.express)],
      ));

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 2);
    });

    test('7. Null assignee handling', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '1001',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: null,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '1002',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: null,
        createBy: 'John',
      );

      expect(appState.orders.length, 1);
      expect(appState.orders.first.assignee, null);
      expect(appState.orders.first.allItems.map((i) => i.id), ['1001', '1002']);

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '1003',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 2);
    });

    test('8. Duplicate Order No. prevention', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 1);
      expect(appState.orders.first.allItems.length, 1);
    });

    test('9. Assignee of existing card does not change when adding new order', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.first.assignee?.id, john.id);

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '891934',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 1);
      expect(appState.orders.first.assignee?.id, john.id);
      expect(appState.orders.first.allItems.length, 2);
    });

    test('10. Update priority for newly created order card using sub-item ID', () {
      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '870213',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      appState.createOrderCard(
        cardType: OrderCardType.orderDiff,
        orderNo: '891934',
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: john,
        createBy: 'John',
      );

      expect(appState.orders.length, 1);
      final card = appState.orders.first;
      expect(card.priority, CasePriority.medium);

      final updated = card.copyWith(id: '891934', priority: CasePriority.high);
      appState.updateOrderCard(updated);

      expect(appState.orders.first.priority, CasePriority.high);
    });
  });

  group('AppState.groupOrdersIntoCards (Supabase multi-row grouping)', () {
    const john = UserModel(
      id: 'EMP-002',
      authUserId: 'uid-john',
      name: 'John',
      role: 'developer',
      email: 'john@company.com',
      avatarUrl: 'J',
    );
    const patis = UserModel(
      id: 'EMP-001',
      authUserId: 'uid-patis',
      name: 'Patis',
      role: 'admin',
      email: 'patis@company.com',
      avatarUrl: 'P',
    );

    OrderModel makeOrder({
      required String id,
      required OrderCardType cardType,
      required String standardDate,
      UserModel? assignee,
      DeliveryType deliveryType = DeliveryType.express,
    }) {
      return OrderModel(
        id: id,
        supabaseId: 'supa-$id',
        cardType: cardType,
        deliveryType: deliveryType,
        priority: CasePriority.medium,
        assignee: assignee,
        createBy: 'Admin',
        dateText: standardDate,
        standardDate: standardDate,
        items: [OrderItemModel(id: id, deliveryType: deliveryType)],
      );
    }

    test('groups same-day orders by assignee and separates Order Diff vs Bank Issue (including Unassigned)', () {
      final raw = [
        // Day 2026-11-25 - John - Order Diff (2 orders -> 1 card)
        makeOrder(id: '100001', cardType: OrderCardType.orderDiff, standardDate: '2026-11-25', assignee: john),
        makeOrder(id: '100002', cardType: OrderCardType.orderDiff, standardDate: '2026-11-25', assignee: john),
        // Day 2026-11-25 - John - Bank Issue (2 orders -> 1 separate card)
        makeOrder(id: '200001', cardType: OrderCardType.bankIssue, standardDate: '2026-11-25', assignee: john),
        makeOrder(id: '200002', cardType: OrderCardType.bankIssue, standardDate: '2026-11-25', assignee: john),
        // Day 2026-11-25 - Patis - Order Diff (1 order -> separate card for Patis)
        makeOrder(id: '100003', cardType: OrderCardType.orderDiff, standardDate: '2026-11-25', assignee: patis),
        // Day 2026-11-25 - Unassigned - Order Diff (2 orders -> 1 unassigned Order Diff card)
        makeOrder(id: '300001', cardType: OrderCardType.orderDiff, standardDate: '2026-11-25', assignee: null),
        makeOrder(id: '300002', cardType: OrderCardType.orderDiff, standardDate: '2026-11-25', assignee: null),
        // Day 2026-11-25 - Unassigned - Bank Issue (2 orders -> 1 separate unassigned Bank Issue card)
        makeOrder(id: '400001', cardType: OrderCardType.bankIssue, standardDate: '2026-11-25', assignee: null),
        makeOrder(id: '400002', cardType: OrderCardType.bankIssue, standardDate: '2026-11-25', assignee: null),
        // Day 2026-11-24 - Unassigned - Order Diff (different day -> separate card)
        makeOrder(id: '628096', cardType: OrderCardType.orderDiff, standardDate: '2026-11-24', assignee: null),
        makeOrder(id: '651210', cardType: OrderCardType.orderDiff, standardDate: '2026-11-24', assignee: null),
      ];

      final cards = AppState.groupOrdersIntoCards(raw);

      // Expected 6 cards total:
      // 2026-11-25: John OrderDiff, Patis OrderDiff, John BankIssue, Unassigned OrderDiff, Unassigned BankIssue (5)
      // 2026-11-24: Unassigned OrderDiff (1)
      expect(cards.length, 6);

      final johnDiff = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-25' && c.cardType == OrderCardType.orderDiff && c.assignee == john);
      expect(johnDiff.allItems.map((i) => i.id), ['100001', '100002']);

      final johnBank = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-25' && c.cardType == OrderCardType.bankIssue && c.assignee == john);
      expect(johnBank.allItems.map((i) => i.id), ['200001', '200002']);

      final patisDiff = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-25' && c.cardType == OrderCardType.orderDiff && c.assignee == patis);
      expect(patisDiff.allItems.map((i) => i.id), ['100003']);

      final unassignedDiffToday = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-25' && c.cardType == OrderCardType.orderDiff && c.assignee == null);
      expect(unassignedDiffToday.allItems.map((i) => i.id), ['300001', '300002']);

      final unassignedBankToday = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-25' && c.cardType == OrderCardType.bankIssue && c.assignee == null);
      expect(unassignedBankToday.allItems.map((i) => i.id), ['400001', '400002']);

      final unassignedDiffYesterday = cards.firstWhere((c) => c.effectiveStandardDate == '2026-11-24' && c.cardType == OrderCardType.orderDiff && c.assignee == null);
      expect(unassignedDiffYesterday.allItems.map((i) => i.id), ['628096', '651210']);
    });
  });
}
