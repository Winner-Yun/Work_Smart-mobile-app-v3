/// Shared timing constants for loading/transition UX.
class AppDurations {
  AppDurations._();

  /// Minimum time the skeleton loader stays visible, so instant cache reads
  /// don't pop straight to content with no perceptible loading state.
  static const Duration minSkeletonDisplay = Duration(milliseconds: 400);
}
