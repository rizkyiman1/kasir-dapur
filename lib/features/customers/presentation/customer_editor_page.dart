import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class CustomerEditorPage extends ConsumerStatefulWidget {
  const CustomerEditorPage({super.key, this.existing});

  final Customer? existing;

  @override
  ConsumerState<CustomerEditorPage> createState() => _CustomerEditorPageState();
}

class _CustomerEditorPageState extends ConsumerState<CustomerEditorPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Customer? existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Customer? existing = widget.existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Pelanggan baru' : 'Edit pelanggan'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (existing != null) ...[
              Text('ID', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(existing.id),
              const SizedBox(height: 16),
            ],
            KdTextField(
              label: 'Nama',
              controller: _name,
              autofocus: existing == null,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              validator: AppValidators.displayName,
            ),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Nomor HP',
              controller: _phone,
              hint: 'Opsional',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              maxLength: 20,
              validator: AppValidators.optionalPhone,
            ),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Alamat',
              controller: _address,
              hint: 'Opsional',
              textInputAction: TextInputAction.next,
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
              label: 'Catatan',
              controller: _notes,
              hint: 'Opsional, keperluan usaha saja',
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              validator: (String? value) => AppValidators.optionalText(
                value,
                maxLength: 500,
                fieldName: 'Catatan',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hanya nama yang wajib. Tidak perlu email, KTP, atau data pribadi lain.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: Text(existing == null ? 'Simpan' : 'Perbarui'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final String businessId =
          widget.existing?.businessId ??
          await ref.read(activeBusinessIdProvider.future);
      await ref
          .read(customerControllerProvider)
          .save(
            businessId: businessId,
            existing: widget.existing,
            name: _name.text,
            phone: _phone.text,
            address: _address.text,
            notes: _notes.text,
          );
      if (!mounted) {
        return;
      }
      context.showMessage(
        widget.existing == null
            ? 'Pelanggan disimpan.'
            : 'Data pelanggan diperbarui.',
      );
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      context.showMessage(ErrorHandler.userMessage(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
