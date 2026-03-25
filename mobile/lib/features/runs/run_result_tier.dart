/// Outcome label for a run based on [wins] and [perfect] (MVP rules).
enum RunResultTier {
  defeat,
  bronzeVictory,
  silverVictory,
  goldVictory,
  diamondVictory,
}

/// Maps to Firestore string values in `users/{uid}/runs/{runId}.resultTier`.
String runResultTierToFirestore(RunResultTier tier) {
  switch (tier) {
    case RunResultTier.defeat:
      return 'defeat';
    case RunResultTier.bronzeVictory:
      return 'bronzeVictory';
    case RunResultTier.silverVictory:
      return 'silverVictory';
    case RunResultTier.goldVictory:
      return 'goldVictory';
    case RunResultTier.diamondVictory:
      return 'diamondVictory';
  }
}

RunResultTier runResultTierFromFirestore(String? value) {
  switch (value) {
    case 'defeat':
      return RunResultTier.defeat;
    case 'bronzeVictory':
      return RunResultTier.bronzeVictory;
    case 'silverVictory':
      return RunResultTier.silverVictory;
    case 'goldVictory':
      return RunResultTier.goldVictory;
    case 'diamondVictory':
      return RunResultTier.diamondVictory;
    default:
      return RunResultTier.defeat;
  }
}

/// Classifies run result per [docs/DATA_MODEL.md].
RunResultTier classifyRunResult({required int wins, required bool perfect}) {
  if (wins == 10 && perfect) {
    return RunResultTier.diamondVictory;
  }
  if (wins == 10) {
    return RunResultTier.goldVictory;
  }
  if (wins >= 7 && wins <= 9) {
    return RunResultTier.silverVictory;
  }
  if (wins >= 4 && wins <= 6) {
    return RunResultTier.bronzeVictory;
  }
  return RunResultTier.defeat;
}

/// Total order for comparing best result across runs (defeat … diamond).
int runResultTierRank(RunResultTier tier) {
  switch (tier) {
    case RunResultTier.defeat:
      return 0;
    case RunResultTier.bronzeVictory:
      return 1;
    case RunResultTier.silverVictory:
      return 2;
    case RunResultTier.goldVictory:
      return 3;
    case RunResultTier.diamondVictory:
      return 4;
  }
}

RunResultTier maxRunResultTier(RunResultTier a, RunResultTier b) {
  return runResultTierRank(a) >= runResultTierRank(b) ? a : b;
}

/// Compact label for tight UI (e.g. catalog badges).
String runResultTierShortLabel(RunResultTier tier) {
  switch (tier) {
    case RunResultTier.defeat:
      return 'Defeat';
    case RunResultTier.bronzeVictory:
      return 'Bronze';
    case RunResultTier.silverVictory:
      return 'Silver';
    case RunResultTier.goldVictory:
      return 'Gold';
    case RunResultTier.diamondVictory:
      return 'Perfect';
  }
}

String runResultTierLabel(RunResultTier tier) {
  switch (tier) {
    case RunResultTier.defeat:
      return 'Unfortunate Journey';
    case RunResultTier.bronzeVictory:
      return 'Bronze Victory';
    case RunResultTier.silverVictory:
      return 'Silver Victory';
    case RunResultTier.goldVictory:
      return 'Gold Victory';
    case RunResultTier.diamondVictory:
      return 'Perfect Victory';
  }
}
