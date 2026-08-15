part of 'user_form_bloc.dart';

sealed class UserFormEvent extends Equatable {
  const UserFormEvent();
  @override
  List<Object?> get props => [];
}

class UserFormCreateSubmitted extends UserFormEvent {
  final String username;
  final String password;
  final String? salesEmployeeCode;
  final int roleId;
  final bool isActive;

  const UserFormCreateSubmitted({
    required this.username,
    required this.password,
    this.salesEmployeeCode,
    required this.roleId,
    this.isActive = true,
  });

  @override
  List<Object?> get props =>
      [username, password, salesEmployeeCode, roleId, isActive];
}

class UserFormUpdateSubmitted extends UserFormEvent {
  final int id;
  final String? salesEmployeeCode;
  final int roleId;
  final bool isActive;

  const UserFormUpdateSubmitted({
    required this.id,
    this.salesEmployeeCode,
    required this.roleId,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, salesEmployeeCode, roleId, isActive];
}

class UserFormPasswordResetSubmitted extends UserFormEvent {
  final int id;
  final String newPassword;

  const UserFormPasswordResetSubmitted({
    required this.id,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [id, newPassword];
}
