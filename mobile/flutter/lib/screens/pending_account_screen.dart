import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/mobile_api.dart';
import '../state/mobile_app_controller.dart';

/// Conta criada pelo Google sem convite: existe, mas ainda não pertence a
/// nenhuma congregação. A indicação da congregação e o uso de convite são
/// feitos na web; aqui só se informa, se verifica de novo e se sai.
class PendingAccountScreen extends ConsumerStatefulWidget {
  const PendingAccountScreen({super.key, required this.state});

  final MobileAppState state;

  @override
  ConsumerState<PendingAccountScreen> createState() =>
      _PendingAccountScreenState();
}

class _PendingAccountScreenState extends ConsumerState<PendingAccountScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    setState(() => _checking = true);
    try {
      await ref.read(mobileAppControllerProvider.notifier).recheckAccount();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openWeb() async {
    final apiUri = Uri.parse(MobileApi.baseUrl);
    final uri = Uri.https(apiUri.host, '/cartas/aguardando');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o navegador.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = widget.state.errorMessage;

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
                      Icons.hourglass_top_rounded,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Aguardando liberação',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sua conta do Mapas JW foi criada, mas ainda não faz parte '
                    'de nenhuma congregação. Para liberar o acesso, use um '
                    'convite ou peça a quem cuida da sua congregação para '
                    'aprovar o seu pedido. Isso é feito no site.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Text(message, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _checking ? null : _recheck,
                    icon: _checking
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Verificar novamente'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openWeb,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Abrir no navegador'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _checking
                        ? null
                        : () => ref
                              .read(mobileAppControllerProvider.notifier)
                              .signOut(),
                    child: const Text('Sair'),
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
