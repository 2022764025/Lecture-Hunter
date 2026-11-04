import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// 과제헌터.html 의 SVG 아이콘에 대응하는 Material 아이콘
abstract final class AppIcons {
  static const logo = Icons.chat_outlined;
  static const send = Icons.send_outlined;
  static const check = Icons.check_circle_outline_rounded;
  static const image = Icons.add_photo_alternate_outlined;
  static const search = Icons.search_rounded;
  static const book = Icons.menu_book_outlined;
  static const pin = Icons.push_pin_outlined;
  static const clipboard = Icons.assignment_outlined;
  static const external = Icons.open_in_new_rounded;
  static const translate = Icons.translate_rounded;
  static const alert = Icons.error_outline_rounded;
  static const sparkle = Icons.auto_awesome_outlined;
  static const campaign = Icons.campaign_outlined;
}

/// 탭 · 하위 탭 · 언어 · 프리셋 버튼 (.tab / .subtab / .lang / .preset)
class ChoiceButton extends StatefulWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height = 38,
    this.fontEm = 0.9,
    this.color = AppColors.secondary,
    this.selectedWeight = FontWeight.w600,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;
  final double fontEm;
  final Color color;
  final FontWeight selectedWeight;
  final String? leading;

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: widget.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.sageSoft : AppColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected || _hover ? AppColors.sage : AppColors.border),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.leading == null ? widget.label : '${widget.leading} ${widget.label}',
                maxLines: 1,
                style: em(
                  widget.fontEm,
                  weight: selected ? widget.selectedWeight : FontWeight.w400,
                  color: selected ? AppColors.sageDark : widget.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 버튼 여러 개를 같은 너비로 나란히 놓는다 (CSS grid repeat(n, 1fr))
class EqualRow extends StatelessWidget {
  const EqualRow({super.key, required this.children, this.gap = 8});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

enum ActionStyle { soft, outline, primary }

/// .action / .outline-action / .summary-action
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.style = ActionStyle.soft,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final ActionStyle style;
  final bool loading;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;
    final (bg, fg, borderColor, weight, fontEm, radius) = switch (widget.style) {
      ActionStyle.soft => (AppColors.sageSoft, AppColors.sageDark, Colors.transparent, FontWeight.w600, 1.0, 10.0),
      ActionStyle.outline => (
          Colors.white,
          AppColors.sageDark,
          _hover && !disabled ? AppColors.sage : AppColors.border,
          FontWeight.w500,
          1.0,
          10.0
        ),
      ActionStyle.primary => (AppColors.sage, Colors.white, Colors.transparent, FontWeight.w800, 1.1, 13.0),
    };
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: Opacity(
          opacity: disabled && !widget.loading ? 0.7 : 1,
          child: Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.loading)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else if (widget.icon != null)
                  Icon(widget.icon, size: kBaseFontSize * fontEm * 1.15, color: fg),
                if (widget.loading || widget.icon != null) const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: em(fontEm, weight: weight, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 둥근 박스 (.caption-original, .glossary-result, .notice-box …)
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = AppColors.cream,
    this.border,
    this.radius = 15,
    this.padding = const EdgeInsets.fromLTRB(14, 17, 14, 17),
    this.minHeight = 0,
  });

  final Widget child;
  final Color color;
  final Color? border;
  final double radius;
  final EdgeInsets padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: child,
    );
  }
}

/// 디자인 입력창 공통 장식
InputDecoration fieldDecoration({
  required String hint,
  Color fill = Colors.white,
  double radius = 10,
  bool bordered = true,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
}) {
  final side = bordered ? const BorderSide(color: AppColors.border) : BorderSide.none;
  return InputDecoration(
    hintText: hint,
    hintStyle: em(0.97, color: AppColors.placeholder),
    filled: true,
    fillColor: fill,
    isDense: true,
    counterText: '',
    contentPadding: padding,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: side),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: side),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: AppColors.sage, width: bordered ? 1.4 : 1.2),
    ),
  );
}

/// 작은 상태 점 + 글자 (.caption-status)
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: em(0.79, color: color == AppColors.sageDark ? AppColors.sageDark : AppColors.secondary)),
      ],
    );
  }
}

/// 섹션 제목 (.notice-title 등): 아이콘 + 굵은 글자
class IconTitle extends StatelessWidget {
  const IconTitle({super.key, required this.icon, required this.title, this.color = AppColors.sageDark, this.fontEm = 1.05});
  final IconData icon;
  final String title;
  final Color color;
  final double fontEm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: kBaseFontSize * fontEm * 1.1, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(title, style: em(fontEm, weight: FontWeight.w800, color: color))),
      ],
    );
  }
}

/// 작은 키워드 칩
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: em(0.8, weight: FontWeight.w600, color: AppColors.sageDark)),
    );
    if (onTap == null) return chip;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: chip));
  }
}

/// 짧은 안내 문구 (빈 상태 / 오류)
class InlineNote extends StatelessWidget {
  const InlineNote(this.text, {super.key, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: em(0.8, color: error ? AppColors.error : AppColors.muted, height: 1.5),
    );
  }
}

String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${time.month}/${time.day}';
}
