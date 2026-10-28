import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:a_messenger/auth/supabase_auth_repository.dart';

sb.User _user({List<sb.UserIdentity>? identities}) => sb.User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-28T00:00:00Z',
  identities: identities,
);

void main() {
  test('пустой identities — повторная регистрация существующей почты', () {
    expect(isRepeatedSignup(_user(identities: const [])), isTrue);
  });

  test('новая регистрация и отсутствие пользователя — не повтор', () {
    expect(
      isRepeatedSignup(
        _user(
          identities: [
            sb.UserIdentity(
              id: 'i1',
              userId: 'u1',
              identityData: const {},
              identityId: 'i1',
              provider: 'email',
              createdAt: '2026-10-28T00:00:00Z',
              lastSignInAt: '2026-10-28T00:00:00Z',
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(isRepeatedSignup(_user()), isFalse);
    expect(isRepeatedSignup(null), isFalse);
  });
}
