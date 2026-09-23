# Pre-estimation review disposition

The frozen `pap.md` was not edited. It was committed before estimation in the
source repository at `a8f5cca` and tagged `wb-analysis-plan-20260907`.

- The generated results now lead with the prespecified unadjusted 2003 quota
  contrasts and retain adjusted estimates as secondary analyses.
- The unsupported rule that inferred zero SSK creation from current SSK absence
  was removed. `ssk_new` now uses only the `F2_8` creation gate and `F2_8b`
  quantity; unknown or skipped creation fields remain missing.
- Public-goods adjusted-model leverage and rank diagnostics are generated in
  `tabs/public_goods_leverage.csv`. Selection by reservation history is
  generated in `tabs/selection_by_reservation_history.csv`.
- The released-data comparison is described as a partial reconstruction of
  selected rows from the 2001 NBER working-paper version (w8615, PDF pages 31
  and 37), not a complete replication or a match to the later journal version.
- The Ganpur roster record (survey spelling Gonpur) is the sole numeric-ID
  disagreement and remains excluded from the main 2003 sample.

The strongest unresolved rival explanation is differential recall, reporting,
survival, or respondent/module composition in the 2006 current-officeholder
survey. Rotation and changing reservation strata also prevent interpreting the
2003 extensions as randomized effects without the original assignment roster.
