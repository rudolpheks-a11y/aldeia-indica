import 'package:flutter/material.dart';

/// Design tokens v1.1 — ver brand/DESIGN_1.md (fonte da verdade da paleta).
/// Verde foi removido do sistema por completo: azul é o hue mais seguro
/// entre todos os tipos de daltonismo (base dos padrões Okabe-Ito/Wong).
class AppColors {
  // Primary — Azul Sereno
  static const Color primary50 = Color(0xFFEAF2F5);
  static const Color primary100 = Color(0xFFCBE0E8);
  static const Color primary200 = Color(0xFFA2C8D4);
  static const Color primary300 = Color(0xFF78AFC0);
  static const Color primary400 = Color(0xFF5695AC);
  static const Color primary500 = Color(0xFF457D94);
  static const Color primary600 = Color(0xFF386B80);
  static const Color primary700 = Color(0xFF2E5C74); // âncora de marca
  static const Color primary800 = Color(0xFF244A5D); // pressed
  static const Color primary900 = Color(0xFF17242E);

  // Secondary — Terracota
  static const Color secondary50 = Color(0xFFFBEEE6);
  static const Color secondary100 = Color(0xFFF5D7C3);
  static const Color secondary200 = Color(0xFFEDBB99);
  static const Color secondary300 = Color(0xFFE39E6E);
  static const Color secondary400 = Color(0xFFD68C58);
  static const Color secondary500 = Color(0xFFC97B4A); // âncora de marca
  static const Color secondary600 = Color(0xFFB1663A);
  static const Color secondary700 = Color(0xFF94532E);
  static const Color secondary800 = Color(0xFF784224);
  static const Color secondary900 = Color(0xFF5C331B);

  // Apoio
  // Dourado — estrelas e superfícies de destaque. NUNCA com conteúdo branco:
  // branco sobre accent500 mede 2.11:1 (falha AA); usar neutral900 (8.24:1).
  static const Color accent500 = Color(0xFFE3A83F);
  static const Color error900 = Color(0xFFB0223C); // Carmim
  static const Color informational700 = Color(0xFF5B4B8A); // selo "Completo"
  static const Color informational900 = Color(0xFF3E3564); // ScoreBadge "Novo"
  static const Color veteran900 = Color(0xFF4A4038); // selo "Veterano"

  // Neutros
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9FAFA);
  static const Color neutral100 = Color(0xFFF1F2F1);
  static const Color neutral200 = Color(0xFFE0E1E0);
  static const Color neutral300 = Color(0xFFBDBEBD);
  static const Color neutral500 = Color(0xFF757675);
  static const Color neutral600 = Color(0xFF616261); // texto secundário e hint
  static const Color neutral700 = Color(0xFF424342);
  static const Color neutral900 = Color(0xFF1A1A1A); // texto primário

  // Aliases semânticos — usados em telas e no ThemeData
  static const Color primary = primary700;
  static const Color secondary = secondary500;
  static const Color accent = accent500;

  static const Color surface = neutral50;
  static const Color background = neutral0;
  static const Color error = error900;
  static const Color success = primary700; // nunca verde — ver DESIGN_1.md

  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textHint = neutral600; // corrigido: 9E9E9E media 2.68:1 (falha AA)

  static const Color starColor = accent500;

  // Selos (bem_avaliado, muito_indicado, veterano, completo)
  static const Color sealBemAvaliado = primary700;
  static const Color sealMuitoIndicado = secondary500;
  static const Color sealVeterano = veteran900;
  static const Color sealCompleto = informational700;

  // ScoreBadge — 4 faixas
  static const Color scoreExcelente = primary700;
  static const Color scoreBom = secondary500;
  static const Color scorePrecisaMelhorar = error900;
  static const Color scoreNovo = informational900;
}
