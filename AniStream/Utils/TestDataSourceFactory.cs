using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Views;
using Android.Widget;
using Com.Google.Android.Exoplayer2.Upstream;

namespace AniStream.Utils
{
    public class TestDataSourceFactory : Java.Lang.Object, IDataSourceFactory
    {
        ByteArrayDataSource byteArrayDataSource;

        public TestDataSourceFactory()
        {

        }

        public TestDataSourceFactory(ByteArrayDataSource b)
        {
            byteArrayDataSource = b;
        }

        public IDataSource CreateDataSource()
        {
            return byteArrayDataSource;
        }
    }
}