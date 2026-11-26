# Tradl Widget Lab

Flutter Web implementation of the Tradl take-home. The app uses generated market data only; no backend or network feed is required.

## Run
```bash
flutter pub get
flutter run -d chrome
```
Build:
```bash
flutter build web --release
```

## State design (10 lines)
1. `Workspace` owns panel layout, widget-local settings, undo history and persistence.
2. `MarketStore` owns seeded history and the latest tick notifier for each symbol.
3. Each channel owns one selected symbol; linked panels derive their symbol from that channel.
4. Unlinked panels retain their own symbol and stop following channel changes.~
5. Panels do not call one another or hold references to other panels.
6. Chart and table read the shared market store.
7. View settings such as range and sort order remain on their panel.
8. Layout serialises to SharedPreferences after each layout mutation.
9. A panel catches its own render failures and displays its own error state.
10. The feed can be paused, dropped, and rate-adjusted from the development strip.

## Packages
- `fl_chart`: line chart rendering. Chosen because it is Flutter-native, lightweight to integrate, and supports custom line charts. Alternatives: `syncfusion_flutter_charts` (feature-rich but heavier/licensing considerations), `graphic` (flexible grammar but more setup), and custom `CustomPainter` (smallest dependency but requires implementing axes, hit testing and accessibility).
- `shared_preferences`: small local layout persistence. Alternatives: Hive/Isar (better for larger structured/offline datasets but unnecessary for a single small JSON layout), SQLite/Drift (relational querying not needed), browser localStorage directly (platform-specific and less idiomatic).
- Drag, resize, state and script editor are implemented with Flutter primitives rather than adding packages. Alternatives include `flutter_draggable_gridview`, `dashboard`/layout packages, Riverpod/Bloc, and code-editor packages. They were not selected to keep the interaction model explicit and avoid dependency constraints for a small take-home.

## Trade-offs / known simplifications
- The grid is a custom 12-column canvas with snap-to-cell movement and resize. Collision handling pushes overlapping panels down; it is intentionally simpler than a full compaction/packing algorithm.
- The script runner is a safe constrained stub/spec renderer, not a JavaScript interpreter. It recognises a simple stat/table intent, renders the result, and exposes a demo threshold parameter. It deliberately never evaluates arbitrary user code.
- The text editor is a plain monospace field, not syntax-highlighted. A full editor adds bundle size and is not needed to demonstrate autosave and the stub contract.
- The seeded generator is deterministic for a fixed sequence of actions. Changing seed resets the PRNG sequence; it does not regenerate the existing 300-point history.
- The table currently displays the three required symbols and derives change from the visible history window.
- Feed-drop state is displayed per panel. A production implementation would model feed health as a stream and distinguish stale data from disconnected data.
- Verify on the target Flutter SDK; package APIs can evolve.
