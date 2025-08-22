// game_logic.dart
import 'dart:ui';

class GameLogic {
  int hitCount = 0;
  Offset? lastLaserPosition;

  void updateLaser(Offset? position, bool isBlocked) {
    if (position != null && !isBlocked) {
      // Register a hit if laser is visible
      hitCount++;
      lastLaserPosition = position;
    }
  }
}
