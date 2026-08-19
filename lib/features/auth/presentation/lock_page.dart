import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_pin_pad.dart';

class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  String _pin = '';
  bool _busy = false;

  Future<void> _onPinChanged(String value) async {
    setState(() => _pin = value);
    if (value.length != AppConstants.pinLength || _busy) {
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .unlock(value);
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
    final AuthState auth = ref.watch(authControllerProvider);
    final String name = auth.user?.displayName ?? 'Pengguna';
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                'Layar terkunci',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan PIN $name untuk membuka.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              KdPinPad(value: _pin, enabled: !_busy, onChanged: _onPinChanged),
              const Spacer(),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => unawaited(
                        ref.read(authControllerProvider.notifier).logout(),
                      ),
                child: const Text('Keluar'),
              ),
              const SizedBox(height: 16),
              const KdLegalFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
