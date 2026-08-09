import 'package:json_annotation/json_annotation.dart';

part 'login_response.g.dart';

/// Mirrors the backend `LoginResponse` (and the /auth/refresh response, which
/// has the same shape).
@JsonSerializable()
class LoginResponse {
  final String token;
  final String username;
  final String? salesEmployeeCode;
  final List<String> roles;

  const LoginResponse({
    required this.token,
    required this.username,
    this.salesEmployeeCode,
    this.roles = const [],
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}
