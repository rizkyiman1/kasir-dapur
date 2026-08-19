import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  int _step = 0;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .completeOnboarding(
          displayName: _nameController.text,
          pin: _pinController.text,
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) => context.showError(error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Brand.appName,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          Brand.tagline,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              Text(
                _step == 0 ? 'Selamat datang' : 'Buat PIN Owner',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 0
                    ? '${Brand.appName} siap dipakai offline untuk kasir UMKM dan toko retail.'
                    : 'PIN ${AppConstants.pinLength} digit tersimpan di perangkat ini, bukan di cloud.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _step == 0
                    ? _WelcomeBody()
                    : _PinForm(
                        formKey: _formKey,
                        nameController: _nameController,
                        pinController: _pinController,
                        confirmController: _confirmController,
                      ),
              ),
              if (_step == 0)
                KdButton(
                  label: 'Lanjutkan',
                  onPressed: () => setState(() => _step = 1),
                )
              else ...[
                KdButton(
                  label: 'Simpan dan masuk',
                  loading: _saving,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _step = 0),
                  child: const Text('Kembali'),
                ),
              ],
              const SizedBox(height: 16),
              const KdLegalFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        _InfoTile(
          icon: Icons.point_of_sale_outlined,
          title: 'Kasir cepat',
          subtitle: 'Transaksi tersimpan di SQLite perangkat, tetap jalan tanpa internet.',
          color: scheme.primary,
        ),
        _InfoTile(
          icon: Icons.inventory_2_outlined,
          title: 'Stok dan laporan',
          subtitle: 'Siap dikembangkan untuk warung, kedai, dan usaha kuliner.',
          color: scheme.secondary,
        ),
        _InfoTile(
          icon: Icons.verified_user_outlined,
          title: 'Gratis untuk mulai',
          subtitle: 'Paket Free, Pro, dan Business akan diatur kemudian. Tidak ada kunci pembayaran di aplikasi.',
          color: scheme.tertiary,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _PinForm extends StatelessWidget {
  const _PinForm({
    required this.formKey,
    required this.nameController,
    required this.pinController,
    required this.confirmController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController pinController;
  final TextEditingController confirmController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        children: [
          KdTextField(
            label: 'Nama tampilan',
            hint: 'Contoh: Budi',
            controller: nameController,
            textInputAction: TextInputAction.next,
            validator: AppValidators.displayName,
          ),
          const SizedBox(height: 16),
          KdTextField(
            label: 'PIN ${AppConstants.pinLength} digit',
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: AppConstants.pinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: AppValidators.pin,
          ),
          const SizedBox(height: 16),
          KdTextField(
            label: 'Ulangi PIN',
            controller: confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: AppConstants.pinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (String? value) {
              return AppValidators.pinConfirmation(pinController.text, value);
            },
          ),
        ],
      ),
    );
  }
}
