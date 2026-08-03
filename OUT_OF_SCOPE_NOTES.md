# Out-of-scope notes

Observations logged during implementation but deliberately NOT fixed, because they fall outside the phase being implemented.

## Noted during Phase 6

- Turning "Daily reminder" ON in Settings never requests notification authorization; permission is only ever requested during onboarding. If a user declines at onboarding (or was never asked), `ReminderScheduler.sync()` silently schedules nothing and the toggle looks live but is inert. A Settings-side authorization request (or a "notifications are off in iOS Settings" hint) would close this, but Phase 6 specifies neither.
- Tapping the reminder notification while the app is open on the Trends or Settings tab sets `openQuestionnaireRequested` but does not switch to the Today tab, so the questionnaire sheet only appears once the user navigates back to Today. Phase 6 specifies only that `TodayView` observes the flag, so no tab routing was added.

## Noted during Phase 8-10

- `AppViewModel.weeklyReadout()`'s "7-day vs 60-day" rows and the existing Trends chart's band (`TrendBuilder`/`trendData`) both call `BaselineCalculator` but split "prior values" slightly differently (dropLast(7) vs dropLast(1) relative to the single newest value). With exactly 7-13 measured days on file this could in theory put one view in "established" and the other in "building" for the same metric at the same moment. Not observed in the seeded 45-day fixture (both were well past the boundary), and reconciling them would mean changing `TrendBuilder`'s existing semantics, which is out of scope for Phase 8-10.
- The Weekly readout's "days outside band" count only considers rMSSD (per the plan's own wording, "band-exit count"); it does not also count RHR/gap-peak band exits. Left as rMSSD-only since the plan doesn't specify combining metrics for this figure and combining them risks reading like a blended score.
