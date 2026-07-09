/// Centralized elevation scale, aligned to Material 3's elevation levels
/// (0–5). Material 3 favors subtle elevation and tonal surfaces over heavy
/// drop shadows — these values intentionally stay conservative.
class AppElevation {
  const AppElevation._();

  /// Flat — e.g. app bar at rest, flat cards.
  static const double level0 = 0;

  /// Barely raised — e.g. resting cards, list tiles.
  static const double level1 = 1;

  /// Slightly raised — e.g. app bar when content scrolls under it.
  static const double level2 = 3;

  /// Noticeably raised — e.g. dialogs, menus.
  static const double level3 = 6;

  /// Prominent — e.g. floating action button.
  static const double level4 = 8;

  /// Highest — reserved for rare, top-most surfaces.
  static const double level5 = 12;
}
