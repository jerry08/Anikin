namespace AniStream.Settings.Encryption;

/// <summary>
/// Interface for settings data protection
/// </summary>
public interface IDataProtector
{
    /// <summary>
    /// Method to encrypt string
    /// </summary>
    /// <param name="plainText">Contains the unencrypted string</param>
    /// <returns></returns>
    string Protect(string plainText);

    /// <summary>
    /// Method to decrypt string
    /// </summary>
    /// <param name="cipherText">Contains the encrypted string</param>
    /// <returns></returns>
    string Unprotect(string cipherText);
}