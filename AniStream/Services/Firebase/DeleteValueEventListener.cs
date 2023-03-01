using Firebase.Database;

namespace AniStream.Services.Firebase;

public class DeleteValueEventListener : Java.Lang.Object, IValueEventListener
{
    public void OnCancelled(DatabaseError error)
    {
    }

    public void OnDataChange(DataSnapshot snapshot)
    {
        snapshot.Child("").Ref.RemoveValue();
    }
}