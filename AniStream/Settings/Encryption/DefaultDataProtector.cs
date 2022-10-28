using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;

namespace AniStream.Settings.Encryption;

/// <summary>
/// Default Data Protector
/// </summary>
public class DefaultDataProtector : IDataProtector
{
    private readonly string _Key = "2V8BjFU9gtG4ZG6C";

    /// <summary>
    /// Initializes an instance of <see cref="DefaultDataProtector"/>.
    /// </summary>
    public DefaultDataProtector()
    {
    }

    /// <summary>
    /// Initializes an instance of <see cref="DefaultDataProtector"/>.
    /// </summary>
    public DefaultDataProtector(string key)
    {
        _Key = key;
    }

    string IDataProtector.Protect(string plainText)
    {
        var iv = new byte[16];
        byte[] array;

        using (var aes = Aes.Create())
        {
            aes.Key = Encoding.UTF8.GetBytes(_Key);
            aes.IV = iv;

            var encryptor = aes.CreateEncryptor(aes.Key, aes.IV);

            using var memoryStream = new MemoryStream();
            using var cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write);
            using (var streamWriter = new StreamWriter(cryptoStream))
            {
                streamWriter.Write(plainText);
            }

            array = memoryStream.ToArray();
        }

        return Convert.ToBase64String(array);
    }

    string IDataProtector.Unprotect(string cipherText)
    {
        var iv = new byte[16];
        var buffer = Convert.FromBase64String(cipherText);

        using var aes = Aes.Create();
        aes.Key = Encoding.UTF8.GetBytes(_Key);
        aes.IV = iv;

        var decryptor = aes.CreateDecryptor(aes.Key, aes.IV);

        using var memoryStream = new MemoryStream(buffer);
        using var cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read);
        using var streamReader = new StreamReader(cryptoStream);
        return streamReader.ReadToEnd();
    }
}