# Raw Log Sentiment Highlighting

**Date**: 2025-10-24
**Feature**: Negative word highlighting in raw log display using Bing Sentiment Lexicon

---

## Overview

The Raw Log tab now includes automatic highlighting of negative sentiment words using the Bing Sentiment Lexicon from the `tidytext` package. This helps users quickly identify problematic or concerning entries in log files.

## How It Works

1. **Lexicon Loading**: When the Raw Log tab is displayed, the module loads the Bing sentiment lexicon via `tidytext::get_sentiments("bing")`

2. **Word Analysis**: Each word in the log file is:
   - Extracted and cleaned (lowercase, punctuation removed)
   - Checked against the negative words list
   - Highlighted if it matches a negative sentiment word

3. **Visual Highlighting**: Negative words are displayed with:
   - **Background color**: `#fff3cd` (light yellow/amber)
   - **Text color**: `#856404` (dark amber/brown)
   - **Font weight**: Bold

## Example Negative Words

The Bing lexicon includes words like:
- error, fail, failure, failed
- bad, wrong, broken, corrupt
- abort, critical, fatal, severe
- degraded, invalid, missing, timeout
- And many more...

## Implementation Details

### Files Modified

- **[R/modules/quick_view_module.R](R/modules/quick_view_module.R)**:
  - Lines 151-154: Changed UI from `verbatimTextOutput` to `uiOutput`
  - Lines 756-818: Complete rewrite of raw log rendering with sentiment analysis

- **[app.R](app.R)**:
  - Lines 26-31: Added `tidytext` and `htmltools` to required packages

### Key Code Components

```r
# Load Bing sentiment lexicon
bing_lexicon <- tidytext::get_sentiments("bing")
bing_negative <- bing_lexicon$word[bing_lexicon$sentiment == "negative"]

# Process each word
word_clean <- tolower(gsub("[^a-z]", "", word))

if (word_clean %in% bing_negative) {
  # Highlight negative words
  paste0('<span style="background-color: #fff3cd; color: #856404; font-weight: bold;">',
         htmltools::htmlEscape(word), '</span>')
}
```

## Fallback Behavior

If the `tidytext` package is not available or the lexicon cannot be loaded:
- The raw log displays normally without highlighting
- No errors are shown to the user
- Graceful degradation ensures functionality

## Performance Considerations

- **Line limit**: Only first 1000 lines are processed to maintain performance
- **Caching**: Lexicon is loaded once per render
- **HTML escaping**: All text is properly escaped to prevent XSS issues

## User Benefits

1. **Quick Problem Identification**: Negative words jump out visually
2. **Error Scanning**: Easily spot error messages and failures
3. **Trend Analysis**: See density of negative words across log sections
4. **Better Readability**: Important issues are visually distinct

## Future Enhancements

Potential improvements:
- Add toggle to enable/disable highlighting
- Support multiple sentiment lexicons (AFINN, NRC)
- Add positive word highlighting (green)
- Custom word lists for aerospace-specific terminology
- Adjustable highlighting colors via settings
- Count/summary of negative words found

---

## Testing

To test the feature:
1. Open any MS110 or DB110 log file in Quick View
2. Navigate to the "Raw Log" tab
3. Look for highlighted words (yellow/amber background)
4. Common highlighted words in aerospace logs:
   - "error", "fail", "abort"
   - "invalid", "timeout", "critical"
   - "degraded", "missing", "corrupt"

---

**Status**: Implemented and ready for testing
