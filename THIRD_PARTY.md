# Third-party notices

Ergo Chaos is licensed under the Apache License 2.0; see [LICENSE](LICENSE).
This covers the code, the shaders, the scenes and everything the game draws in code, e.g., the procedural backgrounds of the levels, the fireballs, the sparks and the rainbow stars.

The hand tracking (`scenes/ergo_meter/ergo_ski/`) was adapted in parts from [body-pose-estimation-with-godot](https://github.com/mristin/body-pose-estimation-with-godot) (same author).

The game includes, or is built with, the following third-party components.
Each keeps its own license.

Every release package carries our [LICENSE](LICENSE), this file and, in the directory `licenses/`, the license texts of Godot Engine (from [licenses/godot](licenses/godot)), ONNX Runtime (from its NuGet package) and the hand detection model (from [scenes/ergo_meter/ergo_ski/model/yolox/LICENSE](scenes/ergo_meter/ergo_ski/model/yolox/LICENSE)); see `.github/workflows/publish.yaml`.

## Distributed with the game

### Godot Engine

* Version: 4.6.2 (.NET); the C# project uses `Godot.NET.Sdk` 4.6.2, which brings the packages `GodotSharp` and `Godot.SourceGenerators` 4.6.2 (MIT)
* License: MIT
* Copyright (c) 2014-present Godot Engine contributors; Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur
* Source: https://godotengine.org
* License text: [licenses/godot/LICENSE.txt](licenses/godot/LICENSE.txt), with the notices of its own third-party components in [licenses/godot/COPYRIGHT.txt](licenses/godot/COPYRIGHT.txt) (both of Godot 4.6.2)

Godot Engine itself includes third-party components under their own licenses, e.g., FreeType, the fonts and the image libraries.
Their notices are listed at https://godotengine.org/license and in the file `COPYRIGHT.txt` of the Godot source code.

### .NET runtime

* License: MIT
* Copyright (c) .NET Foundation and Contributors
* Source: https://github.com/dotnet/runtime
* Third-party notices: https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT

The .NET build of Godot bundles the .NET runtime with the exported game.
ONNX Runtime pulls in the packages `System.Memory` 4.5.5 and `System.Numerics.Tensors` 9.0.0 (both MIT, Copyright (c) .NET Foundation and Contributors).

### ONNX Runtime

* Packages: `Microsoft.ML.OnnxRuntime` 1.24.4 and `Microsoft.ML.OnnxRuntime.Managed` 1.24.4
* License: MIT
* Copyright (c) Microsoft Corporation
* Source: https://github.com/microsoft/onnxruntime
* License text and third-party notices: `LICENSE` and `ThirdPartyNotices.txt` in the NuGet packages

### YOLOX-Body-Head-Hand (hand and head detection)

* Files: `scenes/ergo_meter/ergo_ski/model/yolox/yolox_n_body_head_hand_Nx3xHxW.onnx`, with its description `yolox_n_body_head_hand.json`
* Model: the nano model of YOLOX-Body-Head-Hand, without the built-in post-processing, input N x 3 x H x W (BGR, [0, 255])
* License: Apache License 2.0
* Copyright (c) PINTO0309 (Katsuya Hyodo); based on YOLOX by Megvii (https://github.com/Megvii-BaseDetection/YOLOX)
* Source: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/426_YOLOX-Body-Head-Hand; taken over from steppe-rescue and bird-dog (SHA-256 `2cfe872bbf195743a5cac7a36c45c18f10422b01e7ca33cad486c9665283d6a1`)
* License text: [scenes/ergo_meter/ergo_ski/model/yolox/LICENSE](scenes/ergo_meter/ergo_ski/model/yolox/LICENSE)

We distribute the model unmodified.
The pre- and post-processing in `HandDetector.cs` were adapted from steppe-rescue (same author).

### Images

The images are in `assets/images/`.

| Files | Source | License |
|---|---|---|
| `speedometer.png` | https://opengameart.org/content/speedometer-0 | **TODO:** verify on the page (we could not open it) |
| `spaceship.png`, `spaceship_red.png`, `spaceship_blue.png` | https://opengameart.org/content/spaceships-1 | **TODO:** verify on the page (we could not open it), and whether the red and the blue ships are recolored versions |
| `paint_splat_a.svg` to `paint_splat_d.svg` (the goo) | Kenney, Yellow Paint Pack, https://kenney.nl/assets/yellow-paint-pack | CC0 1.0 (public domain) |
| `background.png` | https://opengameart.org/content/backgrounds-topdown-games | **TODO:** verify on the page; no scene uses this image any more since the backgrounds became shaders, so it can probably be removed |
| `robot.png`, `villain.png`, `unicorn.png`, `splash_screen.png`, `mission_accomplished.png`, `mission_failed.png`, `game_finished.png`, `laser_gate.png`, `red_light.png`, `yellow_light.png`, `green_light.png`, `danger1.png`, `danger2.svg`, `danger3.svg`, `danger4.svg`, `thick_wall_texture.png`, `thick_wall_texture_small.png`, `tile.png`, `tile_small.png` | **TODO:** unknown | **TODO:** unknown |
| `pad.svg`, `recharge_pad.svg`, `connected_switch_symbol.svg`, `disconnected_switch_symbol.svg` | **TODO:** these look hand-written (a few lines of SVG); confirm that they are ours | **TODO** |

### Shader helpers

`hash12` and `hash22` in `scenes/levels/common/noise.gdshaderinc` are taken from David Hoskins' "Hash without Sine" (https://www.shadertoy.com/view/4djSRW, MIT, Copyright (c) 2014 David Hoskins).


## Used only for development, not distributed

| Component | Version | License | Source |
|---|---|---|---|
| dotnet-format (pinned in `.config/dotnet-tools.json`; the CI uses the `dotnet format` of the .NET 8 SDK) | 5.1.250801 | MIT (not checked against the package) | https://github.com/dotnet/format |
