import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/sap_accounts/sap_account_form_bloc.dart';
import '../../data/models/sap_account.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/gradient_button.dart';
import '../widgets/section_card.dart';

/// Single form for both "new" and "edit" SAP account — [existing] null means
/// create. On edit the password field is optional (blank keeps the current
/// one). The backend tests the credentials against SAP before saving, so a
/// wrong user/password comes back as SAP's own error.
class SapAccountFormScreen extends StatefulWidget {
  final SapAccount? existing;
  const SapAccountFormScreen({super.key, this.existing});

  bool get isEdit => existing != null;

  @override
  State<SapAccountFormScreen> createState() => _SapAccountFormScreenState();
}

class _SapAccountFormScreenState extends State<SapAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name);
  late final _usernameController =
      TextEditingController(text: widget.existing?.username);
  final _passwordController = TextEditingController();
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final bloc = context.read<SapAccountFormBloc>();
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (widget.isEdit) {
      bloc.add(SapAccountUpdateSubmitted(
        id: widget.existing!.id,
        name: name,
        username: username,
        password: password.isEmpty ? null : password,
        isActive: _isActive,
      ));
    } else {
      bloc.add(SapAccountCreateSubmitted(
        name: name,
        username: username,
        password: password,
        isActive: _isActive,
      ));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario SAP'),
        content: Text('¿Eliminar "${widget.existing!.name}"? '
            'Solo se puede si no tiene usuarios asignados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context
        .read<SapAccountFormBloc>()
        .add(SapAccountDeleteSubmitted(widget.existing!.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SapAccountFormBloc, SapAccountFormState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        switch (state.status) {
          case SapAccountFormStatus.success:
          case SapAccountFormStatus.deleted:
            final message = state.status == SapAccountFormStatus.deleted
                ? 'Usuario SAP eliminado'
                : widget.isEdit
                    ? 'Usuario SAP actualizado'
                    : 'Usuario SAP creado';
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
            context.pop(true);
          case SapAccountFormStatus.failure:
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                  content: Text(
                      state.error ?? 'No se pudo guardar el usuario SAP')));
          case SapAccountFormStatus.idle:
          case SapAccountFormStatus.submitting:
            break;
        }
      },
      child: AppScaffold(
        title: widget.isEdit ? 'Editar usuario SAP' : 'Nuevo usuario SAP',
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre (descriptivo)',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá un nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Usuario SAP',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá el usuario SAP'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: widget.isEdit
                            ? 'Contraseña SAP (vacío = no cambiar)'
                            : 'Contraseña SAP',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          !widget.isEdit && (v == null || v.isEmpty)
                              ? 'Ingresá la contraseña SAP'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      subtitle: const Text(
                          'Inactivo: sus usuarios usan la cuenta técnica'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            // Backend rejects deleting an assigned account — deactivate it.
            if (widget.isEdit && widget.existing!.userCount == 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Eliminar usuario SAP'),
              ),
            ],
            const SizedBox(height: 20),
            BlocBuilder<SapAccountFormBloc, SapAccountFormState>(
              builder: (context, state) {
                return GradientButton(
                  label: widget.isEdit ? 'Guardar cambios' : 'Crear usuario SAP',
                  loading: state.status == SapAccountFormStatus.submitting,
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
