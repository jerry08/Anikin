using System;
using System.Threading.Tasks;

namespace Anikin.Services.AlertDialog;

public interface IAlertService
{
    Task ShowAlertAsync(string title, string message, string cancel = "DISMISS");

    Task<bool> ShowConfirmationAsync(
        string title,
        string message,
        string accept = "Yes",
        string cancel = "No"
    );

    void ShowAlert(string title, string message, string cancel = "DISMISS");

    /// <summary>
    /// Shows confirmation
    /// </summary>
    /// <param name="title"></param>
    /// <param name="message"></param>
    /// <param name="callback">Action to perform afterwards.</param>
    /// <param name="accept"></param>
    /// <param name="cancel"></param>
    void ShowConfirmation(
        string title,
        string message,
        Action<bool> callback,
        string accept = "Yes",
        string cancel = "No"
    );
}
