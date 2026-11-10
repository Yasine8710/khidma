import 'package:flutter/material.dart';

/// Text with its own reading direction (e.g. an LTR phone number or a
/// language's autonym) that still aligns to the *screen's* start edge.
/// Without this, forcing LTR on a value inside an RTL screen would also
/// flip its alignment.
class AlignedText extends StatelessWidget {
  const AlignedText(this.data, {super.key, this.textDirection, this.style});

  final String data;
  final TextDirection? textDirection;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final screenRtl = Directionality.of(context) == TextDirection.rtl;
    return Text(
      data,
      style: style,
      textDirection: textDirection,
      textAlign: screenRtl ? TextAlign.right : TextAlign.left,
    );
  }
}
