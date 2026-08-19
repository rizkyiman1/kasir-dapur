import 'package:flutter/material.dart';
import 'package:kasir_dapur/config/brand.dart';

class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Brand.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Halaman tidak ditemukan.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
