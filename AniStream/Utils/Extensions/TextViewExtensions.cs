using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Android.App;
using Android.Content;
using Android.OS;
using Android.Runtime;
using Android.Text;
using Android.Text.Method;
using Android.Text.Style;
using Android.Views;
using Android.Widget;

namespace AniStream.Utils.Extensions
{
    public class TextViewExtensions
    {
        public static void MakeTextViewResizable(TextView tv, int maxLine, string expandText, bool viewMore) 
        {
            if (tv.Tag == null) {
                tv.Tag = tv.Text;
            }
            ViewTreeObserver vto = tv.ViewTreeObserver;
            //vto.GlobalLayout += (s, e) =>
            //{
            //    
            //};

            vto.GlobalLayout += Vto_GlobalLayout;

            void Vto_GlobalLayout(object sender, EventArgs e)
            {
                ViewTreeObserver obs = tv.ViewTreeObserver;
                //obs.RemoveGlobalOnLayoutListener(obs);
                vto.GlobalLayout -= Vto_GlobalLayout;
                if (maxLine == 0)
                {
                    int lineEndIndex = tv.Layout.GetLineEnd(0);
                    string text = tv.Text.Substring(0, lineEndIndex - expandText.Length + 1) + " " + expandText;
                    tv.Text = text;
                    tv.MovementMethod = LinkMovementMethod.Instance;
                    tv.SetText(AddClickablePartTextViewResizable(Html.FromHtml(tv.Text.ToString()),
                        tv, maxLine, expandText, viewMore), TextView.BufferType.Spannable);
                }
                else if (maxLine > 0 && tv.LineCount >= maxLine)
                {
                    int lineEndIndex = tv.Layout.GetLineEnd(maxLine - 1);
                    string text = tv.Text.Substring(0, lineEndIndex - expandText.Length + 1) + " " + expandText;
                    tv.Text = text;
                    tv.MovementMethod = LinkMovementMethod.Instance;
                    tv.SetText(AddClickablePartTextViewResizable(Html.FromHtml(tv.Text.ToString()),
                        tv, maxLine, expandText, viewMore), TextView.BufferType.Spannable);
                }
                else
                {
                    int lineEndIndex = tv.Layout.GetLineEnd(tv.Layout.LineCount - 1);
                    string text = tv.Text.Substring(0, lineEndIndex) + " " + expandText;
                    tv.Text = text;
                    tv.MovementMethod = LinkMovementMethod.Instance;
                    tv.SetText(AddClickablePartTextViewResizable(Html.FromHtml(tv.Text.ToString()),
                        tv, lineEndIndex, expandText, viewMore), TextView.BufferType.Spannable);
                }
            }
        }

        static SpannableStringBuilder AddClickablePartTextViewResizable(ISpanned strSpanned, 
            TextView tv, int maxLine, string spanableText, bool viewMore) 
        {
            string str = strSpanned.ToString();
            SpannableStringBuilder ssb = new SpannableStringBuilder(strSpanned);

            if (str.Contains(spanableText))
            {
                MySpannable mySpannable = new MySpannable(false);
                mySpannable.MyClickEvent += (ssb, e) =>
                {
                    if (viewMore)
                    {
                        tv.LayoutParameters = tv.LayoutParameters;
                        tv.SetText(tv.Tag.ToString(), TextView.BufferType.Spannable);
                        tv.Invalidate();
                        MakeTextViewResizable(tv, -1, "See Less", false);
                    }
                    else
                    {
                        tv.LayoutParameters = tv.LayoutParameters;
                        tv.SetText(tv.Tag.ToString(), TextView.BufferType.Spannable);
                        tv.Invalidate();
                        MakeTextViewResizable(tv, 2, ".. See More", true);
                    }
                };

                ssb.SetSpan(mySpannable, str.IndexOf(spanableText), 
                    str.IndexOf(spanableText) + spanableText.Length, 0);
            }

            return ssb;
        }

        public static SpannableStringBuilder MakeSectionOfTextBold(string text, string textToBold)
        {
            SpannableStringBuilder builder = new SpannableStringBuilder();

            if (textToBold.Length > 0 && !textToBold.Trim().Equals(""))
            {
                var cl = new System.Globalization.CultureInfo("en-US");

                //for counting start/end indexes
                string testText = text.ToLower(cl);
                string testTextToBold = textToBold.ToLower(cl);
                int startingIndex = testText.IndexOf(testTextToBold);
                int endingIndex = startingIndex + testTextToBold.Length;
                //for counting start/end indexes

                if (startingIndex < 0 || endingIndex < 0)
                {
                    builder.Append(text);

                    return builder;
                }
                else if (startingIndex >= 0 && endingIndex >= 0)
                {

                    builder.Append(text);
                    builder.SetSpan(new StyleSpan(Android.Graphics.TypefaceStyle.Bold), startingIndex, endingIndex, 0);
                }
            }
            else
            {
                builder.Append(text);

                return builder;
            }

            return builder;
        }
    }
}