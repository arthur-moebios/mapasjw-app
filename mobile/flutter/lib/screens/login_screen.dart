import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mobile_app_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key, required this.state});

  final MobileAppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Mapas JW',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Territórios e trajetos, com você no campo.',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: state.isSigningIn
                        ? null
                        : () => ref
                              .read(mobileAppControllerProvider.notifier)
                              .signInWithGoogle(),
                    icon: state.isSigningIn
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_circle_outlined),
                    label: Text(
                      state.isSigningIn
                          ? 'Aguardando o Google…'
                          : 'Entrar com Google',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _MessageCard(message: state.errorMessage!, isError: true),
                  ],
                  const SizedBox(height: 28),
                  _MessageCard(
                    icon: Icons.shield_outlined,
                    message: 'A localização será solicitada somente quando você tocar em “Minha localização” ou iniciar um trajeto. O acesso em segundo plano é pedido apenas para manter um trajeto ativo com a tela bloqueada.',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Sua conta e os territórios disponíveis são confirmados pelo sistema da sua congregação.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.icon, this.isError = false});

  final String message;
  final IconData? icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError
              ? colors.error.withValues(alpha: 0.16)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? (isError ? Icons.info_outline : Icons.info_outline),
            color: color,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
