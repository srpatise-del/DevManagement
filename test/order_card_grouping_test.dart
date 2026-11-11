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
}
