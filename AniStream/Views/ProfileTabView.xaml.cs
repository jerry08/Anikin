namespace AniStream.Views;

public partial class ProfileTabView
{
    public ProfileTabView()
    {
        InitializeComponent();

        //return;
        //
        ////BindingContext = new ProfileViewModel();
        //
        //var clientID = "14733";
        //
        ////var test1 = webView.Cookies.GetAllCookies();
        //
        //if (webView.Cookies is null)
        //    webView.Cookies = new CookieContainer();
        //
        ////webView.Source = "https://anilist.co/";
        //webView.Source = $"https://anilist.co/api/v2/oauth/authorize?client_id={clientID}&response_type=token";
        //
        //webView.Navigated += async (s, e) =>
        //{
        //    var res = e.Result;
        //
        //    return;
        //
        //    var test2 = webView.Cookies?.GetAllCookies();
        //
        //    if (test2?.Count > 0)
        //    {
        //        var cc = new
        //        {
        //            grant_type = "authorization_code",
        //            client_id = "14733",
        //            client_secret = "G8Um8FlEqb1FOxJGsqOMvNVICgkbsN4BQm1JL5cI",
        //
        //        };
        //
        //        var http = new HttpClient();
        //        var request = new HttpRequestMessage(HttpMethod.Post, $"https://anilist.co/api/v2/oauth/authorize?client_id=${clientID}&response_type=token")
        //        {
        //            //Content = new StringContent(JsonSerializer.Serialize(cc))
        //        };
        //
        //        request.Headers.TryAddWithoutValidation("Accept", "application/json");
        //        request.Headers.TryAddWithoutValidation("Content-Type", "application/json");
        //
        //        var response = await http.SendAsync(
        //            request,
        //            HttpCompletionOption.ResponseHeadersRead
        //        );
        //
        //        var tes = await response.Content.ReadAsStringAsync();
        //    }
        //};
    }
}
