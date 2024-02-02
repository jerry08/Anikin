using Anikin.ViewModels.Manga;

namespace Anikin.Views.Manga;

public partial class MangaReaderPage
{
    public MangaReaderPage(MangaReaderViewModel viewModel)
    {
        InitializeComponent();

        BindingContext = viewModel;
    }
}
