import 'package:flutter/material.dart';

const purple = Color(0xFF6246D8);
const dark = Color(0xFF171642);
const bg = Color(0xFFF8F7FF);
const green = Color(0xFF0F9D68);
const red = Color(0xFFE5484D);
const orange = Color(0xFFF59E0B);

String rupees(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();

  if (digits.length <= 3) {
    return '${negative ? '-' : ''}₹$digits';
  }

  final lastThree = digits.substring(digits.length - 3);
  var remaining = digits.substring(0, digits.length - 3);

  final groups = <String>[];

  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }

  if (remaining.isNotEmpty) {
    groups.insert(0, remaining);
  }

  return '${negative ? '-' : ''}₹${groups.join(',')},$lastThree';
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFEAE7F5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.action,
  });

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: dark,
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: purple,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    this.safe = true,
  });

  final String text;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final c = safe ? green : red;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}