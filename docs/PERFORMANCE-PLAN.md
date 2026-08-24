# Performance Plan

Optimization work needs a stable scenario and comparable measurements. A faster menu or a fresh empty save does not prove multiplayer improvement.

## Baseline record

Create a dated Markdown file in `docs/results/` containing:

- exact Project Zomboid version and branch;
- modpack commit or archive version;
- CPU, GPU, RAM, storage, operating system, resolution, and frame cap;
- Java memory/startup options if changed;
- hosted-server provider tier and region;
- number of connected players;
- save age, cell/location, weather, zombie population, vehicles, and nearby constructions;
- median FPS, 1% low FPS, RAM use, load/join time, and observed server pauses;
- the same fixed five-to-ten-minute route or activity sequence.

## Investigation order

1. Confirm whether the bottleneck is client rendering, client simulation, network/server simulation, garbage collection, loading, or disk access.
2. Reproduce with the unchanged full mod list.
3. Test a vanilla control with the same display and population settings.
4. Bisect the mod list by functional groups while preserving hard dependencies and map order.
5. Inspect frequently running Lua event handlers, repeated world/object scans, tick-based allocations, excessive logging, textures, models, and known mod conflicts.
6. Change one cause at a time and repeat the recorded scenario at least three times.
7. Keep a change only when its result is repeatable and it does not change intended gameplay unexpectedly.

## Four-player acceptance target

Concrete thresholds should be chosen after the first baseline. At minimum, releases should avoid regressions in join time, sustained frame pacing, server responsiveness, and memory growth during a representative four-player session.
