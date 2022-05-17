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
using Com.Google.Android.Exoplayer2;
using Com.Google.Android.Exoplayer2.Upstream;
using Java.IO;
using Java.Net;

namespace AniStream.Utils
{
    public class TestDataSource : Java.Lang.Object, IDataSource
    {
        public static int DEFAULT_MAX_PACKET_SIZE = 2000;

        public static int TRANSFER_LISTENER_PACKET_INTERVAL = 1000;

        private ITransferListener TransferListener;
        private DatagramPacket packet;

        private DataSpec dataSpec;
        private MulticastSocket socket;
        private bool opened;

        private int packetsReceived;
        private byte[] packetBuffer;
        private int packetRemaining;

        public Android.Net.Uri Uri => throw new NotImplementedException();

        public void AddTransferListener(ITransferListener transferListener)
        {
            TransferListener = transferListener;
            //throw new NotImplementedException();
        }

        public void Close()
        {
            //throw new NotImplementedException();
        }

        public long Open(DataSpec dataSpec)
        {
            this.dataSpec = dataSpec;
            string uri = dataSpec.Uri.ToString();
            string host = uri.Substring(0, uri.IndexOf(':'));
            int port = Convert.ToInt32(uri.Substring(uri.IndexOf(':') + 1));

            InetAddress addr = InetAddress.GetByName(host);
            InetSocketAddress sockAddr = new InetSocketAddress(addr, port);

            try
            {
                if (addr.IsMulticastAddress)
                {
                    socket = new MulticastSocket(sockAddr);
                    socket.JoinGroup(addr);
                }
                else
                {
                    socket = (MulticastSocket)new DatagramSocket(sockAddr);
                }
            }
            catch (IOException e)
            {
                throw new IOException(e);
            }

            opened = true;
            TransferListener.OnTransferStart(this, dataSpec, true);
            return C.LengthUnset;
        }

        public int Read(byte[] buffer, int offset, int readLength)
        {
            throw new NotImplementedException();
        }
    }
}