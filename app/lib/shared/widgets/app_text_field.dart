import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Labelled text field. The label sits above the field and is merged into
/// the field's accessibility node. Use [textDirection] to force LTR for
/// phone numbers and emails inside RTL screens.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.textDirection,
    this.autofillHints,
    this.inputFormatters,
    this.prefixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;

  /// Password field. Adds a show/hide toggle.
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: _hidden,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textDirection: widget.textDirection,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              helperMaxLines: 2,
              errorText: widget.errorText,
              errorMaxLines: 3,
              counterText: '',
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, color: scheme.onSurfaceVariant),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      tooltip: _hidden ? l10n.showPassword : l10n.hidePassword,
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
