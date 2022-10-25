using System.Collections.Generic;
using Android.Content;
using AniStream.Utils;

namespace AniStream.BroadcastReceivers;

public class NetworkStateReceiver : BroadcastReceiver
{
    protected List<INetworkStateReceiverListener> listeners = new();
    protected bool? connected;

    public NetworkStateReceiver()
    {
    }

    public override void OnReceive(Context? context, Intent? intent)
    {
        if (intent is null || intent.Extras is null)
            return;

        connected = WeebUtils.HasNetworkConnection(context!);

        NotifyStateToAll();
    }

    private void NotifyStateToAll()
    {
        foreach (INetworkStateReceiverListener listener in listeners)
            NotifyState(listener);
    }

    private void NotifyState(INetworkStateReceiverListener listener)
    {
        if (connected is null || listener is null)
            return;

        if (connected == true)
            listener.NetworkAvailable();
        else
            listener.NetworkUnavailable();
    }

    public void AddListener(INetworkStateReceiverListener listener)
    {
        listeners.Add(listener);
        NotifyState(listener);
    }

    public void RemoveListener(INetworkStateReceiverListener listener)
    {
        listeners.Remove(listener);
    }
}