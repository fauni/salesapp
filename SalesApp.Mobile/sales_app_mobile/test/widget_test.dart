import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app_mobile/core/jwt.dart';

void main() {
  test('Jwt.isExpired returns true for a malformed token', () {
    expect(Jwt.isExpired('not-a-jwt'), isTrue);
  });

  test('Jwt reads expiry and claims from a token payload', () {
    // header.payload.signature — payload has exp far in the future + a name claim.
    // {"exp":4102444800,"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name":"rep1"}
    const token =
        'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjQxMDI0NDQ4MDAsImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3dzLzIwMDUvMDUvaWRlbnRpdHkvY2xhaW1zL25hbWUiOiJyZXAxIn0.sig';
    expect(Jwt.isExpired(token), isFalse);
    expect(Jwt.username(token), 'rep1');
  });
}
