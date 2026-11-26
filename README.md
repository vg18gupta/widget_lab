# Widget Lab

A Flutter Web workspace where a user places widgets on a 12-column drag-and-drop grid, links them to shared colour channels, and watches them update live. All market data is generated inside the app: a seeded mock feed, no backend, no network calls.

- **Hosted app:** _not deployed yet_ (add the link here once it is hosted)
- **Repository:** _not published yet_ (add the link here)

Tested with Flutter 3.50.1 (stable) and Dart 3.3 or newer.

## Run

```bash
flutter pub get
flutter run -d chrome
```

Build a release bundle:

```bash
flutter build web --release
```

Run the tests and analyzer:

```bash
flutter test
flutter analyze
```

## What it does

- **Grid.** Drag a widget from the hub onto the canvas. A shadow shows where it will land. Move by the header, resize from any edge or corner, double-click a header for full screen, and use the header menu to duplicate or remove. Ctrl+Z or Cmd+Z undoes the last layout change. Below 900 px the widgets stack in one column.
- **Chart.** A line plot of one symbol over the last 1m, 5m or 15m.
- **Table.** One row per symbol with last value, change and % change. Click a header to sort; click a row to select that symbol.
- **Script.** A code editor that autosaves, a console, and a result shown as a stat tile or a table. Declared `param`s become sliders.
- **Linking.** Every header has a channel picker: Pink, Blue, Green, Amber, or Unlinked. Widgets on a channel share a symbol.
- **Lock layout** (stretch goal, see below). A lock button stops every layout change while keeping channels, symbols and full screen working.
- **Dev strip.** Pause the feed, change the update rate (100, 150 or 200 ms), drop and reconnect the connection, and set the seed.

## Layout

| Rule | How it works |
|---|---|
| Grid | 12 columns, 56 px rows. Every move and resize snaps to a cell. |
| Minimum sizes | Chart 3×3, table 4×3, script 4×5 cells. |
| Tidy up | The panel being moved or dropped keeps its cell. Every other panel settles into the highest free row, top to bottom. Panels pushed aside return when the moved panel leaves, and gaps close. |
| Undo | One undo step per drag, resize, add, remove or duplicate. Holds the last 30 changes. |
| Saving | Layout (positions, sizes, channels, locked state, channel symbols) saves on every layout change and is restored on reload. |

## Folder structure

The code is split into layers. Each layer depends only on the ones above it in this list, and the presentation layer never changes the stores directly.

```
lib/
  main.dart                    entry point: runApp
  app.dart                     MaterialApp; creates the market and controllers
  config/
    constants.dart             symbols, channel colours, row height, redraw settings
  domain/                      pure Dart, no Flutter, no storage
    panel.dart                 Panel (one widget on the grid), WidgetKind and its sizes
    tick.dart                  Tick (a timestamp and a price)
    grid_layout.dart           grid rules: settle, drag and resize targets, default layout
    script_runner.dart         runScript stub and param parsing
  data/                        sources of data and persistence
    mock_feed.dart            seeded random walk; the simulated market
    layout_repository.dart    stores the layout text (SharedPreferences)
    frame_budget.dart         rolling frame times, used by the chart redraw gate
  store/                       state that the UI reads
    market_store.dart         prices, history windows, notifiers, batch notifier
    workspace_store.dart      panels, channel symbols, lock, undo history
  controller/                  actions and policies; the only code that changes the stores
    app_controllers.dart      builds and holds all of the above
    layout_controller.dart    add, move, resize, remove, duplicate, undo, reset, lock
    layout_persistence.dart   converts the layout to and from saved text
    channel_controller.dart   link to a channel, change the shared symbol
    script_controller.dart    run a script, set its params
    table_controller.dart     table rows and sorting
    chart_controller.dart     chart series and the redraw gate
  presentation/                widgets only; they draw what the controllers return
    lab_home.dart              top bar, widget hub, canvas, dev strip
    panel_card.dart            one card: header, chart, table or script body
    grid_painter.dart          background grid lines
    widget_error.dart          the error tile shown in place of a failed widget
  theme/
    palette.dart               every colour, and buildAppTheme()
test/                          unit and widget tests, one file per area
web/                           host page, manifest and icons for Flutter web
```

## Architecture

```
                 ┌──────────────────────────────┐
                 │  app.dart  (MaterialApp)     │  theme ← theme/palette.dart
                 └──────────────┬───────────────┘
                                │ creates
                 ┌──────────────▼───────────────┐
                 │  controller/app_controllers  │  one place that wires everything
                 └──┬─────────────┬──────────┬──┘
                    │             │          │
   ┌────────────────▼───┐  ┌──────▼──────┐  ┌▼────────────────────────┐
   │ controller/        │  │ store/      │  │ data/                   │
   │ layout · channel · │─▶│ workspace   │  │ mock_feed → market      │
   │ script · table ·   │  │ market      │◀─│ layout_repository       │
   │ chart              │  └──────┬──────┘  │ frame_budget            │
   └────────┬───────────┘         │ read    └─────────────────────────┘
            │ rules from          │
   ┌────────▼───────────┐         │
   │ domain/            │         │
   │ grid_layout ·      │         │
   │ script_runner ·    │         │
   │ panel · tick       │         │
   └────────────────────┘         │
                                  ▼
   ┌──────────────────────────────────────────────────────────┐
   │ presentation/  lab_home (top bar · hub · canvas · dev)   │
   │                  └─ panel_card × N (chart · table · script)│
   └──────────────────────────────────────────────────────────┘
        presentation reads the stores and calls the controllers
```

How the pieces talk:

- **Feed tick.** `MockFeed` produces prices and hands them to `MarketStore`, which stores them, updates each symbol's notifier, and fires `batch`. Charts listen to their symbol; the table listens to `batch`. Only those widgets rebuild.
- **User action.** A gesture or menu item in `presentation/` calls a controller. The controller changes the store, notifies listeners, and saves through the repository. Pixel offsets are converted to cells in `presentation/` before the call.
- **Channels.** `ChannelController` updates the channel's symbol and every linked panel. Widgets never call each other.
- **Scripts.** `ScriptController` runs `runScript` with the market's price lookup and the panel's parameters. The card renders the spec it returns.

## State design (10 lines)

1. `WorkspaceStore` holds panel layout, the lock and the undo history. `LayoutController` changes them and saves.
2. `MarketStore` holds 15 minutes of ticks per symbol, one `ValueNotifier` per symbol, and a `batch` notifier that fires once per feed tick. `MockFeed` produces the ticks.
3. Each channel owns one symbol. A widget joining a channel with members takes that symbol; the first widget in an empty channel sets it.
4. Unlinked panels keep their own symbol and stop following when unlinked.
5. Panels never call one another or hold references to one another; they read and write their channel through `ChannelController`.
6. Charts subscribe to their symbol's notifier. The table subscribes to `batch`. Both read history from the store through their controllers.
7. View settings (chart range, sort column, script code and parameter values) stay on the panel and are not synced.
8. Layout serialises to SharedPreferences after each layout change, including channel symbols and the lock.
9. Each widget's build path catches its own errors and shows an error state inside its own card.
10. The dev strip controls pause, drop, rate and seed of the feed.

## Packages

- **`fl_chart`** (^0.70.2): line chart rendering. It is Flutter-native and lightweight to integrate. Alternatives: `syncfusion_flutter_charts` (richer, but heavier and licensed), `graphic` (more setup), and a custom `CustomPainter` (no dependency, but axes, hit testing and accessibility would all be ours to build).
- **`shared_preferences`** (^2.3.3): saves the small JSON layout. Alternatives: Hive or Isar (better for large or relational data, unnecessary here), Drift (no relational queries needed), or raw `localStorage` (web-only and less idiomatic).
- **Drag, resize, grid, state and the script editor** use Flutter primitives, not packages. Package options such as `flutter_draggable_gridview`, a dashboard layout package, Riverpod or Bloc, or a code-editor package would each have fixed the interaction model in someone else's shape. For a take-home, keeping that logic explicit is worth more.

## Script contract

`runScript(code, latest, params)` is a stub, not an interpreter. It never evaluates code. `latest` is a function that returns a symbol's current price.

- Any script containing the word `table` returns a table of the three current prices.
- Otherwise it reads `label: "…"` and `value: …` and returns a stat tile. `value` can be a number or the name of a declared parameter.
- A parameter is declared as `param name: 10 [0..100]`. It becomes a slider in the widget, and moving it re-runs the script.
- Errors (empty script, no `value:` field, unknown name) show as a script error and a console line.

## Performance

Measured with `test/perf_rebuild_test.dart`: eight widgets (four charts, two tables, two scripts) over 13 feed ticks.

| Widget | Rebuilds per tick |
|---|---|
| Panel card (header and frame) | 0 |
| Script | 0 |
| Chart | 1 |
| Table | 1 |

Every symbol changes on every tick, so each chart and table has new data each tick and rebuilds once. Nothing else does. Charts skip fl_chart's per-tick tween so they don't repaint continuously. Each chart draws at most 300 points.

**Not measured:** frame times in the browser. The test counts rebuilds, not milliseconds. To check the "eight widgets stay smooth" goal properly, profile the hosted app with Flutter DevTools.

## Stretch goal: lock layout

A lock button in the top bar stops every layout change: add, drag, resize, remove, duplicate, undo and reset. The hub tiles and the "+ Add" chips are disabled while locked, and the header menu's Duplicate and Remove are greyed out. Channels, symbol picks, full screen and the dev strip still work. The lock is saved with the layout.

## Trade-offs

- **Grid rules.** Layout uses one settle pass: the moved or dropped panel keeps its cell and the others settle around it. This is not a full packing algorithm, so a widget dropped above an empty gap stays where it was dropped, and the gap stays above it.
- **Full screen remounts the widget.** The card moves in the widget tree, so its console and scroll position reset when toggled. Script text and layout are unaffected.
- **Narrow layout.** Below 900 px, drag, resize and the hub are off. Widgets stack and can be added with the "+ Add" chips.
- **Table rows.** There are three symbols, so the table never shows more than three rows. It shows as many rows as fit and summarises the rest as "+N more", but "more rows" is capped by the data.
- **Chart windows.** The store keeps 15 minutes of ticks per symbol, so 1m, 5m and 15m come from real timestamps. Each window is downsampled to at most 300 points. While the feed is paused or dropped, windows stop sliding.
- **Seed.** Changing the seed restarts the live random walk. The 15 minutes of history already in memory are not regenerated.
- **Error containment.** Chart, table and script bodies are guarded, so a failure shows that card's error state with Retry. Anything outside those guards shows the global error tile instead, which contains the failure to its own element but has no card-specific message. Retry re-runs only that card, so a data source that keeps failing will keep failing.
- **Subscriptions.** Charts subscribe to each symbol. The table subscribes to the shared tick batch, because it reads all three symbols. Both read history from the store.
- **Chart redraws.** Charts draw on every tick, except while frames run over budget. Then they batch to at most one draw every 500 ms (`batchedChartInterval`). The over-budget check uses a rolling average of frame times with hysteresis. It is not verified in the browser, and it can be switched off with `adaptiveChartBatching`.
- **Script.** `runScript` is a stub, not an interpreter. Its output does not yet depend on the symbol picked, and it never computes from history.
- **Editor and console.** The script editor is a plain monospace field, not syntax-highlighted. The console keeps the last 50 lines and is not saved across reloads.
- **Feed health.** Dropped state is shown per panel. A production version would model feed health as a stream and separate stale data from a dropped connection.
- **Lock.** It refuses layout changes; it is not a permission model. Its state is shown only by the icon in the top bar.
- **Saved layouts.** The storage key was renamed, so layouts saved before the rename reset to the default. Layouts saved by earlier versions keep their old sizes until Reset layout is pressed.
- **Performance evidence.** Rebuild counts are measured by a test. Frame times in the browser are not measured yet; use Flutter DevTools on the hosted app to check the "eight widgets stay smooth" goal.
- **Packages.** The grid, drag, resize, state and script editor use Flutter primitives, so the interaction model stays explicit. The cost is more code to own and test.
- **Layers.** The split into domain, data, store, controller and presentation is in place, but the layer tests still sit beside the widget tests in one `test/` folder. The controllers are tested through the stores rather than with fakes.

## Where AI was used

- I designed the architecture: the state model, the channel and symbol rules, the layout rules, and the trade-offs above. 
- AI was used to write the code and the test cases, and to draft some of the documentation. Every change was checked with `flutter analyze`, the full test suite, and a web build before moving on.
