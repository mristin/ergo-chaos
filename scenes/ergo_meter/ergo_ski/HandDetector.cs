#nullable enable

using System;
using System.Collections.Generic;
using System.Linq;

using Godot;

using Microsoft.ML.OnnxRuntime;

namespace ErgoSkiing.Impl
{
    /// <summary>Hold a detected box (in normalized, mirrored coordinates) with its score.</summary>
    public readonly struct HandDetection
    {
        public readonly float X0;
        public readonly float Y0;
        public readonly float X1;
        public readonly float Y1;
        public readonly float Score;

        public HandDetection(float x0, float y0, float x1, float y1, float score)
        {
            X0 = x0;
            Y0 = y0;
            X1 = x1;
            Y1 = y1;
            Score = score;
        }

        public float CenterX => (X0 + X1) * 0.5f;
        public float CenterY => (Y0 + Y1) * 0.5f;

        public float IntersectionOverUnion(HandDetection other)
        {
            float ix = Math.Max(0f, Math.Min(X1, other.X1) - Math.Max(X0, other.X0));
            float iy = Math.Max(0f, Math.Min(Y1, other.Y1) - Math.Max(Y0, other.Y0));
            float intersection = ix * iy;
            float union = (X1 - X0) * (Y1 - Y0) + (other.X1 - other.X0) * (other.Y1 - other.Y0) - intersection;
            return union > 0f ? intersection / union : 0f;
        }
    }

    /// <summary>
    /// Find the hands of one or two players with YOLOX-Body-Head-Hand (nano).
    /// </summary>
    /// <remarks>
    /// <para>
    /// We only need the hands, and YOLOX-nano is fast enough on a laptop CPU to
    /// find them about ten times per second, which gives a good estimate of the
    /// arm speed.
    /// The pre- and post-processing follow steppe-rescue's YoloxHeadDetector.
    /// </para>
    /// <para>See: https://github.com/PINTO0309/PINTO_model_zoo/tree/main/426_YOLOX-Body-Head-Hand</para>
    /// <para>
    /// The model has no post-processing. Its output has a row per anchor point
    /// (strides 8, 16 and 32, row-major) with
    /// <c>(cx, cy, w, h, objectness, p(body), p(head), p(hand))</c>; the box is
    /// relative to the grid and the sigmoid is already applied to the scores. The
    /// frame sits in the top-left corner of the input, padded with 114.
    /// </para>
    /// <para>
    /// The model does not tell the left hand from the right one, but it finds
    /// the heads, too. The arms of a skier swing on their own side of the body,
    /// so a hand belongs to the nearest head and is the left hand if it is left
    /// of that head. Faces mistaken for hands are dropped, as they overlap a
    /// head. All the coordinates are mirrored, as the players see themselves on
    /// the screen.
    /// </para>
    /// <para>The instance is not thread-safe; use it from a single thread only.</para>
    /// </remarks>
    public sealed class HandDetector : IDisposable
    {
        private const int _classBody = 0;
        private const int _classHead = 1;
        private const int _classHand = 2;
        private const int _rowLength = 8;
        private const float _padValue = 114f;
        private static readonly int[] _strides = { 8, 16, 32 };

        /// <summary>The hands are small, so we are more lenient than with the bodies.</summary>
        public float HandScoreThreshold = 0.4f;

        /// <summary>
        /// A hand overlapping a head this much is most likely the face mistaken
        /// for a hand (or a hand in front of the face, which does not swing).
        /// </summary>
        public float HandHeadOverlapThreshold = 0.3f;

        public float HeadScoreThreshold = 0.5f;

        public float BodyScoreThreshold = 0.5f;
        public float NmsIouThreshold = 0.45f;

        public readonly int InputWidth;
        public readonly int InputHeight;

        private readonly InferenceSession _session;
        private readonly RunOptions _runOptions = new();
        private readonly string[] _inputNames;
        private readonly string[] _outputNames;
        private readonly float[] _input;
        private readonly OrtValue _inputValue;

        private readonly List<HandDetection> _handCandidates = new();
        private readonly List<HandDetection> _bodyCandidates = new();
        private readonly List<HandDetection> _headCandidates = new();
        private readonly List<HandDetection> _heads = new();
        private readonly List<HandDetection> _unclaimedHands = new();
        private readonly List<HandDetection> _hands = new();
        private readonly List<HandDetection> _bodies = new();

        /// <param name="model">The bytes of the ONNX model.</param>
        /// <param name="inputWidth">Multiple of 32; 384x288 fits the 4:3 camera exactly and
        /// keeps the hands of the players a couple of meters away large enough.</param>
        /// <param name="threads">The intra-op threads of ONNX Runtime.</param>
        public HandDetector(byte[] model, int inputWidth = 384, int inputHeight = 288, int threads = 2)
        {
            if (inputWidth <= 0 || inputHeight <= 0 || inputWidth % 32 != 0 || inputHeight % 32 != 0)
            {
                throw new ArgumentException(
                    $"The YOLOX input size must be positive multiples of 32, got {inputWidth}x{inputHeight}."
                );
            }

            using var options = new SessionOptions
            {
                GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
                LogSeverityLevel = OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
                ExecutionMode = ExecutionMode.ORT_SEQUENTIAL,
                IntraOpNumThreads = threads,
                InterOpNumThreads = 1,
            };

            // NOTE (mristin):
            // Spinning threads burn the CPU which the game needs for rendering.
            options.AddSessionConfigEntry("session.intra_op.allow_spinning", "0");

            _session = new InferenceSession(model, options);
            try
            {
                if (_session.InputMetadata.Count != 1 || _session.OutputMetadata.Count != 1)
                {
                    throw new InvalidOperationException(
                        "Expected YOLOX without post-processing to have one input and one output, " +
                        $"but got {_session.InputMetadata.Count} and {_session.OutputMetadata.Count}."
                    );
                }

                var input = _session.InputMetadata.First();
                int[] dimensions = input.Value.Dimensions;
                if (dimensions.Length != 4 || dimensions[1] != 3)
                {
                    throw new InvalidOperationException(
                        $"Expected the YOLOX input of shape [N, 3, H, W], but got [{string.Join(", ", dimensions)}]."
                    );
                }

                // NOTE (mristin):
                // A fixed-shape model dictates the input size.
                if (dimensions[2] > 0 && dimensions[3] > 0)
                {
                    inputHeight = dimensions[2];
                    inputWidth = dimensions[3];
                }

                _inputNames = new[] { input.Key };
                _outputNames = new[] { _session.OutputMetadata.Keys.First() };
                InputWidth = inputWidth;
                InputHeight = inputHeight;
                _input = new float[3 * inputWidth * inputHeight];

                // NOTE (mristin):
                // The OrtValue pins our buffer, so we only refill it for every frame.
                _inputValue = OrtValue.CreateTensorValueFromMemory(
                    _input, new long[] { 1, 3, inputHeight, inputWidth }
                );
            }
            catch
            {
                _session.Dispose();
                throw;
            }
        }

        /// <summary>
        /// Find the hands of the players in the RGB8 frame (not mirrored) and give
        /// them to the players.
        /// </summary>
        public PlayerHands Detect(byte[] rgb, int width, int height, int playerCount)
        {
            float scale = Preprocess(rgb, width, height);

            using var outputs = _session.Run(_runOptions, _inputNames, new[] { _inputValue }, _outputNames);
            var output = outputs[0].GetTensorDataAsSpan<float>();

            _handCandidates.Clear();
            _bodyCandidates.Clear();
            _headCandidates.Clear();
            Decode(output, scale, width, height);
            Suppress(_handCandidates, 8, _hands);
            Suppress(_bodyCandidates, 4, _bodies);
            Suppress(_headCandidates, 4, _heads);

            _hands.RemoveAll(hand => _heads.Any(
                head => hand.IntersectionOverUnion(head) > HandHeadOverlapThreshold
                    || (hand.CenterX > head.X0 && hand.CenterX < head.X1
                        && hand.CenterY > head.Y0 && hand.CenterY < head.Y1)
            ));

            // NOTE (mristin):
            // The heads anchor the players: a hand belongs to the nearest head,
            // and it is the left hand if it is left of that head. Without a head,
            // we fall back to the halves of the picture.
            if (playerCount <= 1)
            {
                // The largest head is the closest person, i.e., the player rather
                // than somebody passing by in the back.
                HandDetection? head = null;
                foreach (var candidate in _heads)
                {
                    if (head == null || Area(candidate) > Area(head.Value))
                    {
                        head = candidate;
                    }
                }

                return new PlayerHands(
                    head != null ? HandsOfHead(head.Value, null) : HandsOf(_hands, 0f, 1f),
                    null
                );
            }

            var headA = BestHead(0f, 0.5f);
            var headB = BestHead(0.5f, 1f);

            // NOTE (mristin):
            // A player without a visible head falls back to the hands in their
            // half of the picture, but never takes the hands within the reach of
            // the other player's head. Otherwise a single player standing in
            // the middle would count as two.
            _unclaimedHands.Clear();
            foreach (var hand in _hands)
            {
                if (!(headA != null && WithinReach(headA.Value, hand))
                    && !(headB != null && WithinReach(headB.Value, hand)))
                {
                    _unclaimedHands.Add(hand);
                }
            }

            return new PlayerHands(
                headA != null ? HandsOfHead(headA.Value, headB) : HandsOf(_unclaimedHands, 0f, 0.5f),
                headB != null ? HandsOfHead(headB.Value, headA) : HandsOf(_unclaimedHands, 0.5f, 1f)
            );
        }

        /// <summary>Tell whether the hand is within the reach of the arms of the head.</summary>
        private static bool WithinReach(HandDetection head, HandDetection hand)
        {
            // NOTE (mristin):
            // The reach is measured in head sizes, so that it works both near to
            // and far from the camera. The arms of a skier swing from above the
            // head down to the hips.
            float headWidth = head.X1 - head.X0;
            float headHeight = head.Y1 - head.Y0;
            float reachX = Math.Max(4.5f * headWidth, 0.06f);
            float dx = hand.CenterX - head.CenterX;
            float dy = hand.CenterY - head.CenterY;
            return Math.Abs(dx) <= reachX && dy >= -3.5f * headHeight && dy <= 7f * headHeight;
        }

        private static float Area(HandDetection box) => (box.X1 - box.X0) * (box.Y1 - box.Y0);

        /// <summary>Find the best-scoring head with the center in [from, to).</summary>
        private HandDetection? BestHead(float from, float to)
        {
            foreach (var head in _heads)  // sorted by score
            {
                if (head.CenterX >= from && head.CenterX < to)
                {
                    return head;
                }
            }

            return null;
        }

        /// <summary>
        /// Find the best hand on each side of the head, among the hands
        /// within the reach of the arms and closer to this head than to the other.
        /// </summary>
        private Hands? HandsOfHead(HandDetection head, HandDetection? otherHead)
        {
            HandDetection? left = null;
            HandDetection? right = null;
            foreach (var hand in _hands)  // sorted by score
            {
                if (!WithinReach(head, hand))
                {
                    continue;
                }

                float dx = hand.CenterX - head.CenterX;

                if (otherHead != null && Math.Abs(hand.CenterX - otherHead.Value.CenterX) < Math.Abs(dx))
                {
                    continue;
                }

                if (dx < 0f)
                {
                    left ??= hand;
                }
                else
                {
                    right ??= hand;
                }
            }

            if (left == null && right == null)
            {
                return null;
            }

            return MakeHands(left, right);
        }

        /// <summary>
        /// Find the (at most) two best hands with the center in [from, to).
        /// </summary>
        private Hands? HandsOf(List<HandDetection> hands, float from, float to)
        {
            HandDetection? first = null;
            HandDetection? second = null;
            foreach (var hand in hands)  // sorted by score
            {
                if (hand.CenterX < from || hand.CenterX >= to)
                {
                    continue;
                }

                if (first == null)
                {
                    first = hand;
                }
                else
                {
                    second = hand;
                    break;
                }
            }

            if (first == null)
            {
                return null;
            }

            HandDetection? left;
            HandDetection? right;
            if (second != null)
            {
                bool firstIsLeft = first.Value.CenterX <= second.Value.CenterX;
                left = firstIsLeft ? first : second;
                right = firstIsLeft ? second : first;
            }
            else
            {
                // NOTE (mristin):
                // With a single hand, the body tells on which side it is; without
                // the body, we take the middle of the player's part of the picture.
                float middle = (from + to) * 0.5f;
                foreach (var body in _bodies)
                {
                    if (body.CenterX >= from && body.CenterX < to)
                    {
                        middle = body.CenterX;
                        break;
                    }
                }

                bool isLeft = first.Value.CenterX < middle;
                left = isLeft ? first : null;
                right = isLeft ? null : first;
            }

            return MakeHands(left, right);
        }

        /// <summary>Turn the detected boxes into the hand positions.</summary>
        private static Hands MakeHands(HandDetection? left, HandDetection? right)
        {
            return new Hands(
                left.HasValue ? new Vector2(left.Value.CenterX, left.Value.CenterY) : null,
                right.HasValue ? new Vector2(right.Value.CenterX, right.Value.CenterY) : null
            );
        }

        /// <summary>
        /// Fit the RGB8 frame into the top-left corner of the planar BGR float input
        /// of the model, in [0, 255], and return the scale.
        /// </summary>
        private float Preprocess(byte[] rgb, int width, int height)
        {
            int inputWidth = InputWidth;
            int inputHeight = InputHeight;
            float[] target = _input;
            int plane = inputWidth * inputHeight;

            float scale = Math.Min((float)inputWidth / width, (float)inputHeight / height);
            float inverse = 1f / scale;
            float contentWidth = width * scale;
            float contentHeight = height * scale;

            // NOTE (mristin):
            // We sample at the pixel centers (like cv2.resize) and pre-compute the
            // columns once, since this runs for every frame.
            Span<int> xs0 = stackalloc int[inputWidth];
            Span<int> xs1 = stackalloc int[inputWidth];
            Span<float> fxs = stackalloc float[inputWidth];
            for (int x = 0; x < inputWidth; x++)
            {
                float sx = Math.Clamp((x + 0.5f) * inverse - 0.5f, 0f, width - 1);
                int x0 = (int)sx;
                xs0[x] = x0 * 3;
                xs1[x] = Math.Min(x0 + 1, width - 1) * 3;
                fxs[x] = sx - x0;
            }

            for (int y = 0; y < inputHeight; y++)
            {
                bool insideY = y + 0.5f < contentHeight;
                float sy = Math.Clamp((y + 0.5f) * inverse - 0.5f, 0f, height - 1);
                int y0 = (int)sy;
                int y1 = Math.Min(y0 + 1, height - 1);
                float fy = sy - y0;
                int row0 = y0 * width * 3;
                int row1 = y1 * width * 3;

                for (int x = 0; x < inputWidth; x++)
                {
                    int index = y * inputWidth + x;
                    if (!insideY || x + 0.5f >= contentWidth)
                    {
                        target[index] = _padValue;
                        target[plane + index] = _padValue;
                        target[2 * plane + index] = _padValue;
                        continue;
                    }

                    float fx = fxs[x];
                    for (int c = 0; c < 3; c++)
                    {
                        float p00 = rgb[row0 + xs0[x] + c];
                        float p01 = rgb[row0 + xs1[x] + c];
                        float p10 = rgb[row1 + xs0[x] + c];
                        float p11 = rgb[row1 + xs1[x] + c];
                        float p0 = p00 + (p01 - p00) * fx;
                        float p1 = p10 + (p11 - p10) * fx;

                        // NOTE (mristin):
                        // The model was trained on images loaded with OpenCV, so it
                        // expects the BGR order: R goes to the last plane.
                        target[(2 - c) * plane + index] = p0 + (p1 - p0) * fy;
                    }
                }
            }

            return scale;
        }

        /// <summary>
        /// Decode the hands, the heads and the bodies into normalized, mirrored boxes, before
        /// the non-maximum suppression.
        /// </summary>
        private void Decode(ReadOnlySpan<float> output, float scale, int frameWidth, int frameHeight)
        {
            int anchors = 0;
            foreach (int stride in _strides)
            {
                anchors += (InputWidth / stride) * (InputHeight / stride);
            }

            if (output.Length != anchors * _rowLength)
            {
                throw new ArgumentException(
                    $"Expected the YOLOX output of {anchors * _rowLength} values for the input " +
                    $"{InputWidth}x{InputHeight}, but got {output.Length}."
                );
            }

            float inverse = 1f / scale;
            int row = 0;
            foreach (int stride in _strides)
            {
                int gridWidth = InputWidth / stride;
                int gridHeight = InputHeight / stride;
                for (int gy = 0; gy < gridHeight; gy++)
                {
                    for (int gx = 0; gx < gridWidth; gx++, row++)
                    {
                        int offset = row * _rowLength;
                        float objectness = output[offset + 4];
                        float handScore = objectness * output[offset + 5 + _classHand];
                        float bodyScore = objectness * output[offset + 5 + _classBody];
                        float headScore = objectness * output[offset + 5 + _classHead];

                        List<HandDetection>? candidates = null;
                        float score = 0f;
                        if (handScore >= HandScoreThreshold)
                        {
                            candidates = _handCandidates;
                            score = handScore;
                        }
                        else if (headScore >= HeadScoreThreshold)
                        {
                            candidates = _headCandidates;
                            score = headScore;
                        }
                        else if (bodyScore >= BodyScoreThreshold)
                        {
                            candidates = _bodyCandidates;
                            score = bodyScore;
                        }

                        if (candidates == null)
                        {
                            continue;
                        }

                        float cx = (output[offset] + gx) * stride * inverse;
                        float cy = (output[offset + 1] + gy) * stride * inverse;
                        float w = MathF.Exp(output[offset + 2]) * stride * inverse;
                        float h = MathF.Exp(output[offset + 3]) * stride * inverse;

                        // Normalize and mirror.
                        float x0 = 1f - Math.Clamp(cx + w * 0.5f, 0f, frameWidth) / frameWidth;
                        float x1 = 1f - Math.Clamp(cx - w * 0.5f, 0f, frameWidth) / frameWidth;
                        float y0 = Math.Clamp(cy - h * 0.5f, 0f, frameHeight) / frameHeight;
                        float y1 = Math.Clamp(cy + h * 0.5f, 0f, frameHeight) / frameHeight;
                        if (x1 > x0 && y1 > y0)
                        {
                            candidates.Add(new HandDetection(x0, y0, x1, y1, score));
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Greedily keep the best-scoring detections and drop the ones that overlap
        /// them too much. The candidates are sorted in place.
        /// </summary>
        private void Suppress(List<HandDetection> candidates, int maxCount, List<HandDetection> kept)
        {
            kept.Clear();
            candidates.Sort((a, b) => b.Score.CompareTo(a.Score));
            foreach (var candidate in candidates)
            {
                if (kept.Count >= maxCount)
                {
                    break;
                }

                bool overlaps = false;
                foreach (var other in kept)
                {
                    if (candidate.IntersectionOverUnion(other) > NmsIouThreshold)
                    {
                        overlaps = true;
                        break;
                    }
                }

                if (!overlaps)
                {
                    kept.Add(candidate);
                }
            }
        }

        public void Dispose()
        {
            _inputValue.Dispose();
            _runOptions.Dispose();
            _session.Dispose();
        }
    }
}  // namespace ErgoSkiing.Impl
