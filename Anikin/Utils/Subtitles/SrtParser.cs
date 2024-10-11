using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace Anikin.Utils.Subtitles;

/// <summary>
/// Parser for the .srt subtitles files
///
/// A .srt file looks like:
/// 1
/// 00:00:10,500 --> 00:00:13,000
/// Elephant's Dream
///
/// 2
/// 00:00:15,000 --> 00:00:18,000
/// At the left we can see...[12]
/// </summary>
public class SrtParser : ISubtitlesParser
{
    private readonly string[] _delimiters = ["-->", "- >", "->"];

    public SrtParser() { }

    public List<SubtitleItem> ParseStream(Stream srtStream, Encoding encoding)
    {
        // test if stream if readable and seekable (just a check, should be good)
        if (!srtStream.CanRead || !srtStream.CanSeek)
        {
            var message = string.Format(
                "Stream must be seekable and readable in a subtitles parser. "
                    + "Operation interrupted; isSeekable: {0} - isReadable: {1}",
                srtStream.CanSeek,
                srtStream.CanSeek
            );
            throw new ArgumentException(message);
        }

        // seek the beginning of the stream
        srtStream.Position = 0;

        var reader = new StreamReader(srtStream, encoding, true);

        var items = new List<SubtitleItem>();
        var srtSubParts = GetSrtSubTitleParts(reader).ToList();
        if (srtSubParts.Count == 0)
        {
            throw new FormatException("Parsing as srt returned no srt part.");
        }

        foreach (var srtSubPart in srtSubParts)
        {
            var lines = srtSubPart
                .Split(new string[] { Environment.NewLine }, StringSplitOptions.None)
                .Select(s => s.Trim())
                .Where(l => !string.IsNullOrEmpty(l))
                .ToList();

            var item = new SubtitleItem();
            foreach (var line in lines)
            {
                if (item.StartTime == 0 && item.EndTime == 0)
                {
                    // we look for the timecodes first
                    var success = TryParseTimecodeLine(line, out var startTc, out var endTc);
                    if (success)
                    {
                        item.StartTime = startTc;
                        item.EndTime = endTc;
                    }
                }
                else
                {
                    // we found the timecode, now we get the text
                    item.Lines.Add(line);
                    // strip formatting by removing anything within curly braces or angle brackets, which is how SRT styles text according to wikipedia (https://en.wikipedia.org/wiki/SubRip#Formatting)
                    item.PlaintextLines.Add(Regex.Replace(line, @"\{.*?\}|<.*?>", string.Empty));
                }
            }

            if ((item.StartTime != 0 || item.EndTime != 0) && item.Lines.Count > 0)
            {
                // parsing succeeded
                items.Add(item);
            }
        }

        if (items.Count == 0)
        {
            throw new ArgumentException("Stream is not in a valid Srt format");
        }

        return items;
    }

    /// <summary>
    /// Enumerates the subtitle parts in a srt file based on the standard line break observed between them.
    /// A srt subtitle part is in the form:
    ///
    /// 1
    /// 00:00:20,000 --> 00:00:24,400
    /// Altocumulus clouds occur between six thousand
    ///
    /// </summary>
    /// <param name="reader">The textreader associated with the srt file</param>
    /// <returns>An IEnumerable(string) object containing all the subtitle parts</returns>
    private IEnumerable<string> GetSrtSubTitleParts(TextReader reader)
    {
        string? line;
        var sb = new StringBuilder();

        while ((line = reader.ReadLine()) != null)
        {
            if (string.IsNullOrEmpty(line.Trim()))
            {
                // return only if not empty
                var res = sb.ToString().TrimEnd();
                if (!string.IsNullOrEmpty(res))
                {
                    yield return res;
                }
                sb = new StringBuilder();
            }
            else
            {
                sb.AppendLine(line);
            }
        }

        if (sb.Length > 0)
        {
            yield return sb.ToString();
        }
    }

    private bool TryParseTimecodeLine(string line, out int startTc, out int endTc)
    {
        var parts = line.Split(_delimiters, StringSplitOptions.None);
        if (parts.Length != 2)
        {
            // this is not a timecode line
            startTc = -1;
            endTc = -1;
            return false;
        }
        else
        {
            startTc = ParseSrtTimecode(parts[0]);
            endTc = ParseSrtTimecode(parts[1]);
            return true;
        }
    }

    /// <summary>
    /// Takes an SRT timecode as a string and parses it into a double (in seconds). A SRT timecode reads as follows:
    /// 00:00:20,000
    /// </summary>
    /// <param name="s">The timecode to parse</param>
    /// <returns>The parsed timecode as a TimeSpan instance. If the parsing was unsuccessful, -1 is returned (subtitles should never show)</returns>
    private static int ParseSrtTimecode(string s)
    {
        var match = Regex.Match(s, "[0-9]+:[0-9]+:[0-9]+([,\\.][0-9]+)?");
        if (match.Success)
        {
            s = match.Value;
            if (TimeSpan.TryParse(s.Replace(',', '.'), out var result))
            {
                var nbOfMs = (int)result.TotalMilliseconds;
                return nbOfMs;
            }
        }
        return -1;
    }
}
