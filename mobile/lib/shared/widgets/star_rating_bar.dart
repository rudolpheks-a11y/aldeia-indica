import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StarRatingBar extends StatelessWidget {
  final double rating;
  final int maxStars;
  final double size;

  const StarRatingBar({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = rating.toStringAsFixed(1).replaceAll('.', ',');
    return Semantics(
      label: 'Avaliação: $formatted de $maxStars estrelas',
      // As estrelas individuais são redundantes para o leitor de tela —
      // o label acima já carrega o valor completo.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxStars, (i) {
          final filled = i < rating.floor();
          final half = !filled && i < rating;
          return Icon(
            filled
                ? Icons.star
                : half
                    ? Icons.star_half
                    : Icons.star_border,
            color: AppColors.starColor,
            size: size,
          );
        }),
      ),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const InteractiveStarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  // Piso de 48px por estrela (WCAG 2.5.8 / Material): o ícone pode ser menor,
  // mas a área de toque não — o público inclui faixa etária alta.
  static const double _minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final target = widget.size < _minTarget ? _minTarget : widget.size;
    return Semantics(
      slider: true,
      label: 'Nota',
      value: '${widget.value} de 5',
      increasedValue: widget.value < 5 ? '${widget.value + 1} de 5' : null,
      decreasedValue: widget.value > 1 ? '${widget.value - 1} de 5' : null,
      onIncrease:
          widget.value < 5 ? () => widget.onChanged(widget.value + 1) : null,
      onDecrease:
          widget.value > 1 ? () => widget.onChanged(widget.value - 1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(i + 1),
            child: SizedBox(
              width: target,
              height: target,
              child: Center(
                child: Icon(
                  i < widget.value ? Icons.star : Icons.star_border,
                  color: AppColors.starColor,
                  size: widget.size,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
