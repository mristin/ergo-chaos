# Contributing

Thank you for helping with Ergo Chaos!
This guide explains how to set up the development environment, how to run and test the game, and how to prepare a pull request.

## Overview

The game is made with [Godot] 4.6 (.NET), written in GDScript and C#:

* The hand tracking runs in C# (`scenes/ergo_meter/ergo_ski/`), adapted from [body-pose-estimation-with-godot] and, for the speed, from steppe-rescue.
  `ErgoSki.cs` shows the camera texture directly (mirrored on the GPU) and hands a camera frame to a background thread only when the thread asks for one, so that the frames never queue up.
  `HandDetector.cs` runs YOLOX-Body-Head-Hand nano (`model/yolox/`, input 384x288) through ONNX Runtime with one thread fewer than the CPU has and without spinning, which leaves the game smooth; on an i7-6600U it finds the hands about ten times per second.
  The heads anchor the players: in a two-player game, the best head in the left half of the (mirrored) picture is player A and the one in the right half player B; in a one-player game, the largest head is the player.
  A hand belongs to the nearest head within the reach of the arms, and it is the left hand if it is left of that head.
  Hands overlapping a head are dropped, since they are mostly faces.
  Without a head, the hands fall back to the halves of the picture.
* For each hand, a `Smoother` smooths the position, estimates how fast the hand moves up and down (the mean absolute vertical movement over the last five detections, in picture heights per second, on the capture times of the camera frames), and gives the speed some inertia (`InertialVelocity`, time constant 0.3 s).
  Between the detections, the displayed position glides towards where the hand is heading, so that the fireballs move smoothly.
  `ErgoSki` emits the result as `PlayerSpeedUpdated(player, hand, speed)`, and draws a fireball with a shader trail (`fireball/`) on each tracked hand.
  The direction of the movement does not matter, only its speed: we do not tell a push from a recovery, and we do not track the legs.
* `ErgoSki` can also recognize symbols from the height of the hands (`SymbolTracker`), a leftover from the demo; the game does not use them.
* `ErgoMeter` (`scenes/ergo_meter/ergo_meter.gd`) turns the four speeds into the signals of a `GameController` (`scenes/game_controller/`) and moves the four speedometers (`scenes/ergo_meter/speedometer/`).
  `KeyboardController` (`scenes/keyboard_controller/`) is the other controller, for testing.
* `Player` (`scenes/player/`) is a spaceship with a left and a right engine, each in [0, 1].
  The mean of the two pushes the ship forward, their difference turns it.
  Flying drains the battery by the distance; a `PlayerEffect` changes the speed, the turning or the battery drain while the ship is in a danger zone or on a recharge pad.
* The `game` scene (`scenes/game/`) only orchestrates: it holds the order of the levels (`level_scene_paths`: playground, roundabout, switcher, pit, chase, stable), wires the controllers to the players, sets up the split screen (`scenes/game_screen/`) with one camera per player, and shows the final messages (`scenes/final_message/`).
  The rules live in `level_state` (`scenes/level_state/`): the level is accomplished when all the goo is collected, and failed as soon as one ship's battery runs empty.
* The game starts at the camera selection (`scenes/select_camera/`), which looks for the cameras supporting 640x480 YUYV, and then hands the chosen camera to `ErgoMeter` and starts the game.
* The levels live in `scenes/levels/`, each in its own folder, and inherit from `scenes/levels/base/base.tscn` (the arena with its walls).
  Every level must have the nodes `PlayerA`, `PlayerB` and `GooContainer`; keep the players above the goo (`z_index`).
  The objects of the levels (laser gates, switch gates, recharge pads, spark fields, rotating fireballs, robots, villains and unicorns) live in `scenes/objects/`.
* The test harness and the test levels live in `scenes/tests/`.

The backgrounds are procedural shaders.
The base level has two layers, `Space` (around the arena) and `Floor` (the arena itself).
`Space` uses `scenes/levels/common/deep_space.gdshader`, which each level tints by overriding its colors, and `Floor` uses a shader of the level's own, e.g., `scenes/levels/pit/magma_floor.gdshader`.
The shared helpers (hashes, noise, fbm) are in `scenes/levels/common/noise.gdshaderinc`.
Keep the shaders cheap, since the game has to run on laptops with an integrated GPU next to the hand tracking, and keep the backgrounds calm, so that the players do not mistake them for the dangers.

This is a game for children, so we avoid violence as well as sad and realistic themes: nothing is destroyed, the dangers only drain the battery, and a failed mission simply starts over.

[Godot]: https://godotengine.org
[body-pose-estimation-with-godot]: https://github.com/mristin/body-pose-estimation-with-godot

## Setting up the development environment

You need:

* [Git] and [Git LFS], since we keep the ONNX model and the PNG images in LFS,
* the [.NET 8 SDK], and
* the **.NET** build of [Godot 4.6.2] (also called "mono"; the standard build can not run C#).

[Git]: https://git-scm.com
[Git LFS]: https://git-lfs.com
[.NET 8 SDK]: https://dotnet.microsoft.com/download/dotnet/8.0
[Godot 4.6.2]: https://godotengine.org/download/archive/4.6.2-stable/

### Clone the repository

```
git lfs install
git clone https://github.com/mristin/ergo-chaos.git
cd ergo-chaos
git lfs pull
```

If the model or the images are missing or are only small text files, Git LFS was not set up before cloning.
Run `git lfs pull` again.

### Install Godot

Download the .NET build of Godot 4.6.2 and unpack it anywhere.
For example, on Linux:

```
export GODOT=~/apps/Godot_v4.6.2-stable_mono_linux_x86_64/Godot_v4.6.2-stable_mono_linux.x86_64
```

Put the line in your shell profile (e.g., `~/.bashrc`) so that you do not have to repeat it.

### Restore and build the C# code

```
dotnet restore
dotnet build "Ergo Chaos.sln"
```

## Running the game

Open the project in the Godot editor (Import, then select `project.godot`), and press F5.
The game needs a webcam which supports 640x480 in the YUYV format.
It waits a few seconds on the splash screen for the cameras to show up; if there are several suitable cameras, it asks which one to use, and without one, it explains the problem and quits on any key.

Press Escape twice to quit.

## Testing the levels in isolation

The test harness plays a single level at a time with the keyboard instead of the camera, so that you do not have to swing your arms during every test.
Open `scenes/tests/game_harness/game_harness.tscn` in the editor and press F6 (run the current scene).
Pick a level and press Play.

The keys set the power of an engine to full, half or zero, and the engine keeps it until you press another key of the same engine:

| Engine | Full | Half | Zero |
|---|---|---|---|
| Player A (red), left | Q | A | Z |
| Player A (red), right | W | S | X |
| Player B (blue), left | I | J | N |
| Player B (blue), right | O | K | M |

Only one key is read per frame, so press the keys one after the other.

The harness lists the levels of the game and the test levels in `scenes/tests/levels/`, each of which shows a single object (e.g., the laser gate, the recharge pad, the robot or the villain).
Note that the switcher is not in the list of the harness yet.

To add a test level:

1. Create `scenes/tests/levels/test_<name>/test_<name>.tscn` with `PlayerA`, `PlayerB` and a `GooContainer`, and put the object under test in it.
   The existing test levels keep a single goo in the container, so that collecting it finishes the test.
2. Register it in `scene_level_paths` of `scenes/tests/game_harness/game_harness.gd`.

To add a level to the game, add it to `level_scene_paths` in `scenes/game/game.gd` (and to the harness).

## Formatting

Before you commit, re-format the C# code:

```
dotnet format "Ergo Chaos.sln"
```

We have no formatter or linter for GDScript set up yet; please follow the style of the existing scripts (4 spaces, typed variables, `class_name` for the scenes other scripts refer to).

## Continuous integration

GitHub Actions restores the packages, checks the formatting of the C# code (`dotnet format --verify-no-changes`) and builds it on every pull request and on every push to `main`; see `.github/workflows/ci.yaml`.

## Exporting the game

The export presets live in `export_presets.cfg`; there are presets for Linux, Windows and macOS.
They include the ONNX model explicitly (`include_filter="*.onnx"`), since Godot does not export it as a resource otherwise, and they exclude the build outputs (`build/`, `dist/`, `notices/`) and the test scenes.

Install the .NET export templates of Godot 4.6.2 (in the editor: Editor, Manage Export Templates), and run, e.g.:

```
mkdir -p build/linux
$GODOT --headless --path . --export-release "Linux" build/linux/ergo-chaos.x86_64
```

Godot builds the C# part for each platform itself (`dotnet publish`), including the native libraries of ONNX Runtime.
Mind that Godot exits with zero even if that build fails, and then writes a package without the C# part; check its output for `ERROR`.

The macOS app is universal, but ONNX Runtime provides its native library only for Apple Silicon, so the hand tracking does not work on Intel Macs.

### Releases

When you publish a release on GitHub, the workflow `.github/workflows/publish.yaml` exports the game for Linux, Windows and macOS, adds our license, [THIRD_PARTY.md](THIRD_PARTY.md) and the license texts of the distributed components, and attaches the packages to the release.

You can also start the workflow by hand (Actions, Publish, Run workflow).
Without a tag, it only tries out the packaging and uploads the packages as the artifacts of the run.
With the tag of an existing release, e.g., `v1.0.0`, it also attaches the packages to that release; they are then built from the branch the workflow runs on, not from the tag.

When you add a third-party component, list it in [THIRD_PARTY.md](THIRD_PARTY.md).

## Commit messages

We follow Chris Beams' [guidelines on commit messages]:

1) Separate subject from body with a blank line
2) Limit the subject line to 50 characters
3) Capitalize the subject line
4) Do not end the subject line with a period
5) Use the imperative mood in the subject line
6) Wrap the body at 72 characters
7) Use the body to explain *what* and *why* vs. *how*

[guidelines on commit messages]: https://chris.beams.io/posts/git-commit/
