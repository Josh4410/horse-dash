# Horse Dash

An original three-lane endless runner for iOS, written in Swift with SpriteKit and SwiftUI. You ride a horse through biomes that change as you go further: Sunny Farm, Golden Fields, Blazing Desert, Frosty Peaks, Lava Ridge, Aurora Plains and Sugar Meadow, then the loop starts again from the fields.

## Run it

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open HorseDash.xcodeproj
```

Choose your team under Signing & Capabilities to run on a device. Haptics only work on a real iPhone, not the simulator.

## Controls

| Swipe | Action |
| --- | --- |
| Left / right | Change lane (fires mid-swipe, no need to lift) |
| Up | Jump (buffered if pressed just before landing) |
| Down | Slide; in the air it fast-falls and slides on landing |

## Obstacles

- **Show-jump poles**: jump them
- **Striped beams**: slide under
- **Wagons**: change lane

Hay bales are the currency. Spend them on skins in the store.

## Layout

```
HorseDash/
  App/       App entry, screen routing
  Game/      Tuning, PlayerModel, Spawner, Biomes, GameScene, GameSession
  Art/       Procedural art (all drawn in code, no image assets)
  Core/      GameStore (save data), Haptics, Analytics, Ads stub, revive A/B
  UI/        Menu, HUD, overlays, high scores, skins store, settings
HorseDashTests/  Spawner fairness, player physics, biomes, store
```

All feel numbers (speeds, jump height, lane change time, swipe threshold) live in `Game/Tuning.swift`.

## Notes

- The rewarded ad for the one-time revive is a stub (`StubRewardedAdProvider`). Swap in a real SDK behind the `RewardedAdProvider` protocol.
- Analytics go to the console by default. Replace `Analytics.shared.sink` with a real backend. Every collected field is listed in Settings, and players can turn it off.
- Difficulty ramps with distance only. The optional Dynamic difficulty setting adjusts spacing slightly based on the player's own recent run lengths.
- Music toggle is stored but no tracks are bundled yet.
- Power-ups are not implemented yet.
