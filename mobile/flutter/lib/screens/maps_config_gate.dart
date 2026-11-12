import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mobile_app_controller.dart';

/// Só monta o mapa depois que a chave do Google Maps foi entregue ao iPhone.
///
/// No iOS a chave vem do servidor e é configurada sob demanda. Criar um
/// `GoogleMap` antes disso derruba o app (o SDK nativo lança uma exceção), então
/// toda tela com mapa fora da aba Mapa precisa passar por aqui: o gate pede a
/// configuração e mostra um aviso enquanto ela não chega.
class MapsConfigGate extends ConsumerStatefulWidget {
  const MapsConfigGate({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  ConsumerState<MapsConfigGate> createState() => _MapsConfigGateState();
}

class _MapsConfigGateState extends ConsumerState<MapsConfigGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _configure();
    });
  }

  void _configure() {
    final state = ref.read(mobileAppControllerProvider).asData?.value;
    if (state == null || state.isMapsConfigured) return;
    unawaited(
      ref.read(mobileAppControllerProvider.notifier).ensureMapsConfigured(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mobileAppControllerProvider).asData?.value;
    if (state?.isMapsConfigured == true) return widget.builder(context);

    final error = state?.mapsConfigError;
    return ColoredBox(
      key: const ValueKey('maps-config-pending'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error == null)
                const CircularProgressIndicator()
              else
                const Icon(Icons.error_outline_rounded, size: 36),
              const SizedBox(height: 12),
              Text(error ?? 'Preparando o mapa…', textAlign: TextAlign.center),
              if (error != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _configure,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
