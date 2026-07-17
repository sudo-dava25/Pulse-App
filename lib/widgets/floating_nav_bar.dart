import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}

/// Nav bar mengambang di tengah-bawah layar, gaya pill blur ala iOS.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 34, offset: const Offset(0, 14)),
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) _buildItem(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final selected = index == selectedIndex;
    final item = items[index];
    return GestureDetector(
      onTap: () => onSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.blue.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 18, color: selected ? Colors.white : AppColors.muted),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
