// lib/ui/pages/tools/widgets/toolbar.dart

import 'package:flutter/material.dart';
import '../models.dart';

class TacticsToolbar extends StatelessWidget {
  final ShapeType? selectedShape;
  final LineType? selectedLine;
  final Color selectedColor;
  final double strokeWidth;
  final VoidCallback onReset, onUndo, onPickColor;
  final ValueChanged<ShapeType?> onShapeSelected;
  final ValueChanged<LineType?> onLineSelected;
  final ValueChanged<double> onStrokeSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onClearSelection;

  const TacticsToolbar({
    Key? key,
    required this.selectedShape,
    required this.selectedLine,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onReset,
    required this.onUndo,
    required this.onPickColor,
    required this.onShapeSelected,
    required this.onLineSelected,
    required this.onStrokeSelected,
    required this.onDeleteSelected,
    required this.onClearSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext cx) {
    return Container(
      height: 50,
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Rensa allt
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Rensa',
            onPressed: onReset,
          ),
          // Ångra
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Ångra',
            onPressed: onUndo,
          ),
          // Färgval
          GestureDetector(
            onTap: onPickColor,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(),
              ),
            ),
          ),
          // Tjocklek
          PopupMenuButton<double>(
            // istället för Icons.circle:
            icon: SizedBox(
              width: 24,
              height: 24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(width: 24, height: 1, color: Colors.black),
                  Container(width: 24, height: 2, color: Colors.black),
                  Container(width: 24, height: 4, color: Colors.black),

                  Container(width: 24, height: 6, color: Colors.black),
                ],
              ),
            ),
            tooltip: 'Linjetjocklek',
            onSelected: onStrokeSelected,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 2, child: Text('Tunn')),
                  PopupMenuItem(value: 4, child: Text('Normal')),
                  PopupMenuItem(value: 8, child: Text('Tjock')),
                  PopupMenuItem(value: 12, child: Text('Extra')),
                ],
          ),
          const Spacer(),

          /// ───────── TOOL INDICATOR + “X” ─────────
          // Vi slår ihop ikon, text och “clear”-knapp i en rad:
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Valt verktyg: '),
              if (selectedShape != null) ...[
                Icon(_iconForShape(selectedShape!), color: selectedColor),
                const SizedBox(width: 4),
                Text(_labelForShape(selectedShape!)),
              ] else if (selectedLine != null) ...[
                Icon(_iconForLine(selectedLine!), color: selectedColor),
                const SizedBox(width: 4),
                Text(_labelForLine(selectedLine!)),
              ] else
                const Text('Ingen verktyg'),
              const SizedBox(width: 4),
              // “X”-knappen som avmarkerar det valda verktyget
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Avmarkera verktyg',
                onPressed: () {
                  if (selectedShape != null) {
                    onShapeSelected(null);
                  } else if (selectedLine != null) {
                    onLineSelected(null);
                  }
                },
              ),
            ],
          ),

          const Spacer(),

          // Välj form
          PopupMenuButton<ShapeType>(
            icon: const Icon(Icons.add_box),
            tooltip: 'Form',
            onSelected: onShapeSelected,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: ShapeType.circle, child: Text('Cirkel')),
                  PopupMenuItem(
                    value: ShapeType.square,
                    child: Text('Kvadrat'),
                  ),
                  PopupMenuItem(
                    value: ShapeType.triangle,
                    child: Text('Triangel'),
                  ),
                ],
          ),

          // Välj linjetyp
          PopupMenuButton<LineType>(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Linjetyp',
            onSelected: onLineSelected,
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: LineType.solid,
                    child: Text('Heldragen'),
                  ),
                  PopupMenuItem(
                    value: LineType.solidArrow,
                    child: Text('Pil →'),
                  ),
                  PopupMenuItem(
                    value: LineType.dashed,
                    child: Text('Streckad'),
                  ),
                  PopupMenuItem(
                    value: LineType.dashedArrow,
                    child: Text('Streckad + pil'),
                  ),
                  PopupMenuItem(
                    value: LineType.freeSolid,
                    child: Text('Frihand'),
                  ),
                  PopupMenuItem(
                    value: LineType.freeSolidArrow,
                    child: Text('Frihand + pil'),
                  ),
                  PopupMenuItem(
                    value: LineType.freeDashed,
                    child: Text('Frihand streckad'),
                  ),
                  PopupMenuItem(
                    value: LineType.freeDashedArrow,
                    child: Text('Frihand streckad + pil'),
                  ),
                ],
          ),

          // Ta bort valt objekt
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Ta bort valt',
            onPressed: onDeleteSelected,
          ),
          // Rensa markering
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Rensa markering',
            onPressed: onClearSelection,
          ),
        ],
      ),
    );
  }

  IconData _iconForShape(ShapeType s) {
    switch (s) {
      case ShapeType.circle:
        return Icons.circle;
      case ShapeType.square:
        return Icons.crop_square;
      case ShapeType.triangle:
        return Icons.change_history;
      default:
        // täcker även ShapeType.line (aktiveras aldrig om du inte ger användaren den optionen)
        return Icons.help_outline;
    }
  }

  String _labelForShape(ShapeType s) {
    switch (s) {
      case ShapeType.circle:
        return 'Cirkel';
      case ShapeType.square:
        return 'Kvadrat';
      case ShapeType.triangle:
        return 'Triangel';
      default:
        return '';
    }
  }

  IconData _iconForLine(LineType l) {
    switch (l) {
      case LineType.solid:
        return Icons.show_chart;
      case LineType.solidArrow:
        return Icons.arrow_forward;
      case LineType.dashed:
        return Icons.linear_scale;
      case LineType.dashedArrow:
        return Icons.arrow_forward_ios;
      case LineType.freeSolid:
        return Icons.brush;
      case LineType.freeSolidArrow:
        return Icons.brush_outlined;
      case LineType.freeDashed:
        return Icons.format_color_reset;
      case LineType.freeDashedArrow:
        return Icons.format_color_reset_outlined;
    }
  }

  String _labelForLine(LineType l) {
    switch (l) {
      case LineType.solid:
        return 'Heldragen';
      case LineType.solidArrow:
        return 'Pil i slutet';
      case LineType.dashed:
        return 'Streckad';
      case LineType.dashedArrow:
        return 'Streckad + pil';
      case LineType.freeSolid:
        return 'Frihand';
      case LineType.freeSolidArrow:
        return 'Frihand + pil';
      case LineType.freeDashed:
        return 'Frihand streckad';
      case LineType.freeDashedArrow:
        return 'Frihand streckad + pil';
    }
  }
}
