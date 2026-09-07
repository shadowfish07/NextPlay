import 'package:flutter_test/flutter_test.dart';

import 'support/host_database.dart';
import 'support/account_sync_fixture.dart';

void main() {
  setUpAll(initializeHostDatabase);
  test(
    'old sync cancels when account changes during final reload',
    () => verifySyncCompletionAccountSwitch('sync_completion_account.db'),
  );
}
