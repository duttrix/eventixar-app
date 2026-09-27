import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/event_product.dart';

/// Editor for the products sold in an event.
class EventProductsEditor extends StatefulWidget {
  const EventProductsEditor({
    super.key,
    required this.initialProducts,
    this.catalog = const [],
    this.lockTicketCounts = false,
    this.enabled = true,
  });

  final List<EventProduct> initialProducts;
  final List<EventProduct> catalog;
  final bool lockTicketCounts;
  final bool enabled;

  @override
  State<EventProductsEditor> createState() => EventProductsEditorState();
}

class EventProductsEditorState extends State<EventProductsEditor> {
  late List<_ProductDraft> _products;

  @override
  void initState() {
    super.initState();
    final source = widget.initialProducts.isEmpty
        ? [
            EventProduct(
              id: newProductId(),
              name: '',
              unit: ProductUnit.unit,
              priceOnVariant: false,
              price: 2000,
              profit: 500,
              ticketCount: 100,
              variants: const [],
            ),
          ]
        : widget.initialProducts;
    _products = [for (final product in source) _ProductDraft.from(product)];
  }

  @override
  void dispose() {
    for (final product in _products) {
      product.dispose();
    }
    super.dispose();
  }

  /// First problem in the form, or null when it can be saved.
  String? validate() {
    if (_products.isEmpty) return 'Agregá al menos un producto.';
    for (final product in _products) {
      final name = product.name.text.trim();
      if (name.isEmpty) return 'Falta el nombre de un producto.';
      if (product.variants.isEmpty) {
        final count = int.tryParse(product.ticketCount.text.trim()) ?? 0;
        if (!widget.lockTicketCounts && count <= 0) {
          return 'Ingresá la cantidad de tickets de $name.';
        }
      } else {
        for (final variant in product.variants) {
          final option = variant.name.text.trim();
          final qty = int.tryParse(variant.quota.text.trim()) ?? 0;
          if (!widget.lockTicketCounts && qty <= 0) {
            final label = option.isEmpty ? 'una opción' : option;
            return 'Ingresá la cantidad de $label en $name.';
          }
        }
      }
      if (product.priceOnVariant) {
        if (product.variants.isEmpty) {
          return 'Agregá las opciones con precio de $name.';
        }
      } else if (_money(product.price.text) <= 0) {
        return 'Falta el precio de $name.';
      }
      if (_money(product.profit.text) < 0) {
        return 'La ganancia de $name no es válida.';
      }
      for (final variant in product.variants) {
        if (variant.name.text.trim().isEmpty) {
          return 'Falta el nombre de una opción de $name.';
        }
        if (product.priceOnVariant && _money(variant.price.text) <= 0) {
          return 'Falta el precio de una opción de $name.';
        }
        if (_money(variant.profit.text) < 0) {
          return 'La ganancia de una opción de $name no es válida.';
        }
      }
    }
    return null;
  }

  List<EventProduct> products() {
    return [for (final product in _products) product.toProduct()];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _products.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _ProductCard(
            draft: _products[i],
            enabled: widget.enabled,
            lockTicketCounts: widget.lockTicketCounts,
            canRemove: widget.enabled &&
                !widget.lockTicketCounts &&
                _products.length > 1,
            onChanged: () => setState(() {}),
            onRemove: () {
              final draft = _products.removeAt(i);
              setState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                draft.dispose();
              });
            },
          ),
        ],
        if (widget.enabled && !widget.lockTicketCounts) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Agregar otro producto'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickFromCatalog,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Usar uno que ya creé'),
            ),
          ),
        ],
      ],
    );
  }

  void _addProduct() {
    setState(() {
      _products.add(
        _ProductDraft.from(
          EventProduct(
            id: newProductId(),
            name: '',
            unit: ProductUnit.unit,
            priceOnVariant: false,
            price: 0,
            profit: 0,
            ticketCount: 0,
            variants: const [],
          ),
        ),
      );
    });
  }

  Future<void> _pickFromCatalog() async {
    if (widget.catalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Todavía no hay productos guardados. Se guardan al crear un evento.',
          ),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<EventProduct>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Productos que ya creaste',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final product in widget.catalog)
                ListTile(
                  title: Text(product.name),
                  subtitle: Text(product.priceSummary),
                  onTap: () => Navigator.pop(sheetContext, product),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      final copy = picked.cloneForNewEvent();
      if (_products.length == 1 && _products.first.name.text.trim().isEmpty) {
        _products.first.dispose();
        _products
          ..clear()
          ..add(_ProductDraft.from(copy));
      } else {
        _products.add(_ProductDraft.from(copy));
      }
    });
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.draft,
    required this.enabled,
    required this.lockTicketCounts,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _ProductDraft draft;
  final bool enabled;
  final bool lockTicketCounts;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: draft.name,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Producto *',
              hintText: 'Ej.: Pastelitos',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductUnit>(
            key: ValueKey('${draft.id}-${draft.unit.name}'),
            initialValue: draft.unit,
            decoration: const InputDecoration(labelText: 'Se vende por'),
            items: [
              for (final unit in ProductUnit.values)
                DropdownMenuItem(value: unit, child: Text(unit.label)),
            ],
            onChanged: enabled
                ? (unit) {
                    if (unit == null) return;
                    draft.unit = unit;
                    onChanged();
                  }
                : null,
          ),
          if (!draft.priceOnVariant) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.price,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio *'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: draft.profit,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ganancia'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ],
          if (draft.variants.isEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: draft.ticketCount,
              enabled: enabled && !lockTicketCounts,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de tickets *',
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
          if (draft.variants.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Opciones (sabores, tipos)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < draft.variants.length; i++)
              _VariantFields(
                draft: draft.variants[i],
                priced: draft.priceOnVariant,
                enabled: enabled,
                lockQuantity: lockTicketCounts,
                onChanged: onChanged,
                onRemove: enabled && !lockTicketCounts
                    ? () {
                        final variant = draft.variants.removeAt(i);
                        if (draft.variants.isEmpty) {
                          draft.priceOnVariant = false;
                        }
                        onChanged();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          variant.dispose();
                        });
                      }
                    : null,
              ),
          ],
          if (draft.variants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Total: ${draft.variantTotal} tickets',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (draft.variants.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.priceOnVariant,
              onChanged: enabled
                  ? (checked) {
                      draft.priceOnVariant = checked == true;
                      if (draft.priceOnVariant) {
                        for (final variant in draft.variants) {
                          if (variant.price.text.trim().isEmpty) {
                            variant.price.text = draft.price.text;
                          }
                          if (variant.profit.text.trim().isEmpty) {
                            variant.profit.text = draft.profit.text;
                          }
                        }
                      } else if (draft.variants.isNotEmpty) {
                        draft.price.text = draft.variants.first.price.text;
                        draft.profit.text = draft.variants.first.profit.text;
                      }
                      onChanged();
                    }
                  : null,
              title: const Text('Cada opción tiene su precio'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          if (enabled && !lockTicketCounts)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    draft.variants.add(
                      _VariantDraft(
                        id: newVariantId(),
                        name: '',
                        price: draft.price.text,
                        profit: draft.profit.text,
                        quota: draft.variants.isEmpty
                            ? draft.ticketCount.text
                            : '',
                      ),
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    draft.variants.isEmpty ? 'Tiene opciones' : 'Agregar opción',
                  ),
                ),
                if (canRemove)
                  TextButton(
                    onPressed: onRemove,
                    child: const Text('Quitar producto'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VariantFields extends StatelessWidget {
  const _VariantFields({
    required this.draft,
    required this.priced,
    required this.enabled,
    required this.lockQuantity,
    required this.onChanged,
    required this.onRemove,
  });

  final _VariantDraft draft;
  final bool priced;
  final bool enabled;
  final bool lockQuantity;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.name,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Opción',
                    hintText: 'Ej.: Membrillo',
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  tooltip: 'Quitar opción',
                ),
            ],
          ),
          if (priced) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.price,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: draft.profit,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ganancia'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: draft.quota,
            enabled: enabled && !lockQuantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad *'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _ProductDraft {
  _ProductDraft({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceOnVariant,
    required this.price,
    required this.profit,
    required this.ticketCount,
    required this.variants,
    required this.lockedTicketCount,
  });

  final String id;
  final TextEditingController name;
  ProductUnit unit;
  bool priceOnVariant;
  final TextEditingController price;
  final TextEditingController profit;
  final TextEditingController ticketCount;
  final List<_VariantDraft> variants;
  final int lockedTicketCount;

  factory _ProductDraft.from(EventProduct product) {
    return _ProductDraft(
      id: product.id,
      name: TextEditingController(text: product.name),
      unit: product.unit,
      priceOnVariant: product.priceOnVariant,
      price: TextEditingController(text: _plain(product.price)),
      profit: TextEditingController(text: _plain(product.profit)),
      ticketCount: TextEditingController(
        text: product.ticketCount > 0 ? '${product.ticketCount}' : '',
      ),
      variants: [
        for (final variant in product.variants) _VariantDraft.from(variant),
      ],
      lockedTicketCount: product.ticketCount,
    );
  }

  int get variantTotal {
    var total = 0;
    for (final variant in variants) {
      total += int.tryParse(variant.quota.text.trim()) ?? 0;
    }
    return total;
  }

  EventProduct toProduct() {
    final built = [for (final variant in variants) variant.toVariant()];
    final parsed = int.tryParse(ticketCount.text.trim());
    final variantSum = built.fold<int>(
      0,
      (sum, variant) => sum + variant.quota,
    );
    final count = built.isEmpty
        ? (parsed ?? lockedTicketCount)
        : (variantSum > 0 ? variantSum : lockedTicketCount);
    return EventProduct(
      id: id,
      name: name.text.trim(),
      unit: unit,
      priceOnVariant: priceOnVariant && variants.isNotEmpty,
      price: _money(price.text),
      profit: _money(profit.text) < 0 ? 0 : _money(profit.text),
      ticketCount: count,
      variants: built,
    );
  }

  void dispose() {
    name.dispose();
    price.dispose();
    profit.dispose();
    ticketCount.dispose();
    for (final variant in variants) {
      variant.dispose();
    }
  }
}

class _VariantDraft {
  _VariantDraft({
    required this.id,
    required String name,
    required String price,
    required String profit,
    required String quota,
  }) : name = TextEditingController(text: name),
       price = TextEditingController(text: price),
       profit = TextEditingController(text: profit),
       quota = TextEditingController(text: quota);

  final String id;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController profit;
  final TextEditingController quota;

  factory _VariantDraft.from(EventProductVariant variant) {
    return _VariantDraft(
      id: variant.id,
      name: variant.name,
      price: _plain(variant.price),
      profit: _plain(variant.profit),
      quota: variant.quota > 0 ? '${variant.quota}' : '',
    );
  }

  EventProductVariant toVariant() {
    return EventProductVariant(
      id: id,
      name: name.text.trim(),
      price: _money(price.text) < 0 ? 0 : _money(price.text),
      profit: _money(profit.text) < 0 ? 0 : _money(profit.text),
      quota: int.tryParse(quota.text.trim()) ?? 0,
    );
  }

  void dispose() {
    name.dispose();
    price.dispose();
    profit.dispose();
    quota.dispose();
  }
}

String _plain(double value) {
  if (value == 0) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

double _money(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return 0;
  return double.tryParse(text) ?? -1;
}
