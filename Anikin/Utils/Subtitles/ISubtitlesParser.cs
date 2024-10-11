using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Anikin.Utils.Subtitles;

/// <summary>
/// Interface specifying the required method for a SubParser.
/// </summary>
public interface ISubtitlesParser
{
    /// <summary>
    /// Parses a subtitles file stream in a list of SubtitleItem
    /// </summary>
    /// <param name="stream">The subtitles file stream to parse</param>
    /// <param name="encoding">The stream encoding (if known)</param>
    /// <returns>The corresponding list of SubtitleItems</returns>
    List<SubtitleItem> ParseStream(Stream stream, Encoding encoding);
}
