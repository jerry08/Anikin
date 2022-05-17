using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.Net;

namespace AniStream.BroadcastReceivers
{
    public class NetworkStateReceiver : BroadcastReceiver
    {
        protected List<INetworkStateReceiverListener> listeners;
        protected bool? connected;

        public NetworkStateReceiver()
        {
            listeners = new List<INetworkStateReceiverListener>();
            connected = null;
        }

        public override void OnReceive(Context context, Intent intent)
        {
            if (intent == null || intent.Extras == null)
                return;

            ConnectivityManager manager = (ConnectivityManager)context.GetSystemService(Context.ConnectivityService);
            NetworkInfo ni = manager.ActiveNetworkInfo;

            if (ni != null && ni.GetState() == NetworkInfo.State.Connected)
            {
                connected = true;
            }
            else if (intent.GetBooleanExtra(ConnectivityManager.ExtraNoConnectivity, false))
            {
                connected = false;
            }

            NotifyStateToAll();
        }

        private void NotifyStateToAll()
        {
            foreach (INetworkStateReceiverListener listener in listeners)
                NotifyState(listener);
        }

        private void NotifyState(INetworkStateReceiverListener listener)
        {
            if (connected == null || listener == null)
                return;

            if (connected == true)
                listener.NetworkAvailable();
            else
                listener.NetworkUnavailable();
        }

        public void AddListener(INetworkStateReceiverListener l)
        {
            listeners.Add(l);
            NotifyState(l);
        }

        public void RemoveListener(INetworkStateReceiverListener l)
        {
            listeners.Remove(l);
        }
    }
}