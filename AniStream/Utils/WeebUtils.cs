using System.IO;
using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Net;
using Android.OS;
using Android.Views;
using Android.Widget;
using AnimeDl.Scrapers;
using Java.Net;
using Xamarin.Essentials;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;

namespace AniStream.Utils
{
    public static class WeebUtils
    {
        public static AnimeSites AnimeSite { get; set; } = AnimeSites.GogoAnime;

        public static bool IsDubSelected { get; set; } = false;

        public static CookieManager DEFAULT_COOKIE_MANAGER 
        { 
            get 
            {
                var cm = new CookieManager();
                //cm.SetCookiePolicy(CookiePolicy.AcceptOriginalServer);
                cm.SetCookiePolicy(CookiePolicy.AcceptAll);
                return cm;
            } 
        }

        public static string PersonalDatabaseFolder
        {
            get
            {
                string pathToMyFolder = System.Environment.GetFolderPath(
                    System.Environment.SpecialFolder.Personal) + "/user/database";

                if (!Directory.Exists(pathToMyFolder))
                    Directory.CreateDirectory(pathToMyFolder);

                return pathToMyFolder;
            }
        }

        public static string AppFolder
        {
            get
            {
                //Java.IO.File jFolder;
                //
                //if (Android.OS.Build.VERSION.SdkInt >= BuildVersionCodes.Q)
                //{
                //    jFolder = new Java.IO.File(Android.App.Application.Context.GetExternalFilesDir(Android.OS.Environment.DirectoryDcim), "Test1");
                //}
                //else
                //{
                //    jFolder = new Java.IO.File(Android.OS.Environment.GetExternalStoragePublicDirectory(Android.OS.Environment.DirectoryDcim), "Test1");
                //}
                //
                //if (!jFolder.Exists())
                //    jFolder.Mkdirs();

                //string pathToMyFolder = MainActivity.AppFolder + "/" + AppFolderName;
                string pathToMyFolder = System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.Personal), AppFolderName);
                //if (!Directory.Exists(pathToMyFolder))
                //{
                //    Directory.CreateDirectory(pathToMyFolder);
                //}

                return pathToMyFolder;
            }
        }

        public static string AppFolderName { get; set; }

        public static void CopyToClipboard(Activity activity,
            string text, bool toast = true)
        {
            var clipboard = (ClipboardManager)activity.GetSystemService(Context.ClipboardService);
            var clip = ClipData.NewPlainText("label", text);
            clipboard.PrimaryClip = clip;
            if (toast)
                Toast.MakeText(activity, $"Copied \"{text}\"", ToastLength.Short).Show();
        }

        public static AlertDialog SetProgressDialog(Context context, string text, bool cancelable)
        {
            int llPadding = 20;
            var ll = new LinearLayout(context);
            ll.Orientation = Orientation.Horizontal;
            ll.SetPadding(llPadding, llPadding, llPadding, llPadding);
            ll.SetGravity(GravityFlags.Center);
            var llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent);
            llParam.Gravity = GravityFlags.Center;
            ll.LayoutParameters = llParam;

            var progressBar = new ProgressBar(context);
            progressBar.Indeterminate = true;
            progressBar.SetPadding(0, 0, llPadding, 0);
            progressBar.LayoutParameters = llParam;

            llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent, ViewGroup.LayoutParams.WrapContent);
            llParam.Gravity = GravityFlags.Center;

            var tvText = new TextView(context);
            tvText.Text = text;
            tvText.SetTextColor(Color.ParseColor("#ffffff"));
            tvText.TextSize = 18;
            tvText.LayoutParameters = llParam;
            tvText.Id = 12345;

            ll.AddView(progressBar);
            ll.AddView(tvText);

            var builder = new AlertDialog.Builder(context);
            builder.SetCancelable(cancelable);
            builder.SetView(ll);

            AlertDialog dialog = builder.Create();
            dialog.Show();

            Window window = dialog.Window;
            if (window != null)
            {
                //IWindowManager windowManager = this.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();

                var layoutParams = new WindowManagerLayoutParams();
                layoutParams.CopyFrom(dialog.Window.Attributes);
                layoutParams.Width = ViewGroup.LayoutParams.WrapContent;
                layoutParams.Height = ViewGroup.LayoutParams.WrapContent;
                dialog.Window.Attributes = layoutParams;
            }

            return dialog;
        }

        public static bool HasNetworkConnection(Context context)
        {
            ConnectivityManager connectivityManager = (ConnectivityManager)context.GetSystemService(Context.ConnectivityService);
            if (Build.VERSION.SdkInt >= BuildVersionCodes.M)
            {
                Network nw = connectivityManager.ActiveNetwork;
                
                if (nw == null) return false;

                NetworkCapabilities actNw = connectivityManager.GetNetworkCapabilities(nw);
                //return actNw != null && (actNw.HasTransport(Android.Net.TransportType.Wifi) || actNw.HasTransport(Android.Net.TransportType.Cellular) || actNw.HasTransport(Android.Net.TransportType.Ethernet) || actNw.HasTransport(Android.Net.TransportType.Bluetooth));
                return actNw != null && (actNw.HasTransport(Android.Net.TransportType.Wifi) || actNw.HasTransport(Android.Net.TransportType.Cellular));
            }
            else
            {
                NetworkInfo nwInfo = connectivityManager.ActiveNetworkInfo;
                return nwInfo != null && nwInfo.IsConnected;
            }

            //bool haveConnectedWifi = false;
            //bool haveConnectedMobile = false;
            //
            //ConnectivityManager cm = (ConnectivityManager)context.GetSystemService(Context.ConnectivityService);
            //NetworkInfo[] netInfo = cm.GetAllNetworkInfo();
            //foreach (NetworkInfo ni in netInfo)
            //{
            //    if (ni.TypeName.ToLower().Equals("wifi"))
            //        if (ni.IsConnected)
            //            haveConnectedWifi = true;
            //    if (ni.TypeName.ToLower().Equals("mobile"))
            //        if (ni.IsConnected)
            //            haveConnectedMobile = true;
            //}
            //return haveConnectedWifi || haveConnectedMobile;
        }
    }
}