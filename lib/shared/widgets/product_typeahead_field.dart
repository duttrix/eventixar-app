import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Free-text “qué se vende” with catalog suggestions as references.
class ProductTypeaheadField extends StatefulWidget {
  const ProductTypeaheadField({
    super.key,
    required this.controller,
    required this.suggestions,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<ProductTypeaheadField> createState() => _ProductTypeaheadFieldState();
}

class _ProductTypeaheadFieldState extends State<ProductTypeaheadField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<String> _filtered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return widget.suggestions;
    return widget.suggestions.where((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => _filtered(value.text),
      onSelected: (selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.collapsed(
          offset: selection.length,
        );
        widget.onChanged?.call(selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Qué se vende',
            hintText: 'Escribí o elegí una sugerencia',
            suffixIcon: Icon(Icons.search, size: 20),
          ),
          onChanged: widget.onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList(growable: false);
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        final maxWidth = MediaQuery.sizeOf(context).width - 48;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            color: AppColors.card,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200,
                maxWidth: maxWidth.clamp(220, 480),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: AppColors.border,
                ),
                itemBuilder: (context, index) {
                  final option = list[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
