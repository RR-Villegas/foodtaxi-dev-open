import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HouseNumberInput extends StatelessWidget {
  final TextEditingController numberController;
  final TextEditingController suffixController;
  final InputDecoration numberDecoration;
  final InputDecoration suffixDecoration;

  const HouseNumberInput({
    super.key,
    required this.numberController,
    required this.suffixController,
    required this.numberDecoration,
    required this.suffixDecoration,
  });

  static ({String number, String suffix}) split(String? value) {
    final normalized = value?.trim() ?? '';
    final match = RegExp(r'^(\d+)-([A-Za-z0-9/-]+)$').firstMatch(normalized);
    if (match == null) return (number: normalized, suffix: '');
    return (number: match[1]!, suffix: match[2]!);
  }

  static String combine(String? number, String? suffix) {
    final base = number?.trim() ?? '';
    final extension = suffix?.trim() ?? '';
    if (base.isEmpty) return '';
    if (extension.isEmpty) return base;
    return '$base-$extension';
  }

  static bool hasSuffixWithoutNumber(String? number, String? suffix) {
    return (suffix?.trim().isNotEmpty ?? false) &&
        (number?.trim().isEmpty ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: numberController,
            decoration: numberDecoration,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: suffixController,
            decoration: suffixDecoration,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9/-]')),
            ],
          ),
        ),
      ],
    );
  }
}
