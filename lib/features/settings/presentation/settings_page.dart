import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/core/permissions/permission_policy.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_controller.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/presentation/printers_controller.dart';
import 'package:kasir_dapur/features/settings/domain/legal_documents.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/presentation/legal_text_page.dart';
import 'package:kasir_dapur/features/settings/presentation/settings_controller.dart';
import 'package:kasir_dapur/features/settings/presentation/store_editor_page.dart';
import 'package:kasir_dapur/features/settings/presentation/theme_controller.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/services/settings_repository.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemePreference theme = ref.watch(themeControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final PermissionGuard guard = ref.watch(permissionGuardProvider);
    final AccessContext access = AuthStateAccessContext(auth);
    final bool canSettings = guard.can(access, AppPermission.manageSettings);
    final bool canUsers = guard.can(access, AppPermission.manageUsers);
    final bool canStock = guard.can(access, AppPermission.manageStock);
    final bool canPrinters = guard.can(access, AppPermission.managePrinters);
    final bool canSubscription = guard.can(
      access,
      AppPermission.manageSubscription,
    );
    final bool canSync = guard.can(access, AppPermission.manageSync);
    final bool isOwner = auth.user?.role == UserRole.owner;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Tampilan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AppThemePreference>(
            segments: const [
              ButtonSegment(
                value: AppThemePreference.system,
                label: Text('Sistem'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: AppThemePreference.light,
                label: Text('Terang'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: AppThemePreference.dark,
                label: Text('Gelap'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: <AppThemePreference>{theme},
            onSelectionChanged: (Set<AppThemePreference> value) {
              unawaited(
                ref
                    .read(themeControllerProvider.notifier)
                    .setPreference(value.first),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Kunci layar'),
            onTap: () {
              unawaited(ref.read(authControllerProvider.notifier).lock());
            },
          ),
          if (canSettings) ...[
            const SizedBox(height: 16),
            Text('BUSINESS', style: Theme.of(context).textTheme.titleMedium),
            const _BusinessSection(),
          ],
          if (canPrinters) ...[
            const SizedBox(height: 16),
            Text('PRINTER', style: Theme.of(context).textTheme.titleMedium),
            const _PrinterSection(),
          ],
          if (canSettings || canStock) ...[
            const SizedBox(height: 16),
            Text('POS', style: Theme.of(context).textTheme.titleMedium),
            _PosSection(canSettings: canSettings, canStock: canStock),
          ],
          const SizedBox(height: 16),
          Text('USER', style: Theme.of(context).textTheme.titleMedium),
          _UserSection(canManageUsers: canUsers),
          if (canSubscription) ...[
            const SizedBox(height: 16),
            Text(
              'SUBSCRIPTION',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const _SubscriptionSection(),
          ],
          if (canSettings || canSync) ...[
            const SizedBox(height: 16),
            Text('BACKUP', style: Theme.of(context).textTheme.titleMedium),
            _BackupSection(canBackup: canSettings, canSync: canSync),
          ],
          const SizedBox(height: 16),
          Text('PRIVACY', style: Theme.of(context).textTheme.titleMedium),
          _PrivacySection(canDeleteAccount: isOwner),
          const SizedBox(height: 16),
          Text('LEGAL', style: Theme.of(context).textTheme.titleMedium),
          const _LegalSection(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              unawaited(ref.read(authControllerProvider.notifier).logout());
            },
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
          const SizedBox(height: 32),
          const KdLegalFooter(),
        ],
      ),
    );
  }
}

class _BusinessSection extends ConsumerWidget {
  const _BusinessSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StoreProfile> profile = ref.watch(storeProfileProvider);
    final StoreProfile? data = profile.asData?.value;
    return KdSectionCard(
      onTap: () {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const StoreEditorPage(),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(data?.name ?? 'Nama toko'),
            subtitle: Text(
              [
                if (data?.address != null) data!.address!,
                if (data?.phone != null) data!.phone!,
                'Logo · Alamat · Telepon · Footer receipt',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _PrinterSection extends ConsumerWidget {
  const _PrinterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PrinterProfile> profile = ref.watch(
      printerProfileProvider,
    );
    final PrinterProfile? data = profile.asData?.value;
    return KdSectionCard(
      onTap: () => context.push(AppRoutes.printers),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.print_outlined),
        title: const Text('Printer'),
        subtitle: Text(
          [
            data?.paperSize.label ?? 'Paper size',
            if (data?.autoPrint == true)
              'Auto print aktif'
            else
              'Auto print nonaktif',
            if (data?.deviceName != null) data!.deviceName!,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _PosSection extends ConsumerWidget {
  const _PosSection({required this.canSettings, required this.canStock});

  final bool canSettings;
  final bool canStock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StoreProfile> profile = ref.watch(storeProfileProvider);
    final StoreProfile? store = profile.asData?.value;
    return KdSectionCard(
      child: Column(
        children: [
          if (canSettings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default payment'),
              subtitle: Text(store?.defaultPayment.label ?? 'Tunai'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(_pickPayment(context, ref, store)),
            ),
          if (canStock) const _AllowNegativeStockTile(),
          if (canSettings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Receipt behavior'),
              subtitle: Text(
                store?.receiptBehavior.label ?? ReceiptBehavior.ask.label,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(_pickReceipt(context, ref, store)),
            ),
        ],
      ),
    );
  }

  Future<void> _pickPayment(
    BuildContext context,
    WidgetRef ref,
    StoreProfile? store,
  ) async {
    final PaymentMethod? chosen = await showModalBottomSheet<PaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Default payment')),
            for (final PaymentMethod method in PaymentMethod.values)
              ListTile(
                title: Text(method.label),
                trailing:
                    method == (store?.defaultPayment ?? PaymentMethod.cash)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        );
      },
    );
    if (chosen == null) {
      return;
    }
    try {
      await ref
          .read(storeSettingsControllerProvider)
          .save(StoreProfilePatch(defaultPayment: chosen));
      if (context.mounted) {
        context.showMessage('Default payment disimpan.');
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }

  Future<void> _pickReceipt(
    BuildContext context,
    WidgetRef ref,
    StoreProfile? store,
  ) async {
    final ReceiptBehavior? chosen = await showModalBottomSheet<ReceiptBehavior>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Receipt behavior')),
            for (final ReceiptBehavior behavior in ReceiptBehavior.values)
              ListTile(
                title: Text(behavior.label),
                subtitle: Text(behavior.subtitle),
                trailing:
                    behavior == (store?.receiptBehavior ?? ReceiptBehavior.ask)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(behavior),
              ),
          ],
        );
      },
    );
    if (chosen == null) {
      return;
    }
    try {
      await ref
          .read(storeSettingsControllerProvider)
          .save(StoreProfilePatch(receiptBehavior: chosen));
      if (context.mounted) {
        context.showMessage('Receipt behavior disimpan.');
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }
}

class _AllowNegativeStockTile extends ConsumerWidget {
  const _AllowNegativeStockTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> allow = ref.watch(allowNegativeStockProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Negative stock'),
      subtitle: const Text(
        'Default nonaktif. Transaksi tidak boleh melebihi stok.',
      ),
      value: allow.asData?.value ?? false,
      onChanged: allow.isLoading
          ? null
          : (bool value) {
              unawaited(_set(context, ref, value));
            },
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, bool allow) async {
    try {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await ref
          .read(stockRepositoryProvider)
          .setAllowNegativeStock(businessId: businessId, allow: allow);
      ref.invalidate(allowNegativeStockProvider);
      if (context.mounted) {
        context.showMessage(
          allow ? 'Stok negatif diizinkan' : 'Stok negatif dinonaktifkan',
        );
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }
}

class _UserSection extends ConsumerWidget {
  const _UserSection({required this.canManageUsers});

  final bool canManageUsers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final PermissionPolicy policy = PermissionPolicy.standard();
    return KdSectionCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password),
            title: const Text('PIN'),
            subtitle: Text(
              'PIN ${AppConstants.pinLength} digit pengguna ${auth.user?.displayName ?? ''}',
            ),
            onTap: () => unawaited(_changePin(context, ref)),
          ),
          if (canManageUsers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Owner, Admin, Cashier'),
              subtitle: const Text('Pengguna lokal dan PIN di perangkat ini'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.users),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Permission'),
            subtitle: const Text('Izin Owner, Admin, dan Kasir'),
            children: [
              for (final UserRole role in UserRole.values)
                ExpansionTile(
                  title: Text(role.label),
                  children: [
                    for (final AppPermission permission in AppPermission.values)
                      ListTile(
                        dense: true,
                        title: Text(permission.label),
                        trailing: Icon(
                          policy.allows(role, permission)
                              ? Icons.check
                              : Icons.remove,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changePin(BuildContext context, WidgetRef ref) async {
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();
    final TextEditingController confirm = TextEditingController();
    final GlobalKey<FormState> form = GlobalKey<FormState>();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ganti PIN'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KdTextField(
                  label: 'PIN saat ini',
                  controller: current,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: AppConstants.pinLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: AppValidators.pin,
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'PIN baru',
                  controller: next,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: AppConstants.pinLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: AppValidators.pin,
                ),
                const SizedBox(height: 12),
                KdTextField(
                  label: 'Ulangi PIN baru',
                  controller: confirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: AppConstants.pinLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (String? value) {
                    return AppValidators.pinConfirmation(next.text, value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    final String currentPin = current.text;
    final String newPin = next.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok != true || !context.mounted) {
      return;
    }
    final result = await ref
        .read(authControllerProvider.notifier)
        .changePin(currentPin: currentPin, newPin: newPin);
    if (!context.mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) => context.showMessage('PIN disimpan.'),
      onFailure: (error) => context.showError(error),
    );
  }
}

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(planSnapshotProvider).asData?.value;
    final current = snapshot?.subscription;
    String expiry = 'Memuat status...';
    if (current != null) {
      expiry = current.endsAt == null
          ? 'Tidak kedaluwarsa'
          : 'Kedaluwarsa ${DateFormatter.dateId(DateTime.fromMillisecondsSinceEpoch(current.endsAt!))}';
    }
    return KdSectionCard(
      onTap: () => context.push(AppRoutes.subscription),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(current?.planCode.label ?? 'Plan'),
        subtitle: Text([expiry, 'Upgrade', 'Payment history'].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({required this.canBackup, required this.canSync});

  final bool canBackup;
  final bool canSync;

  @override
  Widget build(BuildContext context) {
    return KdSectionCard(
      child: Column(
        children: [
          if (canBackup)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Backup'),
              subtitle: const Text('Backup Now, Restore, Last Backup'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.backup),
            ),
          if (canSync)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: const Text('Sync'),
              subtitle: const Text('Google Sheets, antrian, coba lagi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.sync),
            ),
        ],
      ),
    );
  }
}

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection({required this.canDeleteAccount});

  final bool canDeleteAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KdSectionCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              title: LegalDocuments.privacyTitle,
              body: LegalDocuments.privacyBody,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              title: LegalDocuments.termsTitle,
              body: LegalDocuments.termsBody,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security_outlined),
            title: const Text('Data & Keamanan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              title: LegalDocuments.dataSafetyTitle,
              body: LegalDocuments.dataSafetyBody,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: const Text('Cara Menggunakan Aplikasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              title: LegalDocuments.appAccessTitle,
              body: LegalDocuments.appAccessBody,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Support & Kontak'),
            subtitle: const Text(Brand.websiteUrl),
            onTap: () => unawaited(_openSupport(context)),
          ),
          if (canDeleteAccount) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Hapus Akun — Panduan'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(
                context,
                title: LegalDocuments.accountDeletionTitle,
                body: LegalDocuments.accountDeletionBody,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.person_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Hapus Akun',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text(
                'Hapus pengguna lokal di perangkat ini. Database tidak di-DROP.',
              ),
              onTap: () => unawaited(_deleteAccount(context, ref)),
            ),
          ],
        ],
      ),
    );
  }

  void _push(
    BuildContext context, {
    required String title,
    required String body,
    bool footerUrl = false,
  }) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              LegalTextPage(title: title, body: body, footerUrl: footerUrl),
        ),
      ),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final Uri uri = Uri.parse(Brand.websiteUrl);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _push(
          context,
          title: LegalDocuments.supportTitle,
          body: LegalDocuments.supportBody,
          footerUrl: true,
        );
      }
    } catch (_) {
      if (context.mounted) {
        _push(
          context,
          title: LegalDocuments.supportTitle,
          body: LegalDocuments.supportBody,
          footerUrl: true,
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final TextEditingController confirm = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ini menghapus Owner, Admin, dan Kasir di perangkat ini, '
                'lalu kembali ke onboarding. Tabel SQLite tidak di-DROP.',
              ),
              const SizedBox(height: 12),
              KdTextField(
                label: 'Ketik HAPUS',
                controller: confirm,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(confirm.text.trim().toUpperCase() == 'HAPUS');
              },
              child: const Text('Hapus akun'),
            ),
          ],
        );
      },
    );
    confirm.dispose();
    if (ok != true || !context.mounted) {
      if (ok == false && context.mounted) {
        context.showMessage('Penghapusan akun dibatalkan.');
      }
      return;
    }
    final result = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (!context.mounted) {
      return;
    }
    result.fold(
      onSuccess: (_) => context.showMessage('Akun perangkat dihapus.'),
      onFailure: (error) => context.showError(error),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection();

  @override
  Widget build(BuildContext context) {
    return const KdSectionCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Brand.appName),
            subtitle: Text(Brand.tagline),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Brand.companyName),
            subtitle: Text(Brand.ownerName),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(Brand.websiteHost),
            subtitle: Text(Brand.websiteUrl),
          ),
        ],
      ),
    );
  }
}
