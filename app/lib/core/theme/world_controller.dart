import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';

/// Which section of the app the person is in: the local trades (yellow) or the
/// digital services (green). Changing it recolours the whole app; the shell
/// plays a colour flood from [WorldState.origin] (where the switch was
/// tapped, in global coordinates).
class WorldState {
  const WorldState(this.world, {this.origin, this.tick = 0});

  final AppWorld world;
  final Offset? origin;

  /// Increases on every change so listeners can tell a repeat from a rebuild.
  final int tick;
}

final worldProvider = NotifierProvider<WorldController, WorldState>(
  WorldController.new,
);

class WorldController extends Notifier<WorldState> {
  @override
  WorldState build() => const WorldState(AppWorld.trades);

  void switchTo(AppWorld world, {Offset? origin}) {
    if (state.world == world) return;
    state = WorldState(world, origin: origin, tick: state.tick + 1);
  }
}
