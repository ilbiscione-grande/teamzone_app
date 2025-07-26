// lib/ui/pages/tools/widgets/bottom_player_list.dart

import 'package:flutter/material.dart';
import '../models.dart';

/// Visar två staplade lag: blått och rött.
/// Längst till höger visas en vertikal lista med "items" (ex bollar).
/// Dragga spelare till vardera DragTarget för att ta bort dem från planen.
/// Dragga item för att lägga ut dem på planen.
class BottomPlayerList extends StatelessWidget {
  final List<Player> available;
  final Widget Function(Player) playerBuilder;
  final void Function(Color teamColor, Offset globalTap) onOpenOverlay;
  final ValueChanged<Player> onPlayerCancelled;

  // -------- NYA PARAMETRAR FÖR ITEMS --------
  final List<Item> items;
  final Widget Function(Item) itemBuilder;
  final ValueChanged<Item>?
  onItemCancelled; // om du vill kunna dra tillbaka items
  // ------------------------------------------

  const BottomPlayerList({
    Key? key,
    required this.available,
    required this.playerBuilder,
    required this.onOpenOverlay,
    required this.onPlayerCancelled,
    required this.items,
    required this.itemBuilder,
    this.onItemCancelled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blues = available.where((p) => p.teamColor == Colors.blue).toList();
    final reds = available.where((p) => p.teamColor == Colors.red).toList();

    return Container(
      height: 90,
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Expanded(child: _teamColumn(blues, Colors.blue)),
          Expanded(child: SizedBox(width: 60, child: _itemsColumn())),
          Expanded(child: _teamColumn(reds, Colors.red)),
        ],
      ),
    );
  }

  Widget _teamColumn(List<Player> players, Color teamColor) {
    players.sort((a, b) => b.number.compareTo(a.number));
    return DragTarget<Player>(
      onWillAccept: (p) => p?.teamColor == teamColor,
      onAccept: onPlayerCancelled,
      builder: (ctx, cand, rej) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onOpenOverlay(teamColor, d.globalPosition),
          child: Stack(
            alignment: Alignment.center,
            children:
                players.map((p) {
                  return Draggable<Player>(
                    data: p,
                    feedback: playerBuilder(p),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: playerBuilder(p),
                    ),
                    child: playerBuilder(p),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _itemsColumn() {
    return DragTarget<Item>(
      onWillAccept: (it) => true,
      onAccept: onItemCancelled,
      builder: (ctx, cand, rej) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children:
              items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Draggable<Item>(
                    data: it,
                    feedback: itemBuilder(it),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: itemBuilder(it),
                    ),
                    child: itemBuilder(it),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}

/// Exempel‐klass för ett "item" — kan vara vad som helst
class Item {
  final String id;
  final Widget icon;
  Item({required this.id, required this.icon});
}
