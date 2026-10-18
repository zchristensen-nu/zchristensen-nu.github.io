# Commute Log (iOS)

An iPhone app that logs your commute door to door, with no taps, and turns it into a dashboard: how
often you hit a severe delay, what a bad day costs, your average trip, and the time you need to leave
by to make it in on time.

SwiftUI · SwiftData · Swift Charts · Core Location · Core Motion · MapKit. iOS 17+. No server, no
accounts: everything stays on the phone.

## Run it

```sh
brew install xcodegen
cd apps/commute-logger
xcodegen            # writes CommuteLogger.xcodeproj from project.yml
open CommuteLogger.xcodeproj
```

Pick your team under **Signing & Capabilities**, change the bundle ID if needed
(`com.example.commutelogger`), and run on a real iPhone. Geofences and visits don't fire in the
Simulator unless you feed it a GPX route. **Settings → Add sample data** (or "Look around with sample
data first" during setup) fills the dashboard with ten weeks of realistic trips.

Tests: `⌘U`, or `xcodebuild test -scheme CommuteLogger -destination 'platform=iOS Simulator,name=iPhone 16'`.

## How automatic logging works

| Signal | Used for | Cost |
| --- | --- | --- |
| Geofences around home and work (`CLCircularRegion`) | Notice you left one place and reached the other. iOS wakes or relaunches the app for these, even when it's closed. | Very low |
| Visits (`CLVisit`) | Exact time you walked out the door and settled in at the other end, so both ends are truly door to door. Also learns where you sleep and work so setup can suggest home and work. | Very low |
| Significant location changes | Relaunches the app if iOS terminated it. | Very low |
| GPS, only while a trip is under way | Distance, route map, and time spent stopped or crawling (traffic, lights, platforms). Optional. | Moderate, during the trip only |
| Apple Maps ETA at departure (`MKDirections`) | Compare your actual trip with the traffic-aware prediction. | One request per trip |
| Motion activity (`CMMotionActivityManager`) | Tell driving, transit, cycling and walking apart after the trip. | None (iOS records it anyway) |

The rules live in `CommuteDetector`, a plain value-type state machine with unit tests:

- Leaving home on a workday opens a trip **to work**; leaving work opens a trip **home**.
- Reaching the other place logs it. Coming back to where you started (forgot your keys) discards it.
- Trips under 3 minutes or that don't arrive within 3 hours (you went somewhere else) are dropped.
- When a `CLVisit` arrives with a more accurate time for either end, the trip is adjusted.
- Its state is saved after every event, so a trip survives the app being relaunched mid-commute.

Location permission has to be **Always** for this to work while the app is closed. The app asks for
While Using first, then offers the upgrade, which is the order iOS requires.

## The dashboard

Switch between **To work** and **To home**, and between the last 30 days, 90 days, year, or everything.

- **Leave home by.** The latest departure that would have got you in on time on 9 of 10 days
  (adjustable to 4 of 5 or 19 of 20). It groups trips into 15-minute departure windows first, so if
  leaving at 8:15 runs into rush hour it will tell you to leave in the 7:45 window instead. With too
  few trips per window it falls back to all trips. Shows how many past trips that time would have
  made. For the trip home, it shows your quickest window to leave instead.
- **Typical, average, bad day, buffer.** Median trip, mean, the 90th-percentile "bad day", and the
  buffer to add on top of typical.
- **Severe and minor delays.** A trip is a minor delay at 5+ minutes over typical and severe at 15+
  (both adjustable). Counts and share of trips.
- **Distance and stopped time** from recorded routes.
- **What the data says.** Plain-language findings when the data backs them: which departure time saves
  the most, slowest and quickest weekdays, how often severe delays happen per month, share of time
  stopped, how you compare with Apple Maps' estimate, whether the last two weeks were slower, and your
  most common tagged delay.
- **Charts.** Recent trips colored by delay level against your typical line; every trip by departure
  time with the typical time per window; average by weekday; week-by-week trend. Tap for details.
- **What slows you down.** Tag trips with causes (traffic, accident, construction, weather, transit
  delay, missed connection, detour) and see which ones happen most and what they cost.

You also get a notification when a trip is logged, with how it compared to usual, an optional weekday reminder
ten minutes before your leave-by time, manual start/stop for one-offs, manual entry for past trips,
and CSV export.

## Code map

```
CommuteLogger/
  App/          app entry, AppDelegate (background relaunch), shared SwiftData container
  Models/       Commute (@Model), enums and value types, AppSettings (UserDefaults-backed)
  Tracking/     CommuteDetector (state machine), CommuteTracker (Core Location delegate), PlaceLearner
  Analytics/    CommuteAnalytics (stats, leave-by, buckets, insights), formatting
  Services/     traffic estimate, motion classification, notifications, CSV export, sample data
  Views/        Dashboard, History (trip list, detail, add), Settings (incl. place picker), Onboarding
CommuteLoggerTests/   detector and analytics tests
```

## Limits worth knowing

- iOS decides exactly when geofence events fire; exits usually arrive within a minute or two of
  crossing the boundary. Visit data corrects the times, but it can arrive later still.
- If you force-quit the app from the app switcher, iOS stops relaunching it for location events
  until you open it again.
- Transit vs. driving is a heuristic (trains read as "automotive" to Core Motion); fix it on the trip
  if it guesses wrong.
- Only home ↔ work trips are logged. A stop on the way (coffee, daycare) is counted as part of the
  commute; tag it as a detour if you want to see it separately.
