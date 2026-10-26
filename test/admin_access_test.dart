import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/models/admin_access.dart';

void main() {
  group('admin access context', () {
    test('wildcard role permission matches every admin permission', () {
      const access = AdminAccessContext(
        userId: 'admin',
        status: 'active',
        role: 'super_admin',
        permissions: {'*'},
      );
      expect(access.isAdmin, isTrue);
      expect(access.hasPermission('withdrawals.process'), isTrue);
    });

    test('namespace wildcard matches only its permission family', () {
      const access = AdminAccessContext(
        userId: 'moderator',
        status: 'active',
        role: 'moderator',
        permissions: {'reports.*', 'tickets.view'},
      );
      expect(access.hasPermission('reports.resolve'), isTrue);
      expect(access.hasPermission('tickets.view'), isTrue);
      expect(access.hasPermission('withdrawals.view'), isFalse);
    });

    test('banned and suspended states are distinct', () {
      const banned = AdminAccessContext(
        userId: 'buyer',
        status: 'banned',
        role: null,
        permissions: {},
      );
      const suspended = AdminAccessContext(
        userId: 'seller',
        status: 'suspended',
        role: null,
        permissions: {},
      );
      expect(banned.isBanned, isTrue);
      expect(suspended.isSuspended, isTrue);
      expect(suspended.isBanned, isFalse);
    });

    test('routing prioritizes restriction over an admin role', () {
      const access = AdminAccessContext(
        userId: 'restricted-admin',
        status: 'banned',
        role: 'super_admin',
        permissions: {'*'},
      );
      expect(resolveAccessDestination(access), AccessDestination.restricted);
    });

    test('routes active admins and marketplace users separately', () {
      const admin = AdminAccessContext(
        userId: 'admin',
        status: 'active',
        role: 'moderator',
        permissions: {'tickets.view'},
      );
      const seller = AdminAccessContext(
        userId: 'seller',
        status: 'suspended',
        role: null,
        permissions: {},
      );
      expect(resolveAccessDestination(admin), AccessDestination.admin);
      expect(resolveAccessDestination(seller), AccessDestination.marketplace);
    });
  });
}
