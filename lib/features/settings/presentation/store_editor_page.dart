import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class StoreEditorPage extends ConsumerStatefulWidget {
  const StoreEditorPage({super.key});

  @override
  ConsumerState<StoreEditorPage> createState() => _StoreEditorPageState();
}

class _StoreEditorPageState extends ConsumerState<StoreEditorPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _footer = TextEditingController();
  bool _ready = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _hydrate(StoreProfile profile) {
    if (_ready) {
      return;
    }
    _name.text = profile.name;
    _address.text = profile.address ?? '';
    _phone.text = profile.phone ?? '';
    _footer.text = profile.receiptFooter ?? '';
    _ready = true;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<StoreProfile> profile = ref.watch(storeProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usaha')),
      body: profile.when(
        loading: () => const KdLoadingView(message: 'Memuat data toko...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Data toko gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(storeProfileProvider),
          );
        },
        data: (StoreProfile data) {
          _hydrate(data);
          return Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('Nama toko, logo, alamat, telepon, footer receipt.'),
                const SizedBox(height: 16),
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundImage: data.hasLogo
                        ? FileImage(File(data.logoPath!))
                        : null,
                    child: data.hasLogo
                        ? null
                        : const Icon(Icons.storefront_outlined, size: 40),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => unawaited(_logo()),
                      child: const Text('Logo'),
                    ),
                    if (data.hasLogo)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => unawaited(_clearLogo()),
                        child: const Text('Hapus logo'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                KdTextField(
                  label: 'Nama toko',
                  controller: _name,
                  validator: AppValidators.displayName,
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'Alamat',
                  controller: _address,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 200,
                  validator: (String? value) => AppValidators.optionalText(
                    value,
                    maxLength: 200,
                    fieldName: 'Alamat',
                  ),
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'Telepon',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
                  ],
                  validator: AppValidators.optionalPhone,
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'Footer receipt',
                  controller: _footer,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 240,
                  hint: 'Teks di bawah struk, misalnya ucapan atau NPWP toko',
                  validator: (String? value) => AppValidators.optionalText(
                    value,
                    maxLength: 240,
                    fieldName: 'Footer receipt',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => unawaited(_save()),
                  child: const Text('Simpan'),
                ),
                const SizedBox(height: 32),
                const KdLegalFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _logo() async {
    setState(() => _saving = true);
    try {
      final StoreProfile? saved = await ref
          .read(storeSettingsControllerProvider)
          .pickLogo();
      if (saved != null && mounted) {
        context.showMessage('Logo toko disimpan.');
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _clearLogo() async {
    setState(() => _saving = true);
    try {
      await ref.read(storeSettingsControllerProvider).removeLogo();
      if (mounted) {
        context.showMessage('Logo dihapus.');
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(storeSettingsControllerProvider)
          .save(
            StoreProfilePatch(
              name: _name.text,
              address: _address.text,
              phone: _phone.text,
              receiptFooter: _footer.text,
              clearAddress: _address.text.trim().isEmpty,
              clearPhone: _phone.text.trim().isEmpty,
              clearFooter: _footer.text.trim().isEmpty,
            ),
          );
      if (mounted) {
        context.showMessage('Data toko disimpan.');
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
