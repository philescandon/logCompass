# MS110 Boot Milestones Implementation

**Date**: 2025-10-24
**Summary**: Created MS110-specific boot milestone extraction to replace DB110-focused version

---

## Problem

The original `boot_milestones.R` from sbitCompass was designed specifically for DB110 errorlogs and had two major issues:

1. **DB110-specific patterns**: Used DB110 text patterns like "TR_Low Starting up the RSM"
2. **dplyr syntax**: Used dplyr functions like `filter()` which caused scoping issues with our base R approach

**Error encountered:**
```
Error extracting boot milestones: In argument: `grepl("TR_Low Starting up the RSM", text, ignore.case = TRUE)`.
```

---

## Solution

Created a new MS110-specific boot milestone extraction function that:
- Uses **base R syntax** (no dplyr)
- Searches for **MS110-specific patterns**
- Handles **MS110 log structure** (info_df, sbitSection)
- Falls back gracefully if milestones not found

---

## Files Created/Modified

### New File: R/utils/ms110_boot_milestones.R

**Function**: `extract_ms110_boot_milestones()`

**MS110 Boot Milestones Tracked** (10 total):

1. **System Power-On**
   - First timestamped log entry
   - Marks the beginning of system initialization

2. **ABSW Version Detected**
   - Pattern: `"ABSW|software version"`
   - Identifies the application software version in use

3. **Sensor Initialization**
   - Pattern: `"sensor.*init|initializing.*sensor"`
   - When the sensor pod begins initialization

4. **SBIT Start**
   - First entry in sbitSection
   - Beginning of Built-In Test sequence

5. **SBIT Complete**
   - Last entry in sbitSection
   - End of Built-In Test sequence

6. **Mission Plan Loaded**
   - Pattern: `"mission.*plan|loading.*mission"`
   - Mission configuration loaded

7. **EO Focal Plane Ready**
   - Pattern: `"EO.*focal.*plane|EOFPA"`
   - Electro-Optical sensor ready

8. **IR Focal Plane Ready**
   - Pattern: `"IR.*focal.*plane|IRFPA"`
   - Infrared sensor ready

9. **System Ready**
   - Pattern: `"system.*ready|operational|ready.*for.*mission"`
   - System fully initialized and operational

10. **Mission Start**
    - Pattern: `"mission.*start|start.*mission|beginning.*mission"`
    - Mission execution begins

---

## Implementation Details

### Base R Approach

All pattern matching uses base R with proper vectorization:

```r
# Example: Finding ABSW version
absw_rows <- info_data[!is.na(info_data$text) &
                       grepl("ABSW|software version", info_data$text, ignore.case = TRUE), , drop = FALSE]
```

**Key differences from DB110 version:**
- Uses `info_data[condition, , drop = FALSE]` instead of `filter()`
- Direct column access with `$` operator
- No pipe operators (`%>%`)
- Explicit `!is.na()` checks

### Helper Function

Internal `add_milestone()` function to safely add milestones:

```r
add_milestone <- function(name, data_row, val = NA) {
  if (nrow(data_row) > 0) {
    timestamp <- if ("time2" %in% names(data_row)) {
      data_row$time2[1]
    } else if ("time" %in% names(data_row)) {
      data_row$time[1]
    } else {
      NA
    }

    milestones <<- rbind(milestones, data.frame(
      milestone = name,
      timestamp = timestamp,
      value = ifelse(is.na(val), NA_character_, as.character(val)),
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }
}
```

### Fallback Behavior

If no specific milestones are found, returns at least one entry:

```r
if (nrow(milestones) == 0 && nrow(info_data) > 0) {
  add_milestone("Log File Parsed", info_data[1, , drop = FALSE])
}
```

---

## Quick View Integration

### Source Loading (quick_view_module.R:30-31)

```r
source("R/utils/boot_milestones.R", local = TRUE)  # DB110 boot milestones
source("R/utils/ms110_boot_milestones.R", local = TRUE)  # MS110 boot milestones
```

### Log Type Detection (quick_view_module.R:543-562)

```r
if (rv$log_type == "MS110") {
  # Use MS110-specific function
  extract_ms110_boot_milestones(
    rv$selected_file,
    info_data,
    maint_log,
    sbit_section
  )
} else if (rv$log_type == "DB110") {
  # Use DB110-specific function (from sbitCompass)
  extract_boot_milestones(
    rv$selected_file,
    info_data,
    maint_log,
    sbit_section
  )
}
```

---

## Differences: MS110 vs DB110 Milestones

| Milestone | MS110 Pattern | DB110 Pattern |
|-----------|---------------|---------------|
| Power-On | First timestamp | "TR_Low Starting up the RSM" |
| Software Version | "ABSW\|software version" | Various RSM patterns |
| Sensor Init | "sensor.*init" | DTM/SCU communication |
| Time Sync | N/A (not in MS110) | "TSY\|" in maint log |
| SBIT | sbitSection first/last | SBIT section timing |
| Mission | "mission.*plan" | Mission ID detection |
| Focal Planes | "EO.*focal.*plane", "IR.*focal.*plane" | N/A (different sensors) |

---

## Return Structure

Both functions return the same data frame structure:

```r
data.frame(
  milestone = character(),    # Name of the milestone
  timestamp = POSIXct(),      # When it occurred
  value = character(),        # Optional value/detail
  status = character()        # PASS/FAIL/WARN
)
```

---

## Testing

### Expected Behavior

1. **MS110 logs** → Uses `extract_ms110_boot_milestones()`
2. **DB110 logs** → Uses `extract_boot_milestones()`
3. **No milestones found** → Shows "No boot milestones found" message
4. **Error during extraction** → Logs error, shows "No boot milestones found"

### Display

- Table with 4 columns: Milestone, Timestamp, Value, Status
- Color-coded status (PASS=green, FAIL=red, WARN=yellow)
- No pagination (shows all milestones)
- Timestamps formatted as YYYY-MM-DD HH:MM:SS

---

## Future Enhancements

Potential improvements:

1. **Timing Analysis**
   - Calculate time between milestones
   - Flag slow initialization steps
   - Show total boot time

2. **Historical Comparison**
   - Compare boot times across logs
   - Identify performance degradation
   - Trend analysis

3. **More Milestones**
   - GPS lock
   - INS alignment
   - Communication link establishment
   - Data recording start

4. **Smart Detection**
   - Learn patterns from multiple logs
   - Adapt to different SW versions
   - Custom milestone definitions

---

## Status

✅ **Implementation Complete**
- MS110-specific function created
- Base R syntax (no dplyr issues)
- Integrated into Quick View
- Automatic log type detection
- Graceful error handling

⏳ **Pending Testing**
- Test with actual MS110 logs
- Verify milestone detection accuracy
- Confirm timestamp extraction
- Validate display formatting

---

**Ready for testing with MS110 info logs!**
