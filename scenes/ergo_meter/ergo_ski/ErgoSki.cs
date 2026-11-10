using Godot;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

using Microsoft.ML.OnnxRuntime;

namespace ErgoSkiing
{

    public static class Player
    {
        public const string A = "A";
        public const string B = "B";
    }

    public static class Hand
    {
        public const string Left = "Left";
        public const string Right = "Right";
    }

    public static class Symbol
    {
        public const string A = "A";
        public const string Y = "Y";
        public const string N = "N";
        public const string T = "T";
        public const string L = "L";
        public const string K = "K";
        public const string EMPTY = "";
    }

    namespace Impl
    {

        /// <summary>
        /// The hands of a player in normalized, mirrored picture coordinates, as
        /// the player sees them on the screen; null if not found.
        /// </summary>
        public sealed class Hands
        {
            public Vector2? Left { get; }
            public Vector2? Right { get; }

            public Hands(Vector2? left, Vector2? right)
            {
                Left = left;
                Right = right;
            }

            public override string ToString() => $"left {Left}, right {Right}";
        }

        /// <summary>The hands of player A (red, left) and player B (blue, right).</summary>
        public sealed class PlayerHands
        {
            public Hands? A { get; }
            public Hands? B { get; }

            public PlayerHands(Hands? a, Hands? b)
            {
                A = a;
                B = b;
            }
        }

        /// <summary>The hands found in one camera picture.</summary>
        public sealed class Inference
        {
            public readonly PlayerHands PlayerHands;

            /// <summary>When the camera delivered the picture, in seconds of the ErgoSki clock.</summary>
            public readonly double CaptureTime;

            public Inference(PlayerHands playerHands, double captureTime)
            {
                PlayerHands = playerHands;
                CaptureTime = captureTime;
            }

            public override string ToString() =>
                $"A: {PlayerHands.A?.ToString() ?? "none"}; B: {PlayerHands.B?.ToString() ?? "none"}";
        }

        /// <summary>Represent a position with timestamp for speed calculation.</summary>
        public class TimestampedPosition
        {
            public Vector2 Position { get; }
            public float Time { get; }

            public TimestampedPosition(Vector2 position, float time)
            {
                Position = position;
                Time = time;
            }
        }

        /// <summary>Represent a symbol observation with timestamp.</summary>
        public class TimestampedSymbol
        {
            public float Time { get; }
            public string Symbol { get; }

            public TimestampedSymbol(float time, string symbol)
            {
                Time = time;
                Symbol = symbol;
            }
        }

        public class InertialVelocity
        {
            private float _v;
            private readonly float _tau;

            public float Get()
            {
                return _v;
            }

            public InertialVelocity()
            {
                // NOTE (mristin):
                // The time constant in seconds; the higher, the more inertia. With
                // the faster hand detector, we can afford a snappier response.
                _tau = 0.3f;
                _v = 0f;
            }

            public void Update(float velocity, float delta)
            {
                if (delta <= 0f)
                {
                    return;
                }

                float alpha = (_tau > 0f)
                    ? 1f - (float)Math.Exp(-delta / _tau)
                    : 1f;

                _v += alpha * (velocity - _v);
            }
        }

        public class Smoother
        {
            private Vector2? _smoothedPosition;
            private Vector2? _displayPosition;

            // NOTE (mristin):
            // Velocity of the smoothed position in normalized units per second,
            // used to glide the display ahead between the detections.
            private Vector2 _velocity = Vector2.Zero;

            private double _lastObservationTime = double.NaN;
            private float _alpha = 0.0f;
            private CircularBuffer<TimestampedPosition> _positionHistory = (
                new CircularBuffer<TimestampedPosition>(5)
            );

            // NOTE (mristin):
            // We decay alpha by this amount per second.
            private const float _alphaDecayRate = 0.7f;

            // NOTE (mristin):
            // How long the hand stays fully visible after its last detection.
            private const double _holdSeconds = 0.3;

            // NOTE (mristin):
            // This determines the smoothing factor of the detections
            // (0 = instant, 1 = no movement). The detector is precise enough that
            // a light smoothing suffices, and every bit of smoothing adds lag.
            private const float _smoothingFactor = 0.15f;

            // NOTE (mristin):
            // The detections come only a few times per second and a moment after
            // the camera took the picture. Between them, the display glides
            // towards where the hand is heading, at most this far ahead.
            private const double _maxExtrapolationSeconds = 0.1;

            // NOTE (mristin):
            // The time constant of the gliding display; small, so that it follows
            // closely, but large enough to hide the steps between detections.
            private const float _displayTau = 0.05f;

            private readonly InertialVelocity _inertialVelocity = new InertialVelocity();

            /// <summary>Observe the hand in the picture taken at <paramref name="captureTime"/>.</summary>
            public void Observe(Vector2 position, double captureTime)
            {
                if (_smoothedPosition.HasValue && !double.IsNaN(_lastObservationTime))
                {
                    var previous = _smoothedPosition.Value;
                    var smoothed = previous.Lerp(position, 1.0f - _smoothingFactor);
                    double dt = captureTime - _lastObservationTime;
                    if (dt > 1e-3 && dt < 0.5)
                    {
                        _velocity = _velocity.Lerp((smoothed - previous) / (float)dt, 0.6f);
                    }
                    else
                    {
                        _velocity = Vector2.Zero;
                    }

                    _smoothedPosition = smoothed;
                }
                else
                {
                    // NOTE (mristin):
                    // If this is the first observation, we set it directly.
                    _smoothedPosition = position;
                    _velocity = Vector2.Zero;
                }

                _lastObservationTime = captureTime;
                _alpha = 1.0f;

                _positionHistory.Add(
                    new TimestampedPosition(_smoothedPosition.Value, (float)captureTime)
                );
            }

            /// <summary>Advance the smoother by a frame, with or without an observation.</summary>
            public void Update(double now, float delta)
            {
                if (_smoothedPosition.HasValue && now - _lastObservationTime >= _holdSeconds)
                {
                    _alpha = Math.Max(0.0f, _alpha - _alphaDecayRate * delta);

                    // NOTE (mristin):
                    // If alpha reaches 0, we can clear the position.
                    if (_alpha <= 0.0f)
                    {
                        _smoothedPosition = null;
                        _displayPosition = null;
                        _velocity = Vector2.Zero;
                        _lastObservationTime = double.NaN;
                        _positionHistory.Clear();
                    }
                }

                _inertialVelocity.Update(EstimateVerticalSpeed() ?? 0.0f, delta);

                if (_smoothedPosition.HasValue)
                {
                    float ahead = (float)Math.Clamp(
                        now - _lastObservationTime, 0.0, _maxExtrapolationSeconds
                    );
                    var target = _smoothedPosition.Value + _velocity * ahead;
                    _displayPosition = _displayPosition.HasValue
                        ? _displayPosition.Value.Lerp(
                            target, 1.0f - (float)Math.Exp(-delta / _displayTau)
                        )
                        : target;
                }
            }

            /// <summary>Get the gliding display position, its visibility and the vertical speed.</summary>
            public (Vector2? position, float alpha, float verticalSpeed) Get()
            {
                return (_displayPosition, _alpha, _inertialVelocity.Get());
            }

            /// <summary>
            /// Estimate vertical speed for rowing simulation based on position history.
            /// </summary>
            /// <returns>
            /// Vertical speed in pixels per second, or null if insufficient data.
            /// </returns>
            public float? EstimateVerticalSpeed()
            {
                if (_positionHistory.Count < 2)
                {
                    return null;
                }

                float totalVerticalDisplacement = 0f;
                float totalTime = 0f;

                for (int i = 1; i < _positionHistory.Count; i++)
                {
                    var previous = _positionHistory[i - 1];
                    var current = _positionHistory[i];

                    float timeDelta = current.Time - previous.Time;
                    if (timeDelta > 0f)
                    {
                        totalVerticalDisplacement += Math.Abs(
                            current.Position.Y - previous.Position.Y
                        );
                        totalTime += timeDelta;
                    }
                }

                return totalTime > 0f ? totalVerticalDisplacement / totalTime : 0f;
            }
        }

        /// <summary>
        /// Track hand positions over a period of time and emit a symbol if the pose is
        /// consistent.
        /// </summary>
        public class SymbolTracker
        {
            public delegate void SymbolEventHandler(
                string symbol
            );

            // If there are enough observations, the symbol candidate will be set.
            public string? Symbol = null;
            public float? Dominance = null;

            private CircularBuffer<TimestampedSymbol> _observations = (
                // NOTE (mristin):
                // We assume here 120 FPS * 4 seconds.
                new CircularBuffer<TimestampedSymbol>(120 * 4)
            );
            private float _currentTime = 0.0f;

            private const float _minObservationThreshold = 1.0f; // in seconds

            private const float _observationThreshold = 3.0f;  // in seconds

            public SymbolEventHandler? OnSymbolDetected;

            public SymbolTracker(
                SymbolEventHandler? symbolHandler = null
            )
            {
                OnSymbolDetected = symbolHandler;
            }

            private bool _running = false;

            public void Start()
            {
                _running = true;
                _observations.Clear();
            }

            public void Stop()
            {
                _running = false;
                _observations.Clear();
            }

            public void Update(float? leftHand, float? rightHand, float delta)
            {
                _currentTime += delta;

                Symbol = null;
                Dominance = null;

                if (!_running)
                {
                    return;
                }

                // NOTE (mristin):
                // We reset observations if the last observation is too old.
                if (_observations.Count > 0)
                {
                    var lastObservation = _observations[_observations.Count - 1];
                    if (_currentTime - lastObservation.Time > _observationThreshold)
                    {
                        _observations.Clear();
                    }
                }

                if (!leftHand.HasValue || !rightHand.HasValue)
                {
                    return;
                }

                string newSymbol = RecognizeSymbol(leftHand.Value, rightHand.Value);

                _observations.Add(new TimestampedSymbol(_currentTime, newSymbol));

                var firstObservation = _observations[0];
                if (_currentTime - firstObservation.Time >= _minObservationThreshold)
                {
                    var histo = new Dictionary<string, int>();
                    var count = 0;

                    bool observedLongEnoughForEmission = false;

                    for (int i = _observations.Count - 1; i >= 0; i--)
                    {
                        var observation = _observations[i];
                        if (_currentTime - observation.Time > _observationThreshold)
                        {
                            observedLongEnoughForEmission = true;
                            break;
                        }

                        histo[observation.Symbol] = (
                            histo.GetValueOrDefault(observation.Symbol, 0) + 1
                        );
                        count++;
                    }

                    string? bestSymbol = null;
                    int bestCount = 0;

                    foreach (var kvp in histo)
                    {
                        if (kvp.Value > bestCount)
                        {
                            bestSymbol = kvp.Key;
                            bestCount = kvp.Value;
                        }
                    }

                    if (bestSymbol == null)
                    {
                        throw new InvalidOperationException(
                            "Unexpected bestSymbol not set when the histo not be empty"
                        );
                    }

                    float dominance = (float)bestCount / (float)count;

                    this.Symbol = bestSymbol;
                    this.Dominance = dominance;

                    if (observedLongEnoughForEmission && dominance >= 0.9f)
                    {
                        OnSymbolDetected?.Invoke(bestSymbol);
                        _observations.Clear();
                    }
                }
            }

            private string RecognizeSymbol(float leftHand, float rightHand)
            {
                if (leftHand > 0.7f && rightHand > 0.7f)
                {
                    return ErgoSkiing.Symbol.A;
                }

                if (leftHand < 0.3f && rightHand < 0.3f)
                {
                    return ErgoSkiing.Symbol.Y;
                }

                if (leftHand < 0.3f && rightHand > 0.7f)
                {
                    return ErgoSkiing.Symbol.N;
                }

                if (
                    leftHand >= 0.4f && leftHand <= 0.6f
                    && rightHand >= 0.4f && rightHand <= 0.6f
                )
                {
                    return ErgoSkiing.Symbol.T;
                }

                if (leftHand < 0.3f && rightHand >= 0.4f && rightHand <= 0.6f)
                {
                    return ErgoSkiing.Symbol.L;
                }

                if (leftHand > 0.7f && rightHand < 0.3f)
                {
                    return ErgoSkiing.Symbol.K;
                }

                // No recognized symbol
                return ErgoSkiing.Symbol.EMPTY;
            }
        }

    }  // namespace Impl

}  // namespace ErgoSkiing

public partial class ErgoSki : Node2D
{
    /// <summary>Signal that the player moved the hand.</summary>
    /// <remarks>
    /// <para>The position lives roughly in [0, 1].</para>
    ///
    /// <para>
    /// If the position is not available, it is given as NaN.
    /// </para>
    /// </remarks>
    [Signal]
    public delegate void PlayerPositionUpdatedEventHandler(
        string player,
        string hand,
        float normalizedPosition
    );

    /// <summary>Signal that the player's speed changed.</summary>
    /// <remarks>
    /// <para>The speed lives roughly in [0, 1].</para>
    ///
    /// <para>
    /// If the hand could not be detected, speed is set to 0.0f.
    /// </para>
    /// </remarks>
    [Signal]
    public delegate void PlayerSpeedUpdatedEventHandler(
        string player,
        string hand,
        float normalizedSpeed
    );

    [Signal]
    public delegate void PlayerSymbolEmittedEventHandler(
        string player,
        string symbol
    );

    private CameraFeed? _cameraFeed = null;

    private Label? _status;
    private CameraTexture? _cameraTexture;
    // NOTE (mristin):
    // The inference thread asks for a frame and waits for it. The main thread
    // copies a camera frame only when asked, so that we never copy frames which
    // nobody processes, and the frames never queue up (which adds latency).
    // This follows steppe-rescue's VisionService.
    private volatile bool _frameRequested = false;
    private readonly System.Threading.AutoResetEvent _frameReady = new(false);
    private TextureRect? _cameraPort;

    private readonly object _latestFrameLock = new object();
    private Image? _latestFrame;
    private double _latestFrameTime;

    // NOTE (mristin):
    // The clock of the capture times and the smoothers.
    private readonly System.Diagnostics.Stopwatch _clock = System.Diagnostics.Stopwatch.StartNew();

    private bool _inferenceRunning = false;
    private System.Threading.Thread? _inferenceThread;
    private ErgoSkiing.Impl.HandDetector? _handDetector;
    private readonly object _latestInferenceLock = new object();
    private ErgoSkiing.Impl.Inference? _latestInference;


    private PackedScene? _fireballScene;
    private Fireball _playerAFireballLeft = null!;
    private Fireball _playerAFireballRight = null!;
    private Fireball _playerBFireballLeft = null!;
    private Fireball _playerBFireballRight = null!;

    private ErgoSkiing.Impl.Smoother _playerALeftSmoother = (
        new ErgoSkiing.Impl.Smoother()
    );
    private ErgoSkiing.Impl.Smoother _playerARightSmoother = (
        new ErgoSkiing.Impl.Smoother()
    );
    private ErgoSkiing.Impl.Smoother _playerBLeftSmoother = (
        new ErgoSkiing.Impl.Smoother()
    );
    private ErgoSkiing.Impl.Smoother _playerBRightSmoother = (
        new ErgoSkiing.Impl.Smoother()
    );

    private readonly Dictionary<
        (string player, string hand),
        float?
    > _lastEmittedPositions = (
        new Dictionary<(string, string), float?>()
    );

    private readonly Dictionary<
        (string player, string hand),
        float
    > _lastEmittedSpeeds = (
        new Dictionary<(string, string), float>()
    );

    private ErgoSkiing.Impl.SymbolTracker _playerASymbolTracker = null!;
    private ErgoSkiing.Impl.SymbolTracker _playerBSymbolTracker = null!;

    private Label _playerASymbolLabel = null!;
    private Label _playerBSymbolLabel = null!;

    public void StartTrackingSymbols()
    {
        _playerASymbolTracker.Start();
        _playerBSymbolTracker.Start();
    }

    public void StopTrackingSymbols()
    {
        _playerASymbolTracker.Stop();
        _playerBSymbolTracker.Stop();
    }

    public void SetCameraFeed(CameraFeed cameraFeed)
    {
        _cameraFeed = cameraFeed;
    }

    // NOTE (mristin):
    // Read by the inference thread, hence volatile.
    private volatile int _playerCount = 2;

    /// <summary>
    /// Set how many players play: 1 (the whole picture belongs to player A)
    /// or 2 (the left half is player A, the right half is player B).
    /// </summary>
    public void SetPlayerCount(int count)
    {
        _playerCount = Math.Clamp(count, 1, 2);
        if (IsInsideTree())
        {
            UpdateFrame();
        }
    }

    public int GetPlayerCount() => _playerCount;

    /// <summary>Show the split in the frame of the camera picture only for two players.</summary>
    private void UpdateFrame()
    {
        var material = GetNode<ColorRect>("Panel/Frame").Material as ShaderMaterial;
        material?.SetShaderParameter("split", _playerCount == 2);
    }

    private long _inferenceCount = 0;

    /// <summary>How many camera pictures were searched for hands so far (for measuring the speed).</summary>
    public long GetInferenceCount() => System.Threading.Interlocked.Read(ref _inferenceCount);

    public override void _Ready()
    {
        UpdateFrame();

        _status = GetNode<Label>("Panel/Status");
        _status.Text = "Setting up...";

        _fireballScene = GD.Load<PackedScene>(
            $"res://scenes/ergo_meter/ergo_ski/fireball/fireball.tscn"
        );

        var coreColor = new Color(1.0f, 0.6f, 2.0f, 1.0f);
        var playerAColor = new Color(1.0f, 0.0f, 0.0f, 1.0f);
        var playerBColor = new Color(0.0f, 0.0f, 1.0f, 1.0f);

        _playerAFireballLeft = _fireballScene.Instantiate<Fireball>();
        _playerAFireballLeft.Visible = false;
        _playerAFireballLeft.SetColors(
            coreColor,
            playerAColor
        );
        AddChild(_playerAFireballLeft);

        _playerAFireballRight = _fireballScene.Instantiate<Fireball>();
        _playerAFireballRight.Visible = false;
        _playerAFireballRight.SetColors(
            coreColor,
            playerAColor
        );
        AddChild(_playerAFireballRight);

        _playerBFireballLeft = _fireballScene.Instantiate<Fireball>();
        _playerBFireballLeft.Visible = false;
        _playerBFireballLeft.SetColors(
            coreColor,
            playerBColor
        );
        AddChild(_playerBFireballLeft);

        _playerBFireballRight = _fireballScene.Instantiate<Fireball>();
        _playerBFireballRight.Visible = false;
        _playerBFireballRight.SetColors(
            coreColor,
            playerBColor
        );
        AddChild(_playerBFireballRight);

        _playerASymbolLabel = GetNode<Label>("SymbolA");
        _playerBSymbolLabel = GetNode<Label>("SymbolB");

        _playerASymbolTracker = new ErgoSkiing.Impl.SymbolTracker(
            symbol => EmitSignal(
                SignalName.PlayerSymbolEmitted,
                ErgoSkiing.Player.A,
                symbol
            )
        );
        _playerBSymbolTracker = new ErgoSkiing.Impl.SymbolTracker(
            symbol => EmitSignal(
                SignalName.PlayerSymbolEmitted,
                ErgoSkiing.Player.B,
                symbol
            )
        );

        // We postpone the setting up of the model loading so that the scene can
        // initialize properly first.
        GetNode<Timer>("SetUpTimer").Timeout += OnSetUpTimerTimeout;
        GetNode<Timer>("SetUpTimer").Start();

        GD.Print("_Ready done.");
    }

    private void OnSetUpTimerTimeout()
    {
        GD.Print("SetUpTimer timed out.");

        if (_cameraFeed == null)
        {
            throw new InvalidOperationException(
                "Camera feed must be set before ErgoSki is ready. " +
                "Call SetCameraFeed() first."
            );
        }

        _cameraTexture = new CameraTexture
        {
            CameraFeedId = _cameraFeed.GetId(),
            CameraIsActive = true
        };

        // NOTE (mristin):
        // We show the camera texture directly, mirrored on the GPU, instead of
        // resizing, flipping and uploading every frame on the CPU.
        _cameraPort = GetNode<TextureRect>("Panel/CameraPort");
        _cameraPort!.Texture = _cameraTexture;
        _cameraPort.FlipH = true;
        _cameraPort.ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize;
        _cameraPort.StretchMode = TextureRect.StretchModeEnum.Scale;

        _cameraFeed.FrameChanged += OnFrameChanged;

        GD.Print("Starting the inference thread...");
        {
            _inferenceRunning = true;
            _inferenceThread = new System.Threading.Thread(InferenceLoop)
            {
                IsBackground = true,
                Name = "ErgoSkiInference",
            };
            _inferenceThread.Start();
            GD.Print("Inference thread started.");
        }

    }

    public override void _ExitTree()
    {
        _inferenceRunning = false;
        _frameReady.Set();
        if (_cameraFeed != null)
        {
            _cameraFeed.FrameChanged -= OnFrameChanged;
        }

        if (_inferenceThread != null)
        {
            _inferenceThread.Join();
            _inferenceThread = null;
        }

        _handDetector?.Dispose();
        _handDetector = null;
    }

    private void OnFrameChanged()
    {
        if (!_frameRequested)
        {
            return;
        }

        Image? image = _cameraTexture!.GetImage();
        if (image == null || image.IsEmpty())
        {
            return;
        }

        if (image.GetFormat() != Image.Format.Rgb8)
        {
            image.Convert(Image.Format.Rgb8);
        }

        lock (_latestFrameLock)
        {
            _latestFrame = image;
            _latestFrameTime = _clock.Elapsed.TotalSeconds;
        }

        _frameRequested = false;
        _frameReady.Set();
    }

    private void InferenceLoop()
    {
        GD.Print("Creating the hand detector ...");
        {
            string path = "res://scenes/ergo_meter/ergo_ski/model/yolox/yolox_n_body_head_hand_Nx3xHxW.onnx";

            if (!FileAccess.FileExists(path))
            {
                GD.PushError($"File not found: {path}");
                return;
            }

            using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
            if (file == null)
            {
                GD.PushError($"Failed to open file: {path}");
                return;
            }

            byte[] data = file.GetBuffer((long)file.GetLength());
            GD.Print($"Loaded ONNX file, size: {data.Length / 1024.0 / 1024.0:F2} Mb");

            // NOTE (mristin):
            // We leave one core to the game, as in steppe-rescue; the defaults of
            // ONNX Runtime spin a thread on every core and starve the game.
            _handDetector = new ErgoSkiing.Impl.HandDetector(
                data,
                threads: Math.Clamp(System.Environment.ProcessorCount - 1, 1, 4)
            );

            GD.Print("Hand detector created.");
        }

        // NOTE (mristin):
        // Godot does not allow changes in the trees from the other threads, so we have
        // to defer a call.
        Callable.From(() => { _status!.Visible = false; }).CallDeferred();

        GD.Print("Inference loop started.");
        while (_inferenceRunning)
        {
            _frameRequested = true;
            if (!_frameReady.WaitOne(500) || !_inferenceRunning)
            {
                continue;
            }

            Image? frame = null;
            double frameTime = 0.0;
            lock (_latestFrameLock)
            {
                frame = _latestFrame;
                frameTime = _latestFrameTime;
                _latestFrame = null;
            }

            if (frame == null || _handDetector == null)
            {
                continue;
            }

            var playerHands = _handDetector.Detect(
                frame.GetData(), frame.GetWidth(), frame.GetHeight(), _playerCount
            );

            var inference = new ErgoSkiing.Impl.Inference(playerHands, frameTime);
            System.Threading.Interlocked.Increment(ref _inferenceCount);
            lock (_latestInferenceLock)
            {
                _latestInference = inference;
            }

        }

        GD.Print("Left inference loop.");
    }

    public override void _Process(double delta)
    {
        ErgoSkiing.Impl.Inference? inference = null;

        lock (_latestInferenceLock)
        {
            if (_latestInference != null)
            {
                inference = _latestInference;
                _latestInference = null;
            }
        }

        Vector2? playerALeftPosition = null;
        Vector2? playerARightPosition = null;

        Vector2? playerBLeftPosition = null;
        Vector2? playerBRightPosition = null;

        if (inference != null)
        {
            playerALeftPosition = inference.PlayerHands.A?.Left;
            playerARightPosition = inference.PlayerHands.A?.Right;
            playerBLeftPosition = inference.PlayerHands.B?.Left;
            playerBRightPosition = inference.PlayerHands.B?.Right;
        }

        foreach (
            var (
                handPosition,
                smoother,
                fireball,
                player,
                hand
            ) in new (Vector2?, ErgoSkiing.Impl.Smoother, Fireball, string, string)[]
            {
                (
                    playerALeftPosition,
                    _playerALeftSmoother,
                    _playerAFireballLeft,
                    ErgoSkiing.Player.A,
                    ErgoSkiing.Hand.Left
                ),
                (
                    playerARightPosition,
                    _playerARightSmoother,
                    _playerAFireballRight,
                    ErgoSkiing.Player.A,
                    ErgoSkiing.Hand.Right
                ),
                (
                    playerBLeftPosition,
                    _playerBLeftSmoother,
                    _playerBFireballLeft,
                    ErgoSkiing.Player.B,
                    ErgoSkiing.Hand.Left
                ),
                (
                    playerBRightPosition,
                    _playerBRightSmoother,
                    _playerBFireballRight,
                    ErgoSkiing.Player.B,
                    ErgoSkiing.Hand.Right
                )
            }
        )
        {
            if (handPosition.HasValue)
            {
                smoother.Observe(handPosition.Value, inference!.CaptureTime);
            }

            smoother.Update(_clock.Elapsed.TotalSeconds, (float)delta);

            var (smoothedPosition, alpha, speed) = smoother.Get();

            if (smoothedPosition.HasValue)
            {
                var cameraPortSize = _cameraPort!.Size;

                var position = new Vector2(
                    _cameraPort!.Position.X
                        + smoothedPosition.Value.X * cameraPortSize.X,
                    _cameraPort!.Position.Y
                        + smoothedPosition.Value.Y * cameraPortSize.Y
                );

                if (!fireball.Visible)
                {
                    fireball.Position = position;
                    fireball.ResetTrail();
                    fireball.Visible = true;
                }
                else
                {
                    fireball.Move(position - fireball.Position);
                }
                fireball.Modulate = new Color(1.0f, 1.0f, 1.0f, alpha);

                fireball.UpdateWithSpeed(speed);
            }
            else
            {
                fireball.Visible = false;
            }

            var key = (player, hand);

            float? normalizedPosition = (smoothedPosition == null)
                ? null
                // NOTE (mristin):
                // We invert since the smoothed position lives in the image coordinates
                // which start from the top-left corner.
                : 1.0f - smoothedPosition.Value.Y;

            if (
                !_lastEmittedPositions.TryGetValue(key, out var lastPosition)
                || (lastPosition != null) ^ (normalizedPosition != null)
                || (
                    lastPosition != null
                    && normalizedPosition != null
                    && Mathf.Abs(lastPosition.Value - normalizedPosition.Value) > 0.001f
                )
            )
            {
                _lastEmittedPositions[key] = normalizedPosition;
                EmitSignal(
                    SignalName.PlayerPositionUpdated,
                    player,
                    hand,
                    normalizedPosition ?? float.NaN
                );
            }

            if (
                !_lastEmittedSpeeds.TryGetValue(key, out var lastSpeed)
                || Math.Abs(lastSpeed - speed) > 0.001f
            )
            {
                _lastEmittedSpeeds[key] = speed;
                EmitSignal(
                    SignalName.PlayerSpeedUpdated,
                    player,
                    hand,
                    speed
                );
            }
        }

        foreach (
            var (
                leftSmoother,
                rightSmoother,
                tracker,
                symbolLabel
            ) in new (
                ErgoSkiing.Impl.Smoother,
                ErgoSkiing.Impl.Smoother,
                ErgoSkiing.Impl.SymbolTracker,
                Label
            )[]
            {
                (
                    _playerALeftSmoother,
                    _playerARightSmoother,
                    _playerASymbolTracker,
                    _playerASymbolLabel
                ),
                (
                    _playerBLeftSmoother,
                    _playerBRightSmoother,
                    _playerBSymbolTracker,
                    _playerBSymbolLabel
                )
            }
        )
        {
            var leftY = leftSmoother.Get().position?.Y;
            var rightY = rightSmoother.Get().position?.Y;

            tracker.Update(leftY, rightY, (float)delta);

            if (tracker.Symbol != null && tracker.Dominance.HasValue)
            {
                symbolLabel.Text = tracker.Symbol;
                symbolLabel.Modulate = new Color(
                    1.0f, 1.0f, 1.0f, tracker.Dominance.Value
                );
                symbolLabel.Visible = true;
            }
            else
            {
                symbolLabel.Text = "";
                symbolLabel.Modulate = new Color(1.0f, 1.0f, 1.0f, 0.0f);
                symbolLabel.Visible = false;
            }
        }
    }
}
