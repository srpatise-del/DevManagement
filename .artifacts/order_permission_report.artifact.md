# Order Management Module - Role & Permission Management Implementation Report

This report summarizes the implementation of Role-Based Access Control (RBAC) and permission management for the **Order Management** module in `devcase_test`, operating alongside the existing Dev Case Management system while maintaining clear separation of permissions and data visibility rules.

---

## 1. Files Created and Modified

### [NEW] Files
- `lib/screens/edit_order_screen.dart`: Dedicated form screen for editing existing Order cards (Order Diff & Bank Issue).

### [MODIFIED] Files
- `lib/models/app_models.dart`:
  - Added `OrderActivityStatus` (Work Status: New, In Progress, Pending, Resolved, Closed).
  - Added `OrderPermission` enum and `OrderRolePermissionHelper` class for Order RBAC rules.
  - Added `activityStatus` field to `OrderModel`.
- `lib/providers/app_state.dart`:
  - Added role-based `filteredOrders` getter utilizing `OrderRolePermissionHelper.canAccessOrder`.
  - Added methods for order actions (`reassignOrderCard`, `updateOrderActivityStatus`, `deleteOrderCard`).
- `lib/screens/order_list_screen.dart`:
  - Integrated `filteredOrders` based on user role.
  - Conditionally rendered the Floating Action Button for creating new orders based on `OrderPermission.createOrder`.
- `lib/screens/order_detail_screen.dart`:
  - Added the **`อัปเดตสถานะ`** button in `bottomNavigationBar` for updating work status.
  - Integrated Assign/Reassign sheet (`_showOrderReassignSheet`) and Activity Status update sheet (`_showActivityStatusUpdateSheet`).
  - Added Delete confirmation dialog before deleting orders.

---

## 2. Role Permissions Matrix for Order Management

| Permission / Action | User | Developer | Team Lead | Admin |
| :--- | :---: | :---: | :---: | :---: |
| **order.view** | Own / Assigned | Team / Assigned | Team All | All |
| **order.create** | ✅ | ✅ | ✅ | ✅ |
| **order.edit** | Own (Pending) | ✅ | ✅ | ✅ |
| **order.delete** | ❌ | ❌ | ✅ | ✅ |
| **order.assign / reassign** | ❌ | ❌ | ✅ | ✅ |
| **order.change_priority** | ❌ | ❌ | ✅ | ✅ |
| **order.update_status (Work Status)** | ❌ | ✅ | ✅ | ✅ |
| **order.change_bank_status (C, P, M...)** | ❌ | ✅ | ✅ | ✅ |
| **order.comment / view_timeline** | ✅ | ✅ | ✅ | ✅ |

---

## 3. Separation of Order Status and Work Status

- **Order Status (Financial / Bank Issue)**:
  - Represented by `OrderStatus` (`C`, `P`, `M`, `E`, `X`, `W`), specific to **Bank Issue** cards.
- **Work Status (Activity / Progress Status)**:
  - Represented by `OrderActivityStatus` (`รอดำเนินการ`, `กำลังตรวจสอบ`, `กำลังแก้ไข`, `แก้ไขเสร็จสิ้น`, `ปิดงาน`), applicable to both Order Diff and Bank Issue cards.

---

## 4. Data Visibility Scope (`OrderRolePermissionHelper.canAccessOrder`)

- **User**: Views only orders created by them or assigned to them.
- **Developer**: Views assigned orders and orders within their assigned team.
- **Team Lead**: Views all orders within their team.
- **Admin**: Views all orders across all teams.

---

## 5. Summary of Verification & Testing

1. **User Role**: Successfully creates orders, views only their own orders, cannot delete or reassign orders.
2. **Developer Role**: Views team/assigned orders, updates work status and bank status, cannot delete orders.
3. **Team Lead Role**: Manages team orders, reassigns tasks, changes priority, updates work status.
4. **Admin Role**: Full access across all teams, including deleting orders with confirmation dialog.
5. **Isolation**: Changes to Order permissions and statuses do not affect Dev Case Management.
