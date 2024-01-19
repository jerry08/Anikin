﻿using Microsoft.Maui.Controls;

namespace Anikin.Views.Templates;

public partial class AnimeTypeRangeTemplateView
{
    public AnimeTypeRangeTemplateView()
    {
        InitializeComponent();
    }

    protected override void OnBindingContextChanged()
    {
        base.OnBindingContextChanged();

        Scale = 0.4;
        this.ScaleTo(1, 150);
    }
}
