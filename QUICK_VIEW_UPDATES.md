# Quick View Module Updates - sbitCompass Integration

**Date**: 2025-10-24
**Summary**: Integrated sbitCompass display logic into Quick View module

---

## Changes Completed

### 1. **SBIT Results Tab** - Complete Redesign

**Files Modified:**
- [R/modules/quick_view_module.R](R/modules/quick_view_module.R:396-507)

**Changes:**
- Now uses `extract_sbit_tests()` function from table_helpers.R
- Parses SBIT test data using regex from text column (Name, TID, Status)
- Displays in sbitCompass style with three sections:
  1. **Summary Statistics** - Total, Pass, Fail, Degraded counts
  2. **Failed Tests** - Separate table with full messages (if any)
  3. **Degraded Tests** - Separate table with full messages (if any)
  4. **All SBIT Test Results** - Complete table with color-coded statuses

**Display Columns:**
- Failed/Degraded: Test Name, TID, Status, Message, Timestamp
- All Tests: Test Name, TID, Status, Timestamp

**Styling:**
- Color-coded status backgrounds (green=PASS, red=FAIL, yellow=DEGR)
- Bold text for FAIL/DEGR
- Column filters enabled for "All Tests" table
- Page length: 10 for failures/degraded, 25 for all tests

### 2. **Maintenance Log Tab** - Enhanced Display

**Files Modified:**
- [R/modules/quick_view_module.R](R/modules/quick_view_module.R:527-594)

**Changes:**
- Now uses `create_maint_log_table()` helper function when fx column is available
- Shows three columns: Timestamp, Log Entry, Function
- Color-coded by function type:
  - `CS_addMaintLogEnt` - Light blue
  - `bitMaintLogWrite` - Light orange
- Falls back to simple display if fx column not available
- Column filters enabled at top

### 3. **Boot Milestones Tab** - Full Implementation

**Files Modified:**
- [R/modules/quick_view_module.R](R/modules/quick_view_module.R:514-606)

**Files Added:**
- [R/utils/boot_milestones.R](R/utils/boot_milestones.R) - Copied from sbitCompass

**Changes:**
- Implemented complete boot milestone extraction
- Uses `extract_boot_milestones()` function
- Tracks 10 key system initialization events:
  1. RSM Startup
  2. Time Synchronization (TSY)
  3. SCU Communication
  4. DTM Power Up
  5. INS Power Up
  6. Sensor Initialization
  7. SBIT Execution Start
  8. SBIT Completion
  9. System Ready
  10. Mission Start

**Display:**
- Table with columns: Milestone, Timestamp, Value, Status
- Color-coded status (PASS=green, FAIL=red, WARN=yellow)
- No pagination (shows all milestones at once)
- Descriptive header explaining purpose

---

## Files Added/Copied from sbitCompass

### R/utils/table_helpers.R
**Functions:**
- `extract_sbit_tests()` - Parses SBIT section using regex to extract Name, TID, Status
- `create_sbit_datatable()` - Creates styled datatables with consistent formatting
- `create_maint_log_table()` - Specialized table for maintenance log with function coloring
- `create_empty_df()` - Helper for creating empty data frames with correct schema

### R/utils/boot_milestones.R
**Functions:**
- `extract_boot_milestones()` - Main extraction function for boot sequence milestones
- Uses regex patterns to find key events in info_data, maint_log, and sbit_section
- Returns data frame with milestone, timestamp, value, status

---

## Integration Architecture

### Source Loading (quick_view_module.R:26-30)
```r
source("R/utils/log_detection.R", local = TRUE)
source("R/utils/mode_detection.R", local = TRUE)
source("R/utils/table_helpers.R", local = TRUE)
source("R/utils/boot_milestones.R", local = TRUE)
```

### SBIT Results Pattern
```r
# Extract test results
all_tests <- extract_sbit_tests(sbit_section)
failures <- extract_sbit_tests(sbit_section, status_filter = "FAIL", include_message = TRUE)
degraded <- extract_sbit_tests(sbit_section, status_filter = "DEGR", include_message = TRUE)

# Create styled tables
create_sbit_datatable(all_tests, column_names = c(...), page_length = 25)
```

### Boot Milestones Pattern
```r
# Extract milestones
boot_milestones <- extract_boot_milestones(
  file_path,
  info_data,
  maint_log,
  sbit_section
)

# Display with color-coded status
datatable(...) %>%
  formatStyle('status', backgroundColor = styleEqual(...))
```

---

## Benefits of Integration

1. **Consistency** - Quick View now matches sbitCompass display style exactly
2. **Code Reuse** - Leverages proven extraction functions from sbitCompass
3. **Better UX** - Failures/degraded tests prominently displayed at top
4. **Boot Analysis** - Users can now see system initialization performance
5. **Maintainability** - Shared utility functions reduce code duplication

---

## Testing Checklist

- [x] SBIT Results displays with summary statistics
- [x] Failed tests show in separate section with messages
- [x] Degraded tests show in separate section with messages
- [x] All tests table shows with color-coded statuses
- [ ] Maintenance log shows with function color-coding (needs testing)
- [ ] Boot milestones extract and display correctly (needs testing)
- [ ] Works with both MS110 and DB110 logs (needs testing)

---

## Next Steps

1. **Test with actual log files** - Verify all tabs display correctly
2. **Error detection integration** - Add critical error alerts (Phase 2)
3. **Pod Compass mode** - Implement deep comparative analysis (Phase 3-4)

---

**Status**: Ready for testing with actual MS110 and DB110 log files
