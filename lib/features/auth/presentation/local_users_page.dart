import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class LocalUsersPage extends ConsumerStatefulWidget {
  const LocalUsersPage({super.key});

  @override
  ConsumerState<LocalUsersPage> createState() => _LocalUsersPageState();
}

class _LocalUsersPageState extends ConsumerState<LocalUsersPage> {
  List<AuthUser> _users = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final List<AuthUser> users = await ref
        .read(authRepositoryProvider)
        .listUsers();
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    final bool? created = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => const _CreateUserDialog(),
    );
    if (created == true) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna lokal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_openCreate()),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
              itemCount: _users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final AuthUser user = _users[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text(user.displayName[0])),
                  title: Text(user.displayName),
                  subtitle: Text(user.role.label),
                );
              },
            ),
    );
  }
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  UserRole _role = UserRole.cashier;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .createUser(
          displayName: _nameController.text,
          pin: _pinController.text,
          role: _role,
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(true),
      onFailure: (error) => context.showError(error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah pengguna'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KdTextField(
                label: 'Nama tampilan',
                controller: _nameController,
                validator: AppValidators.displayName,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Peran'),
                items: const [
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                  DropdownMenuItem(
                    value: UserRole.cashier,
                    child: Text('Kasir'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (UserRole? value) {
                        if (value != null) {
                          setState(() => _role = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              KdTextField(
                label: 'PIN ${AppConstants.pinLength} digit',
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: AppValidators.pin,
              ),
              const SizedBox(height: 12),
              KdTextField(
                label: 'Ulangi PIN',
                controller: _confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.pinLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (String? value) {
                  return AppValidators.pinConfirmation(
                    _pinController.text,
                    value,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
