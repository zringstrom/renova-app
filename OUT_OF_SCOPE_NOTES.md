# Out-of-scope notes

Observations logged during implementation but deliberately NOT fixed, because they fall outside the phase being implemented.

## Noted during Phase 6

- Turning "Daily reminder" ON in Settings never requests notification authorization; permission is only ever requested during onboarding. If a user declines at onboarding (or was never asked), `ReminderScheduler.sync()` silently schedules nothing and the toggle looks live but is inert. A Settings-side authorization request (or a "notifications are off in iOS Settings" hint) would close this, but Phase 6 specifies neither.
- Tapping the reminder notification while the app is open on the Trends or Settings tab sets `openQuestionnaireRequested` but does not switch to the Today tab, so the questionnaire sheet only appears once the user navigates back to Today. Phase 6 specifies only that `TodayView` observes the flag, so no tab routing was added.
