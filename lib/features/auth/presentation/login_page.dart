import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_repository.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_pin_pad.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  String _pin = '';
  bool _busy = false;
  List<AuthUser> _users = const [];
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUsers());
  }

  Future<void> _loadUsers() async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    final List<AuthUser> users = await repository.listUsers();
    if (!mounted) {
      return;
    }
    setState(() {
      _users = users;
      if (users.length == 1) {
        _selectedUserId = users.first.id;
      } else if (_selectedUserId != null &&
          users.every((AuthUser user) => user.id != _selectedUserId)) {
        _selectedUserId = null;
      }
    });
  }

  Future<void> _onPinChanged(String value) async {
    setState(() => _pin = value);
    if (value.length != AppConstants.pinLength || _busy) {
      return;
    }
    if (_users.length > 1 && _selectedUserId == null) {
      setState(() => _pin = '');
      context.showMessage('Pilih pengguna terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(pin: value, userId: _selectedUserId);
    if (!mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        setState(() {
          _pin = '';
          _busy = false;
        });
        context.showError(error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String subtitle = switch (_users.length) {
      0 => 'Masukkan PIN.',
      1 => 'Halo, ${_users.first.displayName}. Masukkan PIN.',
      _ =>
        _selectedUserId == null
            ? 'Pilih pengguna, lalu masukkan PIN.'
            : 'Masukkan PIN ${_users.firstWhere((AuthUser user) => user.id == _selectedUserId).displayName}.',
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'Masuk ke ${Brand.appName}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              if (_users.length > 1) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final AuthUser user in _users)
                      ChoiceChip(
                        label: Text('${user.displayName} · ${user.role.label}'),
                        selected: _selectedUserId == user.id,
                        onSelected: _busy
                            ? null
                            : (bool selected) {
                                setState(() {
                                  _selectedUserId = selected ? user.id : null;
                                  _pin = '';
                                });
                              },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              KdPinPad(value: _pin, enabled: !_busy, onChanged: _onPinChanged),
              const Spacer(),
              const KdLegalFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
