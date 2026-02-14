import 'dart:convert';
import 'dart:ui';

/// Ein einzelner Strich/Stroke einer Annotation
class AnnotationStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  AnnotationStroke({
    required this.points,
    required this.color,
    this.strokeWidth = 3.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      // Store color components separately for cross-version compatibility
      'colorA': color.a,
      'colorR': color.r,
      'colorG': color.g,
      'colorB': color.b,
      'strokeWidth': strokeWidth,
    };
  }

  factory AnnotationStroke.fromJson(Map<String, dynamic> json) {
    // Support both old format (color as int) and new format (ARGB components)
    Color color;
    if (json.containsKey('colorA')) {
      color = Color.from(
        alpha: (json['colorA'] as num).toDouble(),
        red: (json['colorR'] as num).toDouble(),
        green: (json['colorG'] as num).toDouble(),
        blue: (json['colorB'] as num).toDouble(),
      );
    } else {
      // Legacy format: color as int
      final colorValue = json['color'] as int;
      color = Color.from(
        alpha: ((colorValue >> 24) & 0xFF) / 255.0,
        red: ((colorValue >> 16) & 0xFF) / 255.0,
        green: ((colorValue >> 8) & 0xFF) / 255.0,
        blue: (colorValue & 0xFF) / 255.0,
      );
    }
    
    return AnnotationStroke(
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      color: color,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
    );
  }

  AnnotationStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
  }) {
    return AnnotationStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}

/// Annotationen für eine einzelne Seite
class PageAnnotation {
  final int pageNumber;
  final List<AnnotationStroke> strokes;

  PageAnnotation({
    required this.pageNumber,
    List<AnnotationStroke>? strokes,
  }) : strokes = strokes ?? [];

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  factory PageAnnotation.fromJson(Map<String, dynamic> json) {
    return PageAnnotation(
      pageNumber: json['pageNumber'] as int,
      strokes: (json['strokes'] as List?)
              ?.map((s) => AnnotationStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  PageAnnotation copyWith({
    int? pageNumber,
    List<AnnotationStroke>? strokes,
  }) {
    return PageAnnotation(
      pageNumber: pageNumber ?? this.pageNumber,
      strokes: strokes ?? List.from(this.strokes),
    );
  }

  /// Fügt einen neuen Stroke hinzu
  PageAnnotation addStroke(AnnotationStroke stroke) {
    return copyWith(strokes: [...strokes, stroke]);
  }

  /// Entfernt den letzten Stroke (Undo)
  PageAnnotation removeLastStroke() {
    if (strokes.isEmpty) return this;
    return copyWith(strokes: strokes.sublist(0, strokes.length - 1));
  }

  /// Löscht alle Strokes
  PageAnnotation clearStrokes() {
    return copyWith(strokes: []);
  }
}

/// Alle Annotationen für ein PDF-Dokument
class PdfAnnotation {
  /// Dateiname des PDFs (ohne Pfad) - bleibt gleich auch wenn PDF sich ändert
  final String pdfFileName;
  
  /// Annotationen pro Seite (Key = Seitennummer)
  final Map<int, PageAnnotation> pageAnnotations;
  
  /// Zeitstempel der letzten Änderung
  final DateTime lastModified;

  PdfAnnotation({
    required this.pdfFileName,
    Map<int, PageAnnotation>? pageAnnotations,
    DateTime? lastModified,
  })  : pageAnnotations = pageAnnotations ?? {},
        lastModified = lastModified ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'pdfFileName': pdfFileName,
      'pageAnnotations': pageAnnotations.map(
        (key, value) => MapEntry(key.toString(), value.toJson()),
      ),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) {
    final pageAnnotationsJson = json['pageAnnotations'] as Map<String, dynamic>?;
    final pageAnnotations = <int, PageAnnotation>{};
    
    if (pageAnnotationsJson != null) {
      for (final entry in pageAnnotationsJson.entries) {
        final pageNumber = int.parse(entry.key);
        pageAnnotations[pageNumber] = PageAnnotation.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return PdfAnnotation(
      pdfFileName: json['pdfFileName'] as String,
      pageAnnotations: pageAnnotations,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
    );
  }

  /// Serialisiert zu JSON-String
  String toJsonString() => jsonEncode(toJson());

  /// Deserialisiert von JSON-String
  factory PdfAnnotation.fromJsonString(String jsonString) {
    return PdfAnnotation.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  PdfAnnotation copyWith({
    String? pdfFileName,
    Map<int, PageAnnotation>? pageAnnotations,
    DateTime? lastModified,
  }) {
    return PdfAnnotation(
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pageAnnotations: pageAnnotations ?? Map.from(this.pageAnnotations),
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  /// Holt die Annotationen für eine bestimmte Seite
  PageAnnotation getPageAnnotation(int pageNumber) {
    return pageAnnotations[pageNumber] ?? PageAnnotation(pageNumber: pageNumber);
  }

  /// Setzt die Annotationen für eine bestimmte Seite
  PdfAnnotation setPageAnnotation(int pageNumber, PageAnnotation annotation) {
    final newAnnotations = Map<int, PageAnnotation>.from(pageAnnotations);
    newAnnotations[pageNumber] = annotation;
    return copyWith(pageAnnotations: newAnnotations);
  }

  /// Fügt einen Stroke zu einer Seite hinzu
  PdfAnnotation addStrokeToPage(int pageNumber, AnnotationStroke stroke) {
    final pageAnnotation = getPageAnnotation(pageNumber);
    final updatedPage = pageAnnotation.addStroke(stroke);
    return setPageAnnotation(pageNumber, updatedPage);
  }

  /// Entfernt den letzten Stroke einer Seite (Undo)
  PdfAnnotation undoStrokeOnPage(int pageNumber) {
    final pageAnnotation = getPageAnnotation(pageNumber);
    final updatedPage = pageAnnotation.removeLastStroke();
    return setPageAnnotation(pageNumber, updatedPage);
  }

  /// Löscht alle Strokes einer Seite
  PdfAnnotation clearPage(int pageNumber) {
    final pageAnnotation = getPageAnnotation(pageNumber);
    final updatedPage = pageAnnotation.clearStrokes();
    return setPageAnnotation(pageNumber, updatedPage);
  }

  /// Prüft ob Annotationen auf einer Seite existieren
  bool hasAnnotationsOnPage(int pageNumber) {
    final page = pageAnnotations[pageNumber];
    return page != null && page.strokes.isNotEmpty;
  }

  /// Prüft ob überhaupt Annotationen existieren
  bool get hasAnyAnnotations {
    return pageAnnotations.values.any((page) => page.strokes.isNotEmpty);
  }
}
