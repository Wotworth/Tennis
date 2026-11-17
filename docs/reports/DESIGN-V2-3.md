# Session summary: key figures against your average, and a trends tab (17 Nov)

Release: [v0.6.33](https://github.com/Wotworth/Tennis/releases/tag/v0.6.33)

| Summary | Trends |
| --- | --- |
| ![summary](design-v2-3/summary.png) | ![trends](design-v2-3/trends.png) |

**Summary.** It now opens with your key figures for the session, in the order you asked. Each figure shows "above / below / same as your average" with the average of all your earlier sessions, then the average of the **last ten** underneath, so you can see if your average is moving.
- **Accuracy:** % of your shots in, serves left out, and how deep the ones in landed.
- **Serves:** % in, speed, and spin (its commonest kind, such as topspin or slice, and how many feet shorter it made the serve land).
- **Topspin:** forehand and backhand: how many feet shorter spin made the ball land, against the same shot without spin.
- **Speed:** forehand and backhand at contact, serves left out.

The figures appear once "which one is you?" is answered, because until then the app doesn't know which player is you. The older per-player rows stay below.

**Trends tab.** A new fifth tab shows each figure over your sessions, with this session as a large green dot and the restrings of your racquet as dashed lines. A **grey line** is the average of the last ten sessions at each point, so you can see which way it's heading. That makes it easy to spot a change after new strings or a tweak.

**The sample session.** Its earlier sessions now have made-up figures too, and every number on these pages is still odd. The odd-numbers check passes.

## What CI proved

- **Build and release (run 44171693473): passed.** The app built, and its unit and screenshot tests passed.
- **The tests cover:**
  - the summary and trends tab render on the sample session;
  - every number on them is odd, including both averages;
  - a pinch zooms the court map without changing tab.

## On your phone

1. Install v0.6.33, then open **Sessions → vision · sample**.
2. On **summary**, answer "which one is you?" if asked. The key figures then appear: **accuracy, serves, topspin, speed**. Each shows "above / below your average" and a "last ten" figure underneath.
3. Swipe to **trends**, the last tab. Each figure has its own chart, with this session as the large green dot and a grey line for the average of the last ten sessions.
4. On **court**, pinch to zoom in on a cluster of bounces and tap one. Double-tap to see the whole court again.
5. Check that the **iPhone test** tiles are gone from the sessions page.
6. Tell me whether the summary helps you spot a good or bad day, and what you'd add.
