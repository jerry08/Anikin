using System;
using System.ComponentModel;
using System.Linq.Expressions;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace AniStream.Settings;

public abstract partial class SettingsManager : INotifyPropertyChanged
{
    /// <summary>
    /// Triggered when a settings property has been changed
    /// </summary>
    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// Raises the property changed event for given property
    /// </summary>
    protected virtual void RaisePropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    /// <summary>
    /// Raises the property changed event for given property
    /// </summary>
    protected virtual void RaisePropertyChanged<T>(Expression<Func<T>> propertyExpression)
    {
        if (propertyExpression is null)
            throw new ArgumentNullException(nameof(propertyExpression));

        // Get property name
        var propertyName = ((propertyExpression.Body as MemberExpression)?.Member as PropertyInfo)?.Name;
        if (propertyName is null)
            throw new Exception("Could not get property name from expression");

        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    /// <summary>
    /// Sets a property to its new value and raises an event if necessary
    /// </summary>
    protected virtual bool Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        // If value hasn't been updated - return
        if (Equals(field, value))
            return false;

        // Set new value
        field = value;

        // Raise event
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));

        return true;
    }
}