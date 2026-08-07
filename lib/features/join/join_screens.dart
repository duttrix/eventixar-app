import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/collaborator.dart';
import '../../data/app_providers.dart';
import 'collector_workbench.dart';
import 'seller_workbench.dart';
import 'validator_workbench.dart';

/// Entry via deeplink. Routes seller / validator / collector portals.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _resolving = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    try {
      final collab = await ref
          .read(collaboratorRepositoryProvider)
          .findByToken(widget.token);
      if (!mounted) return;
      if (collab == null) {
        setState(() {
          _resolving = false;
          _error = 'Este deeplink no existe o ya no es válido.';
        });
        return;
      }
      await ref
          .read(sessionProvider.notifier)
          .enterAsCollaborator(widget.token, role: collab.role);
      if (!mounted) return;
      final path = switch (collab.role) {
        CollaboratorRole.seller => '/seller/${widget.token}',
        CollaboratorRole.validator => '/validator/${widget.token}',
        CollaboratorRole.collector => '/collector/${widget.token}',
        CollaboratorRole.coordinator => '/coordinator/${widget.token}',
      };
      context.go(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = 'No se pudo validar el link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Link inválido')),
        body: Center(child: Text(_error!)),
      );
    }
    return Scaffold(
      body: Center(
        child: _resolving
            ? const CircularProgressIndicator()
            : const Text('Redirigiendo…'),
      ),
    );
  }
}

/// Seller portal: digital tickets ready to print, sell and share (one or many).
class SellerPortalScreen extends ConsumerWidget {
  const SellerPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(collaboratorByTokenProvider(token));
    if (sellerAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final seller = sellerAsync.valueOrNull;
    if (seller == null || seller.role != CollaboratorRole.seller) {
      return const Scaffold(
        body: Center(child: Text('Vendedor no encontrado.')),
      );
    }

    return SellerWorkbench(
      eventId: seller.eventId,
      actorId: seller.id,
      actorLabel: seller.name,
      actorRole: 'seller',
      showLogout: true,
      lockedSellerId: seller.id,
    );
  }
}

/// Validator portal: scan / look up tickets and mark as delivered (pickup or entrance).
class ValidatorPortalScreen extends ConsumerWidget {
  const ValidatorPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validatorAsync = ref.watch(collaboratorByTokenProvider(token));
    if (validatorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final validator = validatorAsync.valueOrNull;
    if (validator == null || validator.role != CollaboratorRole.validator) {
      return const Scaffold(
        body: Center(child: Text('Validador no encontrado.')),
      );
    }

    return ValidatorWorkbench(
      eventId: validator.eventId,
      actorId: validator.id,
      actorLabel: validator.name,
      actorRole: 'validator',
      showLogout: true,
    );
  }
}

/// Portal del recaudador: elige vendedor y cobra (rinde) tickets ya cobrados.
class CollectorPortalScreen extends ConsumerWidget {
  const CollectorPortalScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectorAsync = ref.watch(collaboratorByTokenProvider(token));
    if (collectorAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final collector = collectorAsync.valueOrNull;
    if (collector == null || collector.role != CollaboratorRole.collector) {
      return const Scaffold(
        body: Center(child: Text('Recaudador no encontrado.')),
      );
    }

    return CollectorWorkbench(
      eventId: collector.eventId,
      actorId: collector.id,
      actorLabel: collector.name,
      actorRole: 'collector',
      showLogout: true,
    );
  }
}
