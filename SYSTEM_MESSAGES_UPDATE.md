# System Messages Tab Update

**Date**: 2025-10-24
**Summary**: Updated System Messages tab to match sbitCompass display style

---

## Changes Made

### IRFPA Messages Table

**File Modified**: [R/modules/quick_view_module.R](R/modules/quick_view_module.R:685-775)

**Previous Display:**
- Only 2 columns: Time, Message

**New Display (matching sbitCompass):**
- 4 columns: **Time, Function, Component, Message**
- Column filters enabled at top
- Message column width: 400px
- Red background highlighting for rows with FAIL/Error
- Red text color for highlighted rows

**Column Details:**
- **Time**: Timestamp (formatted as YYYY-MM-DD HH:MM:SS)
- **Function**: `fx` column - Function that generated the message
- **Component**: `sw2` column - Component identifier (e.g., "TirFpa")
- **Message**: `text` column - Full message text

### Power System Messages Table

**File Modified**: [R/modules/quick_view_module.R](R/modules/quick_view_module.R:777-867)

**Previous Display:**
- Only 2 columns: Timestamp, Message

**New Display (matching sbitCompass):**
- 4 columns: **Timestamp, Message, Component, Function**
- Column filters enabled at top
- Message column width: 400px
- Red background highlighting for rows with FAIL/Error
- Red text color for highlighted rows

**Column Details:**
- **Timestamp**: `time2` column (formatted as YYYY-MM-DD HH:MM:SS)
- **Message**: `text` column - Full message text
- **Component**: `sw2` column - Component identifier
- **Function**: `fx` column - Function that generated the message

---

## Styling Details

### Error Highlighting

Both tables now highlight rows containing "FAIL" or "Error" (case-insensitive) in the message text:

```r
formatStyle(
  'text',
  target = 'row',
  backgroundColor = styleEqual(
    unique(grepl('FAIL|Error', display_df$text, ignore.case = TRUE)),
    c('white', '#f8d7da')  # White for normal, light red for errors
  ),
  color = styleEqual(
    unique(grepl('FAIL|Error', display_df$text, ignore.case = TRUE)),
    c('black', '#721c24')  # Black for normal, dark red for errors
  )
)
```

### Table Features

- **Column Filters**: Top filters enabled with `filter = 'top'`
- **Page Length**: 15 rows per page
- **Horizontal Scroll**: Enabled with `scrollX = TRUE`
- **Column Width**: Message column set to 400px for better readability
- **Styling**: Cell border and striped rows with `class = 'cell-border stripe'`

---

## Differences from sbitCompass

### sbitCompass Approach
- Uses **flextable** package for rendering
- HTML output via `htmltools_value(ft)`
- Applied red background and white text to entire rows

### logCompass Approach
- Uses **DT::datatable** for consistency with other tabs
- Row-level conditional formatting via `target = 'row'`
- Applied red background and dark red text to error rows

**Why the difference?**
- DT datatable is already used throughout Quick View
- DT provides built-in interactive features (sorting, filtering, pagination)
- DT integrates better with Shiny reactivity
- Maintains consistency with SBIT Results, Maintenance Log, and Boot Milestones tabs

---

## Testing Checklist

- [ ] IRFPA table shows all 4 columns (Time, Function, Component, Message)
- [ ] Power table shows all 4 columns (Timestamp, Message, Component, Function)
- [ ] Column filters work at the top of both tables
- [ ] Rows with FAIL/Error are highlighted in red
- [ ] Message columns are readable (400px width)
- [ ] Works with both MS110 and DB110 logs

---

## Integration with sbitCompass

These updates complete the System Messages tab integration with sbitCompass style:

1. ✅ **SBIT Results** - Matches sbitCompass (Failed, Degraded, All tests)
2. ✅ **Maintenance Log** - Matches sbitCompass (with function coloring)
3. ✅ **Boot Milestones** - Matches sbitCompass (10 milestones tracked)
4. ✅ **IRFPA Messages** - NOW matches sbitCompass (4 columns + error highlighting)
5. ✅ **Power Messages** - NOW matches sbitCompass (4 columns + error highlighting)

---

**Status**: Ready for testing - all Quick View tabs now match sbitCompass display style
