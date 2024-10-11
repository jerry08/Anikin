using System;
using System.Threading.Tasks;
using Microsoft.Maui;
using Microsoft.Maui.Controls;

namespace Anikin.Controls;

/// <summary>
/// <para><see href="https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/gestures/pan"/></para>
/// <para><see href="https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/gestures/pinch"/></para>
/// </summary>
public class PanPinchContainer : ContentView
{
    private readonly TapGestureRecognizer _doubleTapGestureRecognizer;

    private readonly PanGestureRecognizer _panGestureRecognizer;

    private readonly PinchGestureRecognizer _pinchGestureRecognizer;

    private double _currentScale = 1;

    private bool _isPanEnabled = true;

    private double _panX;

    private double _panY;

    private double _startScale = 1;

    public PanPinchContainer()
    {
        _panGestureRecognizer = new PanGestureRecognizer();
        _panGestureRecognizer.PanUpdated += OnPanUpdatedAsync;
        GestureRecognizers.Add(_panGestureRecognizer);

        _pinchGestureRecognizer = new PinchGestureRecognizer();
        _pinchGestureRecognizer.PinchUpdated += OnPinchUpdatedAsync;
        GestureRecognizers.Add(_pinchGestureRecognizer);

        _doubleTapGestureRecognizer = new TapGestureRecognizer { NumberOfTapsRequired = 2 };

        _doubleTapGestureRecognizer.Tapped += DoubleTappedAsync;
        GestureRecognizers.Add(_doubleTapGestureRecognizer);
    }

    protected override void OnChildAdded(Element child)
    {
        base.OnChildAdded(child);

        if (child is View view)
        {
            view.HorizontalOptions = LayoutOptions.Center;
            view.VerticalOptions = LayoutOptions.Center;
        }
    }

    private async Task ClampTranslationAsync(double transX, double transY, bool animate = false)
    {
        Content.AnchorX = 0;
        Content.AnchorY = 0;

        var contentWidth = Content.Width * _currentScale;
        var contentHeight = Content.Height * _currentScale;

        if (contentWidth <= Width)
        {
            transX = -(contentWidth - Content.Width) / 2;
        }
        else
        {
            var minBoundX = ((Width - Content.Width) / 2) + contentWidth - Width;
            var maxBoundX = (Width - Content.Width) / 2;
            transX = Math.Clamp(transX, -minBoundX, -maxBoundX);
        }

        if (contentHeight <= Height)
        {
            transY = -(contentHeight - Content.Height) / 2;
        }
        else
        {
            var minBoundY = ((Height - Content.Height) / 2) + contentHeight - Height;
            var maxBoundY = (Height - Content.Height) / 2;
            transY = Math.Clamp(transY, -minBoundY, -maxBoundY);
        }

        if (animate)
        {
            await TranslateToAsync(transX, transY);
        }
        else
        {
            Content.TranslationX = transX;
            Content.TranslationY = transY;
        }
    }

    private async Task ClampTranslationFromScaleOriginAsync(
        double originX,
        double originY,
        bool animate = false
    )
    {
        // The ScaleOrigin is in relative coordinates to the wrapped user interface element,
        // so get the X pixel coordinate.
        var renderedX = Content.X + _panX;
        var deltaX = renderedX / Width;
        var deltaWidth = Width / (Content.Width * _startScale);
        originX = (originX - deltaX) * deltaWidth;

        // The ScaleOrigin is in relative coordinates to the wrapped user interface element,
        // so get the Y pixel coordinate.
        var renderedY = Content.Y + _panY;
        var deltaY = renderedY / Height;
        var deltaHeight = Height / (Content.Height * _startScale);
        originY = (originY - deltaY) * deltaHeight;

        // Calculate the transformed element pixel coordinates.
        var targetX = _panX - (originX * Content.Width * (_currentScale - _startScale));
        var targetY = _panY - (originY * Content.Height * (_currentScale - _startScale));

        // Apply translation based on the change in origin.
        if (_currentScale > 1)
        {
            targetX = Math.Clamp(targetX, -Content.Width * (_currentScale - 1), 0);
            targetY = Math.Clamp(targetY, -Content.Height * (_currentScale - 1), 0);
        }
        else
        {
            targetX = (Width - (Content.Width * _currentScale)) / 2;
            targetY = Content.Height * (1 - _currentScale) / 2;
        }

        await ClampTranslationAsync(targetX, targetY, animate);
    }

    private async void DoubleTappedAsync(object? sender, TappedEventArgs e)
    {
        _startScale = Content.Scale;
        _currentScale = _startScale;
        _panX = Content.TranslationX;
        _panY = Content.TranslationY;

        if (_currentScale < 2)
        {
            _currentScale = 2;
        }
        else
        {
            _currentScale = 1;
        }

        var point = e.GetPosition(sender as View);

        var translateTask = Task.CompletedTask;

        if (point is not null)
        {
            translateTask = ClampTranslationFromScaleOriginAsync(
                point.Value.X / Width,
                point.Value.Y / Height,
                true
            );
        }

        var scaleTask = ScaleToAsync(_currentScale);

        await Task.WhenAll(translateTask, scaleTask);

        _panX = Content.TranslationX;
        _panY = Content.TranslationY;
    }

    private async void OnPanUpdatedAsync(object? sender, PanUpdatedEventArgs e)
    {
        if (!_isPanEnabled)
        {
            return;
        }

        if (Content.Scale <= 1)
        {
            return;
        }

        if (e.StatusType == GestureStatus.Started)
        {
            _panX = Content.TranslationX;
            _panY = Content.TranslationY;

            Content.AnchorX = 0;
            Content.AnchorY = 0;
        }
        else if (e.StatusType == GestureStatus.Running)
        {
            // Translate and pan.
            await ClampTranslationAsync(_panX + e.TotalX, _panY + e.TotalY);
        }
        else if (e.StatusType == GestureStatus.Completed)
        {
            // Store the translation applied during the pan
            _panX = Content.TranslationX;
            _panY = Content.TranslationY;
        }
        else if (e.StatusType == GestureStatus.Canceled)
        {
            Content.TranslationX = _panX;
            Content.TranslationY = _panX;
        }
    }

    private async void OnPinchUpdatedAsync(object? sender, PinchGestureUpdatedEventArgs e)
    {
        if (e.Status == GestureStatus.Started)
        {
            _isPanEnabled = false;

            _panX = Content.TranslationX;
            _panY = Content.TranslationY;

            // Store the current scale factor applied to the wrapped user interface element,
            // and zero the components for the center point of the translate transform.
            _startScale = Content.Scale;

            Content.AnchorX = 0;
            Content.AnchorY = 0;
        }

        if (e.Status == GestureStatus.Running)
        {
            // Calculate the scale factor to be applied.
            _currentScale += (e.Scale - 1) * _startScale;
            _currentScale = Math.Clamp(_currentScale, 0.5, 10);

            await ClampTranslationFromScaleOriginAsync(e.ScaleOrigin.X, e.ScaleOrigin.Y);

            // Apply scale factor
            Content.Scale = _currentScale;
        }

        if (e.Status == GestureStatus.Completed)
        {
            if (_currentScale < 1)
            {
                var translateTask = TranslateToAsync(0, 0);
                var scaleTask = ScaleToAsync(1);

                await Task.WhenAll(translateTask, scaleTask);
            }

            // Store the translation delta's of the wrapped user interface element.
            _panX = Content.TranslationX;
            _panY = Content.TranslationY;

            _isPanEnabled = true;
        }
        else if (e.Status == GestureStatus.Canceled)
        {
            Content.TranslationX = _panX;
            Content.TranslationY = _panY;
            Content.Scale = _startScale;

            _isPanEnabled = true;
        }
    }

    private async Task ScaleToAsync(double scale)
    {
        await Content.ScaleTo(scale, 250, Easing.Linear);
        _currentScale = scale;
    }

    private async Task TranslateToAsync(double x, double y)
    {
        await Content.TranslateTo(x, y, 250, Easing.Linear);
        _panX = x;
        _panY = y;
    }
}
