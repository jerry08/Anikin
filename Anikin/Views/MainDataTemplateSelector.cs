using System;
using Microsoft.Maui.Controls;

namespace Anikin.Views;

public class MainDataTemplateSelector : DataTemplateSelector
{
    public DataTemplate? DataTemplate { get; set; }

    public DataTemplate? WindowsDataTemplate { get; set; }

    protected override DataTemplate? OnSelectTemplate(object item, BindableObject container)
    {
        if (WindowsDataTemplate is not null && OperatingSystem.IsWindows())
            return WindowsDataTemplate;

        return DataTemplate;
    }
}
