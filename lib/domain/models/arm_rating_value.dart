/// One rating to inject into an ARM shell (plot × column).
class ArmRatingValue {
  const ArmRatingValue({
    required this.plotNumber,
    required this.armColumnId,
    required this.value,
  });

  final int plotNumber;
  final String armColumnId;
  final String value;
}
