import 'package:flutter/material.dart';

/// Verfügbare Stiftfarben für Annotationen
class AnnotationColors {
  static const Color red = Color(0xFFE53935);
  static const Color darkGreen = Color(0xFF43A047);
  static const Color lightGreen = Color(0xFF8BC34A);
  static const Color orange = Color(0xFFFFA000);
  static const Color yellow = Color(0xFFFFEB3B);
  static const Color darkBlue = Color(0xFF1E88E5);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color black = Color(0xFF424242);
  
  static const List<Color> allColors = [
    red,
    darkGreen,
    lightGreen,
    orange,
    yellow,
    darkBlue,
    lightBlue,
    black,
  ];
}

/// Toolbar für Annotationen im Edit-Mode
class AnnotationToolbar extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback? onUndo;
  final bool canUndo;
  final double strokeWidth;
  final ValueChanged<double> onStrokeWidthChanged;
  final double opacity;
  final ValueChanged<double> onOpacityChanged;
  final bool isEraserMode;
  final ValueChanged<bool> onEraserModeChanged;

  const AnnotationToolbar({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    required this.onCancel,
    required this.onConfirm,
    this.onUndo,
    this.canUndo = false,
    this.strokeWidth = 3.0,
    required this.onStrokeWidthChanged,
    this.opacity = 1.0,
    required this.onOpacityChanged,
    this.isEraserMode = false,
    required this.onEraserModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF757575), // Grauer Hintergrund wie im Screenshot
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Erste Reihe: Buttons und Farben
            Row(
              children: [
                // Cancel Button
                _buildActionButton(
                  icon: Icons.close,
                  onPressed: onCancel,
                  tooltip: 'Abbrechen',
                ),
                const SizedBox(width: 8),
                // Undo Button
                _buildActionButton(
                  icon: Icons.undo,
                  onPressed: canUndo ? onUndo : null,
                  tooltip: 'Rückgängig',
                ),
                const SizedBox(width: 12),
                // Eraser Toggle Button (looks like color button but white with red X)
                _buildEraserButton(),
                const SizedBox(width: 16),
                // Color buttons (disabled in eraser mode)
                Expanded(
                  child: Opacity(
                    opacity: isEraserMode ? 0.4 : 1.0,
                    child: IgnorePointer(
                      ignoring: isEraserMode,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: AnnotationColors.allColors.map((color) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildColorButton(color),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Confirm Button
                _buildActionButton(
                  icon: Icons.check,
                  onPressed: onConfirm,
                  tooltip: 'Bestätigen',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Zweite Reihe: Sliders
            Row(
              children: [
                // Stroke Width Slider
                const Icon(Icons.line_weight, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: _sliderTheme(context),
                    child: Slider(
                      value: strokeWidth,
                      min: 1.0,
                      max: 20.0,
                      onChanged: onStrokeWidthChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${strokeWidth.round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                // Opacity Slider
                const Icon(Icons.opacity, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: _sliderTheme(context),
                    child: Slider(
                      value: opacity,
                      min: 0.1,
                      max: 1.0,
                      onChanged: onOpacityChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${(opacity * 100).round()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SliderThemeData _sliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: Colors.white,
      inactiveTrackColor: Colors.white38,
      thumbColor: Colors.white,
      overlayColor: Colors.white24,
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: onPressed != null ? Colors.white : Colors.white38,
        size: 28,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }

  Widget _buildEraserButton() {
    return GestureDetector(
      onTap: () => onEraserModeChanged(!isEraserMode),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEraserMode ? Colors.red : Colors.transparent,
            width: 3,
          ),
          boxShadow: isEraserMode
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Icons.close,
          color: Colors.red,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = selectedColor == color;
    
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
              boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _getContrastColor(color),
                size: 18,
              )
            : null,
      ),
    );
  }

  /// Bestimmt eine kontrastierende Farbe für den Checkmark
  Color _getContrastColor(Color color) {
    // Berechne Luminanz
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

/// Kompakte Toolbar für den Edit-Modus (nur im Edit-Mode sichtbar)
class AnnotationToolbarCompact extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final bool canUndo;

  const AnnotationToolbarCompact({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.onUndo,
    this.onClear,
    this.canUndo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Undo Button
          _buildIconButton(
            icon: Icons.undo,
            onPressed: canUndo ? onUndo : null,
            tooltip: 'Rückgängig',
          ),
          const SizedBox(width: 8),
          // Color buttons
          ...AnnotationColors.allColors.map((color) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildColorButton(color),
            );
          }),
          const SizedBox(width: 8),
          // Clear Button
          _buildIconButton(
            icon: Icons.delete_outline,
            onPressed: onClear,
            tooltip: 'Alle löschen',
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: onPressed != null ? Colors.white : Colors.white38,
        size: 20,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      padding: EdgeInsets.zero,
      splashRadius: 16,
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = selectedColor == color;
    
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
