/// Günün hangi bölümünde olduğumuz: sabah 06-11, öğle 11-17, akşam 17-06 (öneri zamanlaması için).
enum SahneBolumu {
  sabah,
  ogle,
  aksam;

  static SahneBolumu simdi([DateTime? an]) {
    final s = (an ?? DateTime.now()).hour;
    if (s >= 6 && s < 11) return sabah;
    if (s >= 11 && s < 17) return ogle;
    return aksam;
  }
}
