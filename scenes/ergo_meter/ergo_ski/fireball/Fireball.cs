using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class Fireball : Node2D
{
    [Export] public Color CoreColor { get; set; } = Colors.White;
    [Export] public Color GlowColor { get; set; } = new Color(1.0f, 0.6f, 0.2f, 1.0f);

    private ShaderMaterial _fireballShader = null!;

    // NOTE (mristin):
    // The trail is a tapered Line2D through the recent positions, painted by a
    // shader (fireball_trail.gdshader). Only a handful of points change per
    // frame and nothing is allocated, so it costs next to no CPU.
    private Line2D _trail = null!;
    private ShaderMaterial _trailShader = null!;

    /// <summary>How far back in time the trail reaches, in seconds.</summary>
    private const double _trailSeconds = 0.28;

    private const int _maxTrailPoints = 24;

    /// <summary>Width of the trail at the fireball, in the fireball's units.</summary>
    private const float _trailWidth = 34.0f;

    // NOTE (mristin):
    // Recent positions in the parent's coordinates with their times, oldest first.
    private readonly Vector2[] _trailPositions = new Vector2[_maxTrailPoints];
    private readonly double[] _trailTimes = new double[_maxTrailPoints];
    private int _trailStart = 0;
    private int _trailCount = 0;

    // NOTE (mristin):
    // One array per point count, so that we do not allocate every frame.
    private readonly Vector2[][] _trailPointArrays = Enumerable
        .Range(0, _maxTrailPoints + 1)
        .Select(n => new Vector2[n])
        .ToArray();

    private static ImageTexture? _whiteTexture;

    public override void _Ready()
    {
        var colorRect = GetNode<ColorRect>("ColorRect");

        var fireballShader = GD.Load<Shader>(
            "res://scenes/ergo_meter/ergo_ski/fireball/fireball.gdshader"
        );
        _fireballShader = new ShaderMaterial();
        _fireballShader.Shader = fireballShader;
        _fireballShader.SetShaderParameter("time_scale", 1.0f);
        _fireballShader.SetShaderParameter("core_color", CoreColor);
        _fireballShader.SetShaderParameter("glow_color", GlowColor);

        colorRect.Material = _fireballShader;

        _trailShader = new ShaderMaterial
        {
            Shader = GD.Load<Shader>(
                "res://scenes/ergo_meter/ergo_ski/fireball/fireball_trail.gdshader"
            )
        };

        var widthCurve = new Curve();
        widthCurve.AddPoint(new Vector2(0.0f, 1.0f));
        widthCurve.AddPoint(new Vector2(0.35f, 0.75f));
        widthCurve.AddPoint(new Vector2(1.0f, 0.08f));

        // NOTE (mristin):
        // The Line2D gives the shader UVs along the line only in the stretch
        // texture mode, which needs a texture; a 1x1 white one suffices.
        if (_whiteTexture == null)
        {
            var image = Image.CreateEmpty(1, 1, false, Image.Format.Rgba8);
            image.Fill(Colors.White);
            _whiteTexture = ImageTexture.CreateFromImage(image);
        }

        _trail = new Line2D
        {
            Width = _trailWidth,
            WidthCurve = widthCurve,
            Texture = _whiteTexture,
            TextureMode = Line2D.LineTextureMode.Stretch,
            JointMode = Line2D.LineJointMode.Round,
            BeginCapMode = Line2D.LineCapMode.Round,
            EndCapMode = Line2D.LineCapMode.None,
            Material = _trailShader,
            Visible = false,
        };

        AddChild(_trail);

        // Move trail behind fireball
        MoveChild(_trail, 0);

        UpdateShaderColors();
    }

    private void UpdateShaderColors()
    {
        if (_fireballShader == null || _trail == null)
        {
            return;
        }

        _fireballShader.SetShaderParameter("core_color", CoreColor);
        _fireballShader.SetShaderParameter("glow_color", GlowColor);

        _trailShader.SetShaderParameter("core_color", CoreColor);
        _trailShader.SetShaderParameter("glow_color", GlowColor);
    }

    public void SetColors(Color coreColor, Color glowColor)
    {
        CoreColor = coreColor;
        GlowColor = glowColor;
        UpdateShaderColors();
    }

    /// <summary>Forget the trail, e.g., when the hand appears again elsewhere.</summary>
    public void ResetTrail()
    {
        _trailStart = 0;
        _trailCount = 0;
        if (_trail != null)
        {
            _trail.Visible = false;
        }
    }

    /// <summary>Move the fireball relative to its previous position.</summary>
    public void Move(Vector2 diff)
    {
        Position += diff;

        double now = Time.GetTicksUsec() / 1e6;

        // NOTE (mristin):
        // We record a point only if the fireball moved a bit, so that the
        // segments do not degenerate, but we always let the old points expire.
        bool moved = _trailCount == 0
            || Position.DistanceSquaredTo(_trailPositions[(_trailStart + _trailCount - 1) % _maxTrailPoints]) > 0.25f;
        if (moved)
        {
            if (_trailCount == _maxTrailPoints)
            {
                _trailStart = (_trailStart + 1) % _maxTrailPoints;
                _trailCount--;
            }

            int index = (_trailStart + _trailCount) % _maxTrailPoints;
            _trailPositions[index] = Position;
            _trailTimes[index] = now;
            _trailCount++;
        }

        while (_trailCount > 0 && now - _trailTimes[_trailStart] > _trailSeconds)
        {
            _trailStart = (_trailStart + 1) % _maxTrailPoints;
            _trailCount--;
        }

        if (_trailCount < 2)
        {
            _trail.Visible = false;
            return;
        }

        // NOTE (mristin):
        // The trail is our child, so it moves and scales with us; its points go
        // from the newest position (about here) back to the oldest one.
        var points = _trailPointArrays[_trailCount];
        float inverseScale = Scale.X > 1e-3f ? 1.0f / Scale.X : 1.0f;
        for (int i = 0; i < _trailCount; i++)
        {
            int index = (_trailStart + _trailCount - 1 - i) % _maxTrailPoints;
            points[i] = (_trailPositions[index] - Position) * inverseScale;
        }

        _trail.Points = points;
        _trail.Visible = true;
    }

    /// <summary>Update fireball with vertical speed for intensity effect.</summary>
    /// <remarks>
    /// The <paramref name="normalizedAbsSpeed" /> is expected to be in [0,1].
    /// </remarks>
    public void UpdateWithSpeed(float? normalizedAbsSpeed)
    {
        if (_fireballShader == null || !normalizedAbsSpeed.HasValue)
        {
            return;
        }

        Scale = Vector2.One * (0.6f + normalizedAbsSpeed.Value * 0.4f);
        _trailShader?.SetShaderParameter("intensity", Math.Clamp(normalizedAbsSpeed.Value, 0f, 1f));
    }
}
