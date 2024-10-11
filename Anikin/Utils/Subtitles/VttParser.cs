using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Anikin.Utils.Subtitles;

/// <summary>
/// Parser for the .vtt subtitles files. Does not handle formatting tags within the text; that has to be parsed separately.
///
/// A .vtt file looks like:
/// WEBVTT
///
/// CUE - 1
/// 00:00:10.500 --> 00:00:13.000
/// Elephant's Dream
///
/// CUE - 2
/// 00:00:15.000 --> 00:00:18.000
/// At the left we can see...
/// </summary>
public class VttParser : ISubtitlesParser
{
    private static readonly Regex _rxLongTimestamp = new Regex(
        "(?<H>[0-9]+):(?<M>[0-9]+):(?<S>[0-9]+)[,\\.](?<m>[0-9]+)",
        RegexOptions.Compiled
    );
    private static readonly Regex _rxShortTimestamp = new Regex(
        "(?<M>[0-9]+):(?<S>[0-9]+)[,\\.](?<m>[0-9]+)",
        RegexOptions.Compiled
    );

    private readonly string[] _delimiters = ["-->", "- >", "->"];

    public VttParser() { }

    public List<SubtitleItem> ParseStream(Stream vttStream, Encoding encoding)
    {
        // test if stream if readable and seekable (just a check, should be good)
        if (!vttStream.CanRead || !vttStream.CanSeek)
        {
            var message = string.Format(
                "Stream must be seekable and readable in a subtitles parser. "
                    + "Operation interrupted; isSeekable: {0} - isReadable: {1}",
                vttStream.CanSeek,
                vttStream.CanSeek
            );
            throw new ArgumentException(message);
        }

        // seek the beginning of the stream
        vttStream.Position = 0;

        var reader = new StreamReader(vttStream, encoding, detectEncodingFromByteOrderMarks: true);

        var items = new List<SubtitleItem>();
        var vttSubParts = GetVttSubTitleParts(reader).GetEnumerator();
        if (false == vttSubParts.MoveNext())
        {
            throw new FormatException("Parsing as VTT returned no VTT part.");
        }

        do
        {
            var lines = vttSubParts
                .Current.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)
                .Select(s => s.Trim())
                .Where(l => !string.IsNullOrEmpty(l));

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
                }
            }

            if ((item.StartTime != 0 || item.EndTime != 0) && item.Lines.Any())
            {
                // parsing succeeded
                items.Add(item);
            }
        } while (vttSubParts.MoveNext());

        return items;
    }

    public async Task<List<SubtitleItem>> ParseStreamAsync(Stream vttStream, Encoding encoding)
    {
        // test if stream if readable and seekable (just a check, should be good)
        if (!vttStream.CanRead || !vttStream.CanSeek)
        {
            var message = string.Format(
                "Stream must be seekable and readable in a subtitles parser. "
                    + "Operation interrupted; isSeekable: {0} - isReadable: {1}",
                vttStream.CanSeek,
                vttStream.CanSeek
            );
            throw new ArgumentException(message);
        }

        // seek the beginning of the stream
        vttStream.Position = 0;

        var reader = new StreamReader(vttStream, encoding, detectEncodingFromByteOrderMarks: true);

        var items = new List<SubtitleItem>();
        var vttBlockEnumerator = GetVttSubTitlePartsAsync(reader).GetAsyncEnumerator();
        if (await vttBlockEnumerator.MoveNextAsync() == false)
        {
            throw new FormatException("Parsing as VTT returned no VTT part.");
        }

        do
        {
            var lines = vttBlockEnumerator
                .Current.Split(new string[] { Environment.NewLine }, StringSplitOptions.None)
                .Select(s => s.Trim())
                .Where(l => !string.IsNullOrEmpty(l));

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
                }
            }

            if ((item.StartTime != 0 || item.EndTime != 0) && item.Lines.Any())
            {
                // parsing succeeded
                items.Add(item);
            }
        } while (await vttBlockEnumerator.MoveNextAsync());

        return items;
    }

    /// <summary>
    /// Enumerates the subtitle parts in a VTT file based on the standard line break observed between them.
    /// A VTT subtitle part is in the form:
    ///
    /// CUE - 1
    /// 00:00:20.000 --> 00:00:24.400
    /// Altocumulus clouds occur between six thousand
    ///
    /// The first line is optional, as well as the hours in the time codes.
    /// </summary>
    /// <param name="reader">The textreader associated with the vtt file</param>
    /// <returns>An IEnumerable(string) object containing all the subtitle parts</returns>
    private IEnumerable<string> GetVttSubTitleParts(TextReader reader)
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

    private async IAsyncEnumerable<string> GetVttSubTitlePartsAsync(TextReader reader)
    {
        string? line;
        var sb = new StringBuilder();

        while ((line = await reader.ReadLineAsync()) != null)
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
            startTc = ParseVttTimecode(parts[0]);
            endTc = ParseVttTimecode(parts[1]);
            return true;
        }
    }

    /// <summary>
    /// Takes an VTT timecode as a string and parses it into a double (in seconds). A VTT timecode reads as follows:
    /// 00:00:20.000
    /// or
    /// 00:20.000
    /// </summary>
    /// <param name="s">The timecode to parse</param>
    /// <returns>The parsed timecode as a TimeSpan instance. If the parsing was unsuccessful, -1 is returned (subtitles should never show)</returns>
    private int ParseVttTimecode(string s)
    {
        var hours = 0;
        var minutes = 0;
        var seconds = 0;
        var milliseconds = -1;
        var match = _rxLongTimestamp.Match(s);
        if (match.Success)
        {
            hours = int.Parse(match.Groups["H"].Value);
            minutes = int.Parse(match.Groups["M"].Value);
            seconds = int.Parse(match.Groups["S"].Value);
            milliseconds = int.Parse(match.Groups["m"].Value);
        }
        else
        {
            match = _rxShortTimestamp.Match(s);
            if (match.Success)
            {
                minutes = int.Parse(match.Groups["M"].Value);
                seconds = int.Parse(match.Groups["S"].Value);
                milliseconds = int.Parse(match.Groups["m"].Value);
            }
        }

        if (milliseconds >= 0)
        {
            var result = new TimeSpan(0, hours, minutes, seconds, milliseconds);
            var nbOfMs = (int)result.TotalMilliseconds;
            return nbOfMs;
        }

        return -1;
    }
}
