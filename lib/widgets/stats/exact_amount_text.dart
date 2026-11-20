import "package:decimal/decimal.dart";
import "package:flow/data/money.dart";
import "package:flow/prefs/transitive.dart";
import "package:flow/widgets/general/money_text_raw.dart";
import "package:flutter/material.dart";

/// Two-decimal money text that follows the session privacy setting.
class ExactAmountText extends StatefulWidget {
  final Decimal amount;
  final String currency;
  final TextStyle? style;
  final bool selectable;

  const ExactAmountText({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.selectable = true,
  });

  @override
  State<ExactAmountText> createState() => _ExactAmountTextState();
}

class _ExactAmountTextState extends State<ExactAmountText> {
  @override
  void initState() {
    super.initState();
    TransitiveLocalPreferences().sessionPrivacyMode.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TransitiveLocalPreferences().sessionPrivacyMode.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String value = TransitiveLocalPreferences().sessionPrivacyMode.get()
        ? "••••"
        : Money(widget.amount.toDouble(), widget.currency).formattedExact;
    final Widget text = MoneyTextRaw(
      text: value,
      style: widget.style,
      autoSize: true,
      maxLines: 1,
    );
    return widget.selectable ? SelectionArea(child: text) : text;
  }
}
