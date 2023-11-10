using Microsoft.Maui.Controls;

namespace Anikin.Views;

public class MainDataTemplateSelector : DataTemplateSelector
{
    public DataTemplate? DataTemplate { get; set; }

    //protected override DataTemplate? OnSelectTemplate(object item, BindableObject container)
    //{
    //    if (item is AnimeInfo)
    //        return DataTemplate;
    //
    //    return null;
    //}

    protected override DataTemplate? OnSelectTemplate(object item, BindableObject container)
    {
        return DataTemplate;
    }
}
