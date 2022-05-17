using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.Net;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using Java.IO;
using Java.Lang;
using Java.Net;

namespace AniStream.Utils
{
    public class UriByteDataHelper
    {
        public Uri getUri(byte[] data)
        {
            try
            {
                //URL url = new URL(null, "bytes:///" + "audio", new BytesHandler(data));
                URL url = new URL(null, "bytes:///" + "video", new BytesHandler(data));
                return Uri.Parse(url.ToURI().ToString());
            }
            catch (MalformedURLException e)
            {
                throw new RuntimeException(e);
            }
            catch (URISyntaxException e)
            {
                throw new RuntimeException(e);
            }
        }

        class BytesHandler : URLStreamHandler 
        {
            byte[] mData;
            public BytesHandler(byte[] data) {
                mData = data;
            }

            protected override URLConnection OpenConnection(URL u)
            {
                return new ByteUrlConnection(u, mData);
            }
        }

        class ByteUrlConnection : URLConnection 
        {
            byte[] mData;
            public ByteUrlConnection(URL url, byte[] data) : base(url)
            {
                mData = data;
            }

            public override void Connect()
            {
                
            }

            public override Stream InputStream { get { return new MemoryStream(mData); } }
        }
    }
}