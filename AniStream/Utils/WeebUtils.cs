using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using AnimeDl;
using Java.IO;
using Java.Net;
using Java.Util.Concurrent;
using Newtonsoft.Json;
using Xamarin.Essentials;
using AlertDialog = AndroidX.AppCompat.App.AlertDialog;

namespace AniStream.Utils
{
    public static class WeebUtils
    {
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
                {
                    Directory.CreateDirectory(pathToMyFolder);
                }

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

        public static int GetUrlFileSize(string url)
        {
            var task = Task.Run(() =>
            {
                try
                {
                    // Build and set timeout values for the request.
                    Java.Net.URLConnection connection = new Java.Net.URL(url).OpenConnection();
                    //Java.Net.URL urlCon = new Java.Net.URL(url);
                    //Java.Net.URLConnection connection = urlCon.OpenConnection();
                    connection.ConnectTimeout = 5000;
                    connection.ReadTimeout = 5000;
                    
                    //var httpURLConnection = (connection as Java.Net.HttpURLConnection);
                    //var test = httpURLConnection as Javax.Net.Ssl.HttpsURLConnection;
                    //
                    //test.SSLSocketFactory = Android.Net.SSLCertificateSocketFactory.GetInsecure(0, null);
                    //test.HostnameVerifier = new Org.Apache.Http.Conn.Ssl.AllowAllHostnameVerifier();

                    //if (connection is HttpsURLConnection) 
                    //{
                    //    HttpsURLConnection httpsConn = (HttpsURLConnection) conn;
                    //    httpsConn.setSSLSocketFactory(SSLCertificateSocketFactory.getInsecure(0, null));
                    //    httpsConn.setHostnameVerifier(new AllowAllHostnameVerifier());
                    //}

                    connection.Connect();

                    int file_size = connection.ContentLength;

                    return file_size;
                }
                catch (Exception e)
                {
                    return 0;
                }
            });

            task.Wait();

            return task.Result;
        }

        public static AlertDialog SetProgressDialog(Context context, string text, bool cancelable)
        {
            int llPadding = 20;
            LinearLayout ll = new LinearLayout(context);
            ll.Orientation = Orientation.Horizontal;
            ll.SetPadding(llPadding, llPadding, llPadding, llPadding);
            ll.SetGravity(GravityFlags.Center);
            LinearLayout.LayoutParams llParam = new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WrapContent,
                    ViewGroup.LayoutParams.WrapContent);
            llParam.Gravity = GravityFlags.Center;
            ll.LayoutParameters = llParam;

            ProgressBar progressBar = new ProgressBar(context);
            progressBar.Indeterminate = true;
            progressBar.SetPadding(0, 0, llPadding, 0);
            progressBar.LayoutParameters = llParam;

            llParam = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WrapContent,
                ViewGroup.LayoutParams.WrapContent);
            llParam.Gravity = GravityFlags.Center;
            TextView tvText = new TextView(context);
            tvText.Text = text;
            tvText.SetTextColor(Color.ParseColor("#ffffff"));
            tvText.TextSize = 18;
            tvText.LayoutParameters = llParam;
            tvText.Id = 12345;

            ll.AddView(progressBar);
            ll.AddView(tvText);

            AlertDialog.Builder builder = new AlertDialog.Builder(context);
            builder.SetCancelable(cancelable);
            builder.SetView(ll);

            AlertDialog dialog = builder.Create();
            dialog.Show();
            Window window = dialog.Window;
            if (window != null)
            {
                //IWindowManager windowManager = this.GetSystemService(Context.WindowService).JavaCast<IWindowManager>();

                WindowManagerLayoutParams layoutParams = new WindowManagerLayoutParams();
                layoutParams.CopyFrom(dialog.Window.Attributes);
                layoutParams.Width = ViewGroup.LayoutParams.WrapContent;
                layoutParams.Height = ViewGroup.LayoutParams.WrapContent;
                dialog.Window.Attributes = layoutParams;
            }

            return dialog;
        }

        public static bool HaveNetworkConnection(Context context)
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

        public static void GetLastUpdatedBkAnimes(Context context)
        {

        }

        public static string GetAssetJsonData(Context context)
        {
            string json = null;
            try
            {
                using (StreamReader sr = new StreamReader(context.Assets.Open("client_secret.json")))
                {
                    json = sr.ReadToEnd();
                }

                //System.IO.Stream input = context.Assets.Open("myJson.json");
                //int size = input.Length;
                //byte[] buffer = new byte[size];
                //input.Read(buffer);
                //input.Close();
                //json = new string(buffer, "UTF-8");
            }
            catch (Exception ex)
            {
                return null;
            }

            return json;
        }
    }

    public static class SubstringExtensions
    {
        /// <summary>
        /// Get string value between [first] a and [last] b.
        /// </summary>
        public static string Between(this string value, string a, string b)
        {
            int posA = value.IndexOf(a);
            int posB = value.LastIndexOf(b);
            if (posA == -1)
            {
                return "";
            }
            if (posB == -1)
            {
                return "";
            }
            int adjustedPosA = posA + a.Length;
            if (adjustedPosA >= posB)
            {
                return "";
            }
            return value.Substring(adjustedPosA, posB - adjustedPosA);
        }

        /// <summary>
        /// Get string value after [first] a.
        /// </summary>
        public static string Before(this string value, string a)
        {
            int posA = value.IndexOf(a);
            if (posA == -1)
            {
                return "";
            }
            return value.Substring(0, posA);
        }

        /// <summary>
        /// Get string value after [last] a.
        /// </summary>
        public static string After(this string value, string a)
        {
            int posA = value.LastIndexOf(a);
            if (posA == -1)
            {
                return "";
            }
            int adjustedPosA = posA + a.Length;
            if (adjustedPosA >= value.Length)
            {
                return "";
            }
            return value.Substring(adjustedPosA);
        }
    }
}