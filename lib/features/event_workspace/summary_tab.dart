import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/collaborator.dart';
import '../../data/models/event.dart';
import '../../data/models/event_product.dart';
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

    final total = tickets.isEmpty ? event.ticketCount : tickets.length;
    final poolTickets = <Ticket>[];
    final assignedTickets = <Ticket>[];

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
      final isReserved = _countsAsReserved(ticket);
      final isCobrada =
          ticket.status == TicketStatus.collected ||
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered;
      final isRendida =
          ticket.status == TicketStatus.settled ||
          ticket.status == TicketStatus.delivered;

      if (isPool) {
        pool++;
        poolTickets.add(ticket);
        if (isReserved) poolReserved++;
      } else {
        assigned++;
        assignedTickets.add(ticket);
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
        const _SectionLabel('Estado'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _EstadoCard(
                value: pool,
                label: 'En pool',
                reserved: poolReserved,
                onTap: () => _showEstadoDetail(
                  context,
                  title: 'En pool',
                  tickets: poolTickets,
                  event: event,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _EstadoCard(
                value: assigned,
                label: 'Asignados',
                reserved: assignedReserved,
                onTap: () => _showEstadoDetail(
                  context,
                  title: 'Asignados',
                  tickets: assignedTickets,
                  event: event,
                ),
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
        if (sellers.isNotEmpty) ...[
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
        ],
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
        const _SectionLabel('Por producto'),
        const SizedBox(height: 10),
        SectionCard(
          title: 'Qué se vendió',
          child: Column(
            children: [
              for (final product in event.products) ...[
                _ProductReport(event: event, product: product, tickets: tickets),
              ],
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

/// Still reserved, or reserved and later collected without clearing the hold.
bool _countsAsReserved(Ticket ticket) {
  if (ticket.status == TicketStatus.reserved) return true;
  final sold =
      ticket.status == TicketStatus.collected ||
      ticket.status == TicketStatus.settled ||
      ticket.status == TicketStatus.delivered;
  if (!sold) return false;
  var open = false;
  for (final entry in ticket.history) {
    if (entry.action == TicketHistoryAction.reserved) open = true;
    if (entry.action == TicketHistoryAction.reservationCleared) open = false;
  }
  return open;
}

void _showEstadoDetail(
  BuildContext context, {
  required String title,
  required List<Ticket> tickets,
  required Event event,
}) {
  final byStatus = <TicketStatus, int>{};
  for (final ticket in tickets) {
    byStatus[ticket.status] = (byStatus[ticket.status] ?? 0) + 1;
  }
  final reservedNow = byStatus[TicketStatus.reserved] ?? 0;
  final reservedThenSold = tickets
      .where(
        (ticket) =>
            ticket.status != TicketStatus.reserved && _countsAsReserved(ticket),
      )
      .length;

  final productLines = <String>[];
  for (final product in event.products) {
    final ofProduct = tickets
        .where((ticket) => event.productFor(ticket).id == product.id)
        .toList(growable: false);
    if (ofProduct.isEmpty) continue;
    if (event.products.length > 1) {
      productLines.add('${product.name}: ${ofProduct.length}');
    }
    for (final variant in product.variants) {
      final count = ofProduct
          .where((ticket) => ticket.variantId == variant.id)
          .length;
      if (count == 0) continue;
      final prefix = event.products.length > 1 ? '  ' : '';
      productLines.add('$prefix${variant.name}: $count');
    }
  }

  final rows = <(String, int)>[
    ('Sin vendedor', byStatus[TicketStatus.unassigned] ?? 0),
    ('Devueltos', byStatus[TicketStatus.returned] ?? 0),
    ('En poder del vendedor', byStatus[TicketStatus.withSeller] ?? 0),
    ('Reservados', reservedNow),
    ('Cobrados', byStatus[TicketStatus.collected] ?? 0),
    ('Rendidos', byStatus[TicketStatus.settled] ?? 0),
    ('Validados', byStatus[TicketStatus.delivered] ?? 0),
  ].where((row) => row.$2 > 0).toList(growable: false);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${tickets.length} tickets',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (tickets.isEmpty)
              const Text(
                'Todavía no hay tickets en este grupo.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.$1)),
                      Text(
                        '${row.$2}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            if (reservedThenSold > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$reservedThenSold se reservaron y después se cobraron.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (productLines.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'POR PRODUCTO',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              for (final line in productLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(line),
                ),
            ],
          ],
        ),
      );
    },
  );
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
    required this.onTap,
  });

  final int value;
  final String label;
  final int reserved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = value == 0 ? 0.0 : reserved / value;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Bar(value: ratio),
              const SizedBox(height: 8),
              Text(
                '$reserved con reserva (${_pct(reserved, value)}%)',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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

class _ProductReport extends StatelessWidget {
  const _ProductReport({
    required this.event,
    required this.product,
    required this.tickets,
  });

  final Event event;
  final EventProduct product;
  final List<Ticket> tickets;

  bool _sold(Ticket ticket) =>
      ticket.status == TicketStatus.collected ||
      ticket.status == TicketStatus.settled ||
      ticket.status == TicketStatus.delivered;

  @override
  Widget build(BuildContext context) {
    final ofProduct = tickets
        .where((ticket) => event.productFor(ticket).id == product.id)
        .toList(growable: false);
    final sold = ofProduct.where(_sold).toList(growable: false);
    final money = sold.fold<double>(
      0,
      (sum, ticket) => sum + (event.priceFor(ticket) ?? 0),
    );
    final profit = sold.fold<double>(
      0,
      (sum, ticket) => sum + (event.profitFor(ticket) ?? 0),
    );
    final pieces = product.unit.piecesPerSale > 1
        ? ' · ${sold.length * product.unit.piecesPerSale} u.'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${sold.length}/${ofProduct.length} · ${formatMoney(money)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Ganancia ${formatMoney(profit)}$pieces',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          for (final variant in product.variants)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                variant.quota > 0
                    ? '${variant.name}: ${sold.where((ticket) => ticket.variantId == variant.id).length} / ${variant.quota}'
                    : '${variant.name}: ${sold.where((ticket) => ticket.variantId == variant.id).length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
