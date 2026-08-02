/// Shared timing constants for loading/transition UX.
class AppDurations {
  AppDurations._();

  /// Minimum time the skeleton loader stays visible before cached data is
  /// revealed, even when the cache read resolves instantly — without this,
  /// a fast local read can flip straight to content with no perceptible
  /// loading state at all, which reads as a jarring pop-in rather than a
  /// smooth load.
  static const Duration minSkeletonDisplay = Duration(milliseconds: 400);
}
