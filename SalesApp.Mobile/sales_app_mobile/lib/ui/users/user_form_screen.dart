import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/users/user_form_bloc.dart';
import '../../data/models/app_user.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_card.dart';

/// Single form for both "new user" and "edit user" — [existing] null means
/// create. Username/password only apply to create (see UsersController: the
/// username can't be changed afterwards, and password changes go through the
/// separate reset-password dialog on edit).
class UserFormScreen extends StatefulWidget {
  final AppUser? existing;
  const UserFormScreen({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _usernameController =
      TextEditingController(text: widget.existing?.username);
  final _passwordController = TextEditingController();
  late final _salesEmployeeCodeController =
      TextEditingController(text: widget.existing?.salesEmployeeCode);
  late int _roleId = widget.existing?.roleId ?? AppRole.salesperson.id;
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _salesEmployeeCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final code = _salesEmployeeCodeController.text.trim();
    final bloc = context.read<UserFormBloc>();
    if (widget.isEdit) {
      bloc.add(UserFormUpdateSubmitted(
        id: widget.existing!.id,
        salesEmployeeCode: code.isEmpty ? null : code,
        roleId: _roleId,
        isActive: _isActive,
      ));
    } else {
      bloc.add(UserFormCreateSubmitted(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        salesEmployeeCode: code.isEmpty ? null : code,
        roleId: _roleId,
        isActive: _isActive,
      ));
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nueva contraseña'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newPassword == null || newPassword.length < 6) {
      if (newPassword != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('La contraseña debe tener al menos 6 caracteres')));
      }
      return;
    }
    if (!mounted) return;
    context.read<UserFormBloc>().add(UserFormPasswordResetSubmitted(
          id: widget.existing!.id,
          newPassword: newPassword,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserFormBloc, UserFormState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        switch (state.status) {
          case UserFormStatus.success:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                  content: Text(widget.isEdit
                      ? 'Usuario actualizado'
                      : 'Usuario creado')));
            context.pop(true);
          case UserFormStatus.passwordResetSuccess:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
          case UserFormStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                  content: Text(state.error ?? 'No se pudo guardar el usuario')));
          case UserFormStatus.idle:
          case UserFormStatus.submitting:
            break;
        }
      },
      child: AppScaffold(
        title: widget.isEdit ? 'Editar usuario' : 'Nuevo usuario',
        onBack: () => context.pop(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      enabled: !widget.isEdit,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá el usuario'
                          : null,
                    ),
                    if (!widget.isEdit) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _roleId,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        for (final role in AppRole.all)
                          DropdownMenuItem(
                              value: role.id, child: Text(role.name)),
                      ],
                      onChanged: (v) => setState(() => _roleId = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salesEmployeeCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Código de vendedor SAP (opcional)',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _resetPassword,
                icon: const Icon(Icons.password_rounded),
                label: const Text('Restablecer contraseña'),
              ),
            ],
            const SizedBox(height: 20),
            BlocBuilder<UserFormBloc, UserFormState>(
              builder: (context, state) {
                return GradientButton(
                  label: widget.isEdit ? 'Guardar cambios' : 'Crear usuario',
                  loading: state.status == UserFormStatus.submitting,
                  onPressed: _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
