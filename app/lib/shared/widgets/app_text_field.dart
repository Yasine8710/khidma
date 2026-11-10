import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';

/// Labelled text field. The visible label sits above the field; screen
/// readers get it as the field's name (the visible copy is hidden from them
/// to avoid reading it twice). The password toggle stays a separate button.
/// Use [textDirection] to force LTR for phone numbers and emails inside RTL
/// screens.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textDirection,
    this.autofillHints,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;

  /// Trailing widget (e.g. a clear button). Ignored for password fields.
  final Widget? suffix;

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
  void didUpdateWidget(AppTextField old) {
    super.didUpdateWidget(old);
    if (old.obscureText != widget.obscureText) _hidden = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: widget.label,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            obscureText: _hidden,
            // Passwords are never autocorrected or suggested, even while shown.
            autocorrect: !widget.obscureText,
            enableSuggestions: !widget.obscureText,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textDirection: widget.textDirection,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hint,
              // A forced-LTR field (phone, email) must not show its hint RTL.
              hintTextDirection: widget.textDirection,
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
                      onPressed: widget.enabled
                          ? () => setState(() => _hidden = !_hidden)
                          : null,
                    )
                  : widget.suffix,
            ),
          ),
        ),
      ],
    );
  }
}
