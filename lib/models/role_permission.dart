import 'package:flutter/material.dart';
import 'app_models.dart';

enum UserRole {
  user('User', 'ผู้ใช้งานทั่วไป'),
  developer('Developer', 'นักพัฒนา'),
  teamLead('Team Lead', 'หัวหน้าทีม'),
  admin('Admin', 'ผู้ดูแลระบบ');

  final String code;
  final String label;

  const UserRole(this.code, this.label);

  static UserRole fromString(String roleStr) {
    final lower = roleStr.trim().toLowerCase();
    if (lower.contains('admin') || lower.contains('sysadmin')) {
      return UserRole.admin;
    } else if (lower.contains('lead') || lower.contains('head')) {
      return UserRole.teamLead;
    } else if (lower.contains('dev') || lower.contains('developer') || lower.contains('qa')) {
      return UserRole.developer;
    }
    return UserRole.user;
  }
}

enum Permission {
  // Case View
  viewOwnCases,
  viewTeamCases,
  viewAllCases,

  // Case Actions
  createCase,
  editCase,
  editOwnCase,
  changeStatus,
  assignDeveloper,
  changeTeam,
  changeOwner,
  changePriority,
  closeCase,
  reopenCase,
  deleteCase,

  // Comments & Attachments
  addComment,
  manageAttachments,

  // Activities & Logs
  viewCaseActivity,
  viewTeamActivity,
  viewAllActivity,

  // User & System Management
  manageUsers,
  manageTeams,
  manageSystemSettings,
}

class RolePermissionHelper {
  /// Checks if a [role] has a specific [permission].
  static bool hasPermission(UserRole role, Permission permission) {
    switch (role) {
      case UserRole.admin:
        return true; // Admin has all permissions

      case UserRole.teamLead:
        return permission != Permission.manageUsers &&
            permission != Permission.deleteCase &&
            permission != Permission.manageSystemSettings &&
            permission != Permission.viewAllCases;

      case UserRole.developer:
        return permission == Permission.viewOwnCases ||
            permission == Permission.viewTeamCases ||
            permission == Permission.createCase ||
            permission == Permission.editCase ||
            permission == Permission.changeStatus ||
            permission == Permission.addComment ||
            permission == Permission.manageAttachments ||
            permission == Permission.viewCaseActivity ||
            permission == Permission.viewTeamActivity;

      case UserRole.user:
        return permission == Permission.viewOwnCases ||
            permission == Permission.createCase ||
            permission == Permission.editOwnCase ||
            permission == Permission.addComment ||
            permission == Permission.viewCaseActivity;
    }
  }

  /// Determines if a [user] can view/access a specific [caseObj].
  static bool canAccessCase(UserModel user, CaseModel caseObj) {
    final role = user.roleEnum;

    switch (role) {
      case UserRole.admin:
        return true; // Admin sees all cases

      case UserRole.teamLead:
        // Team Lead sees all cases in their team or assigned to them/created by them
        if (user.team != null && caseObj.team == user.team) return true;
        return caseObj.assignee == user || caseObj.createdById == user.id;

      case UserRole.developer:
        // Developer sees cases assigned to them OR in their team
        if (caseObj.assignee == user) return true;
        if (user.team != null && caseObj.team == user.team) return true;
        return caseObj.createdById == user.id;

      case UserRole.user:
        // User sees cases created by them or assigned to them or involved in
        if (caseObj.createdById == user.id || caseObj.assignee == user) return true;
        final involvedInComments = caseObj.comments.any((c) => c.author == user);
        if (involvedInComments) return true;
        final involvedInLogs = caseObj.activityLogs.any((l) => l.authorName.toLowerCase() == user.name.toLowerCase());
        return involvedInLogs;
    }
  }

  /// Determines if a [user] can edit a specific [comment].
  static bool canEditComment(UserModel user, CommentModel comment) {
    // Admins can edit any comment
    if (user.roleEnum == UserRole.admin) return true;
    
    // Otherwise, must be the owner (checked by authUserId/user ID)
    return user == comment.author;
  }

  /// Determines if a [user] can delete a specific [comment].
  static bool canDeleteComment(UserModel user, CommentModel comment) {
    // Admins can delete any comment
    if (user.roleEnum == UserRole.admin) return true;
    
    // Otherwise, must be the owner (checked by authUserId/user ID)
    return user == comment.author;
  }

  /// Gets allowed status transitions for a [role] given the current [CaseStatus].
  static List<CaseStatus> getAllowedStatuses(UserRole role, CaseStatus currentStatus) {
    if (role == UserRole.admin || role == UserRole.teamLead) {
      return CaseStatus.values;
    }

    if (role == UserRole.developer) {
      // Developer can switch between Open, Assigned, In Progress, Waiting, Testing, Done
      return [
        CaseStatus.open,
        CaseStatus.assigned,
        CaseStatus.inProgress,
        CaseStatus.waiting,
        CaseStatus.testing,
        CaseStatus.done,
      ];
    }

    // User can only view or keep current status
    return [currentStatus];
  }

  /// Gets the list of available overflow menu items for a [user] on a given [caseObj].
  static List<OverflowMenuItem> getOverflowMenuItems(UserModel user, CaseModel caseObj) {
    final role = user.roleEnum;
    final items = <OverflowMenuItem>[];

    switch (role) {
      case UserRole.user:
        // User: View History, Copy Case ID
        items.add(const OverflowMenuItem(
          key: 'history',
          label: 'ดูประวัติ',
          icon: Icons.history,
        ));
        items.add(const OverflowMenuItem(
          key: 'copy_id',
          label: 'คัดลอก Case ID',
          icon: Icons.copy_outlined,
        ));
        break;

      case UserRole.developer:
        // Developer: Add Comment, Manage Attachments, Change Status, View History
        items.add(const OverflowMenuItem(
          key: 'comment',
          label: 'เพิ่ม Comment',
          icon: Icons.chat_bubble_outline,
        ));
        items.add(const OverflowMenuItem(
          key: 'attachments',
          label: 'จัดการไฟล์แนบ',
          icon: Icons.attach_file,
        ));
        items.add(const OverflowMenuItem(
          key: 'status',
          label: 'เปลี่ยน Status',
          icon: Icons.swap_horiz,
        ));
        items.add(const OverflowMenuItem(
          key: 'history',
          label: 'ดูประวัติ',
          icon: Icons.history,
        ));
        break;

      case UserRole.teamLead:
        // Team Lead: Reassign, Change Team, Change Priority, Change Status, Close Case, Reopen Case, View History
        items.add(const OverflowMenuItem(
          key: 'assignee',
          label: 'เปลี่ยนผู้รับผิดชอบ',
          icon: Icons.person_add_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'team',
          label: 'เปลี่ยน Team',
          icon: Icons.groups_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'priority',
          label: 'เปลี่ยน Priority',
          icon: Icons.flag_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'status',
          label: 'เปลี่ยน Status',
          icon: Icons.swap_horiz,
        ));
        if (caseObj.status != CaseStatus.closed) {
          items.add(const OverflowMenuItem(
            key: 'close',
            label: 'Close Case',
            icon: Icons.check_circle_outline,
            iconColor: Colors.red,
          ));
        } else {
          items.add(const OverflowMenuItem(
            key: 'reopen',
            label: 'Reopen Case',
            icon: Icons.refresh,
            iconColor: Colors.green,
          ));
        }
        items.add(const OverflowMenuItem(
          key: 'history',
          label: 'ดูประวัติ',
          icon: Icons.history,
        ));
        break;

      case UserRole.admin:
        // Admin: Reassign, Change Team, Change Priority, Change Status, Manage Attachments, View History, Close Case, Reopen Case, Delete Case
        items.add(const OverflowMenuItem(
          key: 'assignee',
          label: 'เปลี่ยนผู้รับผิดชอบ',
          icon: Icons.person_add_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'team',
          label: 'เปลี่ยน Team',
          icon: Icons.groups_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'priority',
          label: 'เปลี่ยน Priority',
          icon: Icons.flag_outlined,
        ));
        items.add(const OverflowMenuItem(
          key: 'status',
          label: 'เปลี่ยน Status',
          icon: Icons.swap_horiz,
        ));
        items.add(const OverflowMenuItem(
          key: 'attachments',
          label: 'จัดการไฟล์แนบ',
          icon: Icons.attach_file,
        ));
        items.add(const OverflowMenuItem(
          key: 'history',
          label: 'ดูประวัติ',
          icon: Icons.history,
        ));
        if (caseObj.status != CaseStatus.closed) {
          items.add(const OverflowMenuItem(
            key: 'close',
            label: 'Close Case',
            icon: Icons.check_circle_outline,
            iconColor: Colors.red,
          ));
        } else {
          items.add(const OverflowMenuItem(
            key: 'reopen',
            label: 'Reopen Case',
            icon: Icons.refresh,
            iconColor: Colors.green,
          ));
        }
        items.add(const OverflowMenuItem(
          key: 'delete',
          label: 'Delete Case',
          icon: Icons.delete_outline,
          iconColor: Colors.red,
        ));
        break;
    }

    return items;
  }
}

class OverflowMenuItem {
  final String key;
  final String label;
  final IconData icon;
  final Color? iconColor;

  const OverflowMenuItem({
    required this.key,
    required this.label,
    required this.icon,
    this.iconColor,
  });
}


