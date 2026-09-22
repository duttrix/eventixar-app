import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/ticket.dart';
import '../../data/app_providers.dart';
import '../../shared/widgets/section_card.dart';

const _faltanColor = Color(0xFFC2780A);

/// Unified overview + key figures (former Resumen + Reportes).
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final ticketsAsync = ref.watch(eventTicketsProvider(eventId));
    final collabsAsync = ref.watch(eventCollaboratorsProvider(eventId));

    if (eventAsync.isLoading ||
        ticketsAsync.isLoading ||
        collabsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (eventAsync.hasError) {
      return Center(child: Text('No se pudo cargar: ${eventAsync.error}'));
    }
    if (ticketsAsync.hasError) {
      return Center(
        child: Text('No se pudo cargar tickets: ${ticketsAsync.error}'),
      );
    }
    if (collabsAsync.hasError) {
      return Center(
        child: Text('No se pudo cargar equipo: ${collabsAsync.error}'),
      );
    }

    final event = eventAsync.requireValue;
    final tickets = ticketsAsync.requireValue;
    final collaborators = collabsAsync.requireValue;
    final sellers = collaborators
        .where((c) => c.role == CollaboratorRole.seller)
        .toList();
    final validators = collaborators
        .where((c) => c.role == CollaboratorRole.validator)
        .toList();
    final collectors = collaborators
        .where((c) => c.role == CollaboratorRole.collector)
        .toList();

    final total = tickets.isEmpty ? event.ticketCount : tickets.length;

    var assigned = 0;
    var pool = 0;
    var assignedReserved = 0;
    var poolReserved = 0;
    var cobradasFull = 0;
    var cobradasGanancia = 0;
    var rendidasFull = 0;
    var rendidasGanancia = 0;
    var validados = 0;

    for (final ticket in tickets) {
      final isPool = ticket.status.isAssignablePool;
      final isProfit = ticket.settleMode == TicketSettleMode.profit;
      final isReserved = ticket.status == TicketStatus.reserved;
      final isCobrada =
          ticket.status == TicketStatus.collected ||
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered;
      final isRendida =
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered;

      if (isPool) {
        pool++;
        if (isReserved) poolReserved++;
      } else {
        assigned++;
        if (isReserved) assignedReserved++;
      }

      if (isCobrada) {
        if (isProfit) {
          cobradasGanancia++;
        } else {
          cobradasFull++;
        }
      }
      if (isRendida) {
        if (isProfit) {
          rendidasGanancia++;
        } else {
          rendidasFull++;
        }
      }
      if (ticket.status == TicketStatus.delivered && !isProfit) {
        validados++;
      }
    }
    if (tickets.isEmpty) pool = total;

    const sinCosto = 0;
    final aCobrar = (total - sinCosto).clamp(0, total);
    final cobradas = cobradasFull + cobradasGanancia;
    final faltanCobrar = (aCobrar - cobradas).clamp(0, aCobrar);
    final aRendir = aCobrar;
    final rendidas = rendidasFull + rendidasGanancia;
    final faltanRendir = (aRendir - rendidas).clamp(0, aRendir);
    final aValidar = (cobradas - cobradasGanancia).clamp(0, cobradas);
    final faltanValidar = (aValidar - validados).clamp(0, aValidar);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel(
          'Cantidad',
          trailing: Text(
            '$total',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Estado'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _EstadoCard(
                value: assigned,
                label: 'Asignadas',
                reserved: assignedReserved,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EstadoCard(
                value: pool,
                label: 'Pool',
                reserved: poolReserved,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Cobranza'),
        const SizedBox(height: 10),
        _EquationCard(
          intro: sinCosto > 0
              ? '$total tarjetas – $sinCosto sin costo = $aCobrar a cobrar'
              : '$total tarjetas = $aCobrar a cobrar',
          leftValue: aCobrar,
          leftLabel: 'A cobrar',
          midValue: cobradas,
          midLabel: 'Cobradas',
          midSubtitle: cobradas == 0
              ? null
              : cobradasGanancia > 0
              ? '$cobradasFull total · $cobradasGanancia ganancia'
              : '$cobradasFull total',
          rightValue: faltanCobrar,
          rightLabel: 'Faltan',
          progressLabel: 'Cobradas sobre el total',
          progressPart: cobradas,
          progressTotal: aCobrar,
          caption: aCobrar == 0
              ? 'Todavía no hay tickets para cobrar.'
              : '${_pct(cobradas, aCobrar)}% del total ya se cobró',
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Rendición'),
        const SizedBox(height: 10),
        _EquationCard(
          leftValue: aRendir,
          leftLabel: 'A rendir',
          midValue: rendidas,
          midLabel: 'Rendidas',
          midSubtitle: rendidas == 0
              ? null
              : rendidasGanancia > 0
              ? '$rendidasFull normales · $rendidasGanancia ganancia'
              : '$rendidasFull normales',
          rightValue: faltanRendir,
          rightLabel: 'Faltan',
          progressLabel: 'Rendidas sobre cobradas',
          progressPart: rendidas,
          progressTotal: cobradas,
          caption: cobradas == 0
              ? 'Cuando se cobre, acá se ve cuánto ya se rindió.'
              : '${_pct(rendidas, cobradas)}% de lo cobrado ya se rindió',
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Validación'),
        const SizedBox(height: 10),
        _EquationCard(
          intro: cobradasGanancia > 0
              ? '$cobradas cobradas – $cobradasGanancia ganancia = $aValidar a validar'
              : cobradas == 0
              ? null
              : '$cobradas cobradas = $aValidar a validar',
          leftValue: aValidar,
          leftLabel: 'A validar',
          midValue: validados,
          midLabel: 'Validados',
          rightValue: faltanValidar,
          rightLabel: 'Falta',
          progressLabel: 'Validados sobre cobradas',
          progressPart: validados,
          progressTotal: aValidar,
          caption: aValidar == 0
              ? 'Cuando se cobre, acá se ve cuánto ya se validó.'
              : '${_pct(validados, aValidar)}% de lo cobrado ya se validó',
        ),
        const SizedBox(height: 22),
        const _SectionLabel('Desempeño'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Vendedores',
          child: sellers.isEmpty
              ? const Text(
                  'Todavía no hay vendedores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final seller in sellers)
                      Builder(
                        builder: (context) {
                          final sold = tickets
                              .where(
                                (t) =>
                                    t.sellerId == seller.id &&
                                    (t.status == TicketStatus.collected ||
                                        t.status == TicketStatus.settled ||
                                        t.status == TicketStatus.delivered),
                              )
                              .length;
                          final held = tickets
                              .where(
                                (t) =>
                                    t.sellerId == seller.id &&
                                    (t.status == TicketStatus.withSeller ||
                                        t.status == TicketStatus.reserved),
                              )
                              .length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(seller.name)),
                                Text(
                                  '$sold cobrados · ${formatMoney(event.ticketPrice * sold)}'
                                  '${held > 0 ? ' · $held en mano' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Recaudadores',
          child: collectors.isEmpty
              ? const Text(
                  'Todavía no hay recaudadores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final collector in collectors)
                      Builder(
                        builder: (context) {
                          final collectorTickets = tickets
                              .where((t) => t.collectorId == collector.id)
                              .toList(growable: false);
                          final count = collectorTickets.length;
                          final amount = collectorTickets.fold<double>(
                            0,
                            (sum, t) =>
                                sum +
                                t.resolvedSettledAmount(event.ticketPrice),
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(collector.name)),
                                Text(
                                  '$count rendidos · ${formatMoney(amount)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Validadores',
          child: validators.isEmpty
              ? const Text(
                  'Todavía no hay validadores.',
                  style: TextStyle(color: AppColors.textMuted),
                )
              : Column(
                  children: [
                    for (final validator in validators)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(validator.name)),
                            Text(
                              '${tickets.where((t) => t.validatorId == validator.id).length} validados',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

int _pct(int part, int total) {
  if (total <= 0) return 0;
  return ((part / total) * 100).round();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _EstadoCard extends StatelessWidget {
  const _EstadoCard({
    required this.value,
    required this.label,
    required this.reserved,
  });

  final int value;
  final String label;
  final int reserved;

  @override
  Widget build(BuildContext context) {
    final ratio = value == 0 ? 0.0 : reserved / value;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _Bar(value: ratio),
          const SizedBox(height: 8),
          Text(
            '$reserved reservadas (${_pct(reserved, value)}%)',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EquationCard extends StatelessWidget {
  const _EquationCard({
    this.intro,
    required this.leftValue,
    required this.leftLabel,
    required this.midValue,
    required this.midLabel,
    this.midSubtitle,
    required this.rightValue,
    required this.rightLabel,
    required this.progressLabel,
    required this.progressPart,
    required this.progressTotal,
    required this.caption,
  });

  final String? intro;
  final int leftValue;
  final String leftLabel;
  final int midValue;
  final String midLabel;
  final String? midSubtitle;
  final int rightValue;
  final String rightLabel;
  final String progressLabel;
  final int progressPart;
  final int progressTotal;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ratio = progressTotal == 0 ? 0.0 : progressPart / progressTotal;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (intro != null) ...[
            Text(
              intro!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _EquationStat(
                  value: leftValue,
                  label: leftLabel,
                  color: AppColors.text,
                ),
              ),
              const _EquationOp('='),
              Expanded(
                child: _EquationStat(
                  value: midValue,
                  label: midLabel,
                  color: AppColors.successText,
                  subtitle: midSubtitle,
                ),
              ),
              const _EquationOp('+'),
              Expanded(
                child: _EquationStat(
                  value: rightValue,
                  label: rightLabel,
                  color: _faltanColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$progressPart / $progressTotal',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Bar(value: ratio),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              caption,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquationStat extends StatelessWidget {
  const _EquationStat({
    required this.value,
    required this.label,
    required this.color,
    this.subtitle,
  });

  final int value;
  final String label;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            maxLines: 1,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _EquationOp extends StatelessWidget {
  const _EquationOp(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        symbol,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: AppColors.border,
        color: AppColors.emerald,
      ),
    );
  }
}
