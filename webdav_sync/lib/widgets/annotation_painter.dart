import 'package:flutter/material.dart';
import '../models/pdf_annotation.dart';

/// CustomPainter der die Annotationen zeichnet
class AnnotationPainter extends CustomPainter {
  final List<AnnotationStroke> strokes;
  final AnnotationStroke? currentStroke;

  AnnotationPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Zeichne alle gespeicherten Strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Zeichne den aktuellen Stroke (während des Zeichnens)
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, AnnotationStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      // Einzelner Punkt: zeichne einen Kreis
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      // Mehrere Punkte: zeichne einen Pfad
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        // Verwende quadratische Bezier-Kurven für glattere Linien
        if (i < stroke.points.length - 1) {
          final midPoint = Offset(
            (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
            (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(
            stroke.points[i].dx,
            stroke.points[i].dy,
            midPoint.dx,
            midPoint.dy,
          );
        } else {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}

/// Widget das Annotationen über einem PDF-Viewer anzeigt
class AnnotationOverlay extends StatefulWidget {
  final PageAnnotation pageAnnotation;
  final bool isEditMode;
  final bool isEraserMode;
  final Color selectedColor;
  final double strokeWidth;
  final double opacity;
  final Function(AnnotationStroke)? onStrokeAdded;
  final Function(int)? onStrokeDeleted;

  const AnnotationOverlay({
    super.key,
    required this.pageAnnotation,
    this.isEditMode = false,
    this.isEraserMode = false,
    this.selectedColor = Colors.red,
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.onStrokeAdded,
    this.onStrokeDeleted,
  });

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  List<Offset> _currentPoints = [];

  void _onPanStart(DragStartDetails details) {
    if (!widget.isEditMode) return;
    
    if (widget.isEraserMode) {
      // In Eraser mode: check if we hit a stroke
      _tryDeleteStrokeAt(details.localPosition);
    } else {
      // In draw mode: start drawing
      setState(() {
        _currentPoints = [details.localPosition];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isEditMode) return;
    
    if (widget.isEraserMode) {
      // In Eraser mode: check for strokes along the path
      _tryDeleteStrokeAt(details.localPosition);
    } else {
      // In draw mode: continue drawing
      setState(() {
        _currentPoints = [..._currentPoints, details.localPosition];
      });
    }
  }

  /// Tries to delete a stroke at the given position
  void _tryDeleteStrokeAt(Offset position) {
    final strokes = widget.pageAnnotation.strokes;
    
    // Check strokes in reverse order (newer strokes on top)
    for (int i = strokes.length - 1; i >= 0; i--) {
      if (_isPointNearStroke(position, strokes[i])) {
        widget.onStrokeDeleted?.call(i);
        return; // Only delete one stroke per hit
      }
    }
  }

  /// Checks if a point is near a stroke (within hit distance)
  bool _isPointNearStroke(Offset point, AnnotationStroke stroke) {
    const hitDistance = 15.0; // Tolerance in pixels
    
    for (final strokePoint in stroke.points) {
      final distance = (point - strokePoint).distance;
      if (distance <= hitDistance + stroke.strokeWidth / 2) {
        return true;
      }
    }
    return false;
  }

  /// Applies opacity to a color
  Color _applyOpacity(Color color) {
    return color.withValues(alpha: widget.opacity);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isEditMode) return;
    if (_currentPoints.isEmpty) return;

    final stroke = AnnotationStroke(
      points: List.from(_currentPoints),
      color: _applyOpacity(widget.selectedColor),
      strokeWidth: widget.strokeWidth,
    );

    widget.onStrokeAdded?.call(stroke);

    setState(() {
      _currentPoints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStroke = _currentPoints.isNotEmpty
        ? AnnotationStroke(
            points: _currentPoints,
            color: _applyOpacity(widget.selectedColor),
            strokeWidth: widget.strokeWidth,
          )
        : null;

    return GestureDetector(
      onPanStart: widget.isEditMode ? _onPanStart : null,
      onPanUpdate: widget.isEditMode ? _onPanUpdate : null,
      onPanEnd: widget.isEditMode ? _onPanEnd : null,
      behavior: widget.isEditMode
          ? HitTestBehavior.opaque
          : HitTestBehavior.translucent,
      child: CustomPaint(
        painter: AnnotationPainter(
          strokes: widget.pageAnnotation.strokes,
          currentStroke: currentStroke,
        ),
        child: Container(),
      ),
    );
  }
}
