import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Barra de rolagem lateral persistente — trilho + alça arrastável + setas
/// nas pontas, ao contrário da rolagem transitória padrão do iOS/Flutter
/// (que só aparece durante o gesto e some sozinha).
///
/// `controller` precisa ser o mesmo ScrollController usado pelo
/// ListView/SingleChildScrollView passado como [child].
class AppScrollbar extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  final double width;
  final double step;

  /// Deve bater com o `reverse` do ListView/scrollable envolvido — inverte a
  /// posição da alça e o sentido das setas/arrasto (offset 0 fica embaixo,
  /// não em cima, como no ListView de chat).
  final bool reverse;

  const AppScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.width = 22,
    this.step = 80,
    this.reverse = false,
  });

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // Na primeira montagem, o trilho é medido antes do scrollable irmão
    // terminar seu próprio layout (Row mede filhos não-flexíveis primeiro),
    // então `hasContentDimensions` ainda é falso e o trilho fica em branco.
    // O controller só notifica listeners quando o offset muda, não quando as
    // dimensões passam a existir — então sem isto o trilho ficaria vazio até
    // o usuário arrastar a lista manualmente pela primeira vez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() => setState(() {});

  void _step(double delta) {
    if (!widget.controller.hasClients ||
        !widget.controller.position.hasContentDimensions) {
      return;
    }
    final max = widget.controller.position.maxScrollExtent;
    final signedDelta = widget.reverse ? -delta : delta;
    final target = (widget.controller.offset + signedDelta).clamp(0.0, max);
    widget.controller.animateTo(target,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: widget.child),
        SizedBox(
          width: widget.width,
          child: _Track(
              controller: widget.controller,
              step: _step,
              reverse: widget.reverse),
        ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  final ScrollController controller;
  final void Function(double delta) step;
  final bool reverse;
  const _Track(
      {required this.controller, required this.step, required this.reverse});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StepButton(icon: Icons.keyboard_arrow_up, onTap: () => step(-80)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!controller.hasClients ||
                  !controller.position.hasContentDimensions ||
                  controller.position.maxScrollExtent <= 0) {
                return Container(color: AppColors.neutral100);
              }
              final trackHeight = constraints.maxHeight;
              final viewport = controller.position.viewportDimension;
              final maxScroll = controller.position.maxScrollExtent;
              final contentHeight = viewport + maxScroll;
              final thumbHeight =
                  (trackHeight * viewport / contentHeight).clamp(24.0, trackHeight);
              final maxThumbTravel = trackHeight - thumbHeight;
              final scrollFraction = maxScroll <= 0 ? 0.0 : controller.offset / maxScroll;
              final effectiveFraction = reverse ? 1 - scrollFraction : scrollFraction;
              final thumbTop = maxThumbTravel * effectiveFraction;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (maxThumbTravel <= 0) return;
                  final rawDelta =
                      (details.delta.dy / maxThumbTravel) * maxScroll;
                  final deltaScroll = reverse ? -rawDelta : rawDelta;
                  final target =
                      (controller.offset + deltaScroll).clamp(0.0, maxScroll);
                  controller.jumpTo(target);
                },
                child: Container(
                  color: AppColors.neutral100,
                  child: Stack(
                    children: [
                      Positioned(
                        top: thumbTop,
                        left: 4,
                        right: 4,
                        height: thumbHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _StepButton(icon: Icons.keyboard_arrow_down, onTap: () => step(80)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 22,
        color: AppColors.neutral200,
        child: Icon(icon, size: 16, color: AppColors.neutral600),
      ),
    );
  }
}
