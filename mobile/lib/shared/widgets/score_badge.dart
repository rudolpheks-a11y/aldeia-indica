import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 56});

  // Faixa "Bom" usa texto grafite, não branco: terracota satura demais para
  // passar 4.5:1 com branco (3.27:1) — ver DESIGN_1.md, "bug mais fácil de
  // reintroduzir por engano".
  Color get _bgColor {
    if (score >= 85) return AppColors.scoreExcelente;
    if (score >= 65) return AppColors.scoreBom;
    return AppColors.scorePrecisaMelhorar;
  }

  Color get _textColor => score >= 65 && score < 85
      ? AppColors.neutral900
      : AppColors.neutral0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Score Aldeia: ${score.round()} de 100',
      // "47" + "score" como textos soltos não dizem nada no leitor de tela;
      // o label acima substitui os dois.
      excludeSemantics: true,
      child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgColor,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.32,
            ),
          ),
          Text(
            'score',
            style: TextStyle(
              color: _textColor.withValues(alpha: 0.7),
              fontSize: size * 0.16,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
