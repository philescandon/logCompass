# Quick View Module Fixes

**Date**: 2025-10-23
**Author**: Claude (Anthropic)
**Issue**: Quick View module was not properly extracting and displaying MS110/DB110 metadata and SBIT results

---

## Problem Summary

The Quick View module had several critical issues:

1. **Wrong extraction approach**: Tried to extract metadata directly from `info_df` data frame instead of using aerolog extraction functions
2. **Incorrect function calls**: Called `ms110_getSBIT(df)` with data frame instead of `ms110_getSBIT(log_data)` with full parsed structure
3. **Missing aerolog function usage**: Did not leverage the complete set of aerolog extraction functions (e.g., `ms110_getSensorID`, `ms110_getMissionData`)
4. **Incomplete metadata display**: Metadata tab only showed raw data frame info instead of Sensor ID, Pod ID, Mission Plan, etc.

---

## Root Cause

The `aerolog::ms110_processInfoLog()` function returns a **list structure** with multiple components:
- `$mission`: Mission metadata (sensor ID, pod ID, flight date, etc.)
- `$sbit`: SBIT test results data frame
- `$info_df`: Main parsed log entries data frame
- Other components for specific data types

The Quick View module was treating this as if it were just a data frame, rather than using the aerolog extraction functions designed to work with this structure.

---

## Changes Made

### 1. Metadata Extraction (Lines 311-424)

**Before**:
```r
# Tried to extract directly from rv$parsed_log$mission
if (!is.null(rv$parsed_log$mission)) {
  mission <- rv$parsed_log$mission
  for (field in names(mission)) {
    metadata[[field]] <- mission[[field]]
  }
}
```

**After**:
```r
# Use aerolog extraction functions with full log_data structure
sensor_id <- tryCatch({
  aerolog::ms110_getSensorID(rv$parsed_log)
}, error = function(e) NULL)
if (!is.null(sensor_id) && !is.na(sensor_id)) {
  metadata$`Sensor ID` <- sensor_id
}

# Extract pod ID
pod_id <- tryCatch({
  aerolog::ms110_getPodID(rv$parsed_log)
}, error = function(e) NULL)

# Extract mission plan
mission_plan <- tryCatch({
  aerolog::ms110_getMissionPlan(rv$parsed_log)
}, error = function(e) NULL)

# Extract mission data
mission_data <- tryCatch({
  aerolog::ms110_getMissionData(rv$parsed_log)
}, error = function(e) NULL)

# Extract sysdisk info
sysdisk <- tryCatch({
  aerolog::ms110_getSysdisk(rv$parsed_log)
}, error = function(e) NULL)
```

**Key Functions Used**:
- `aerolog::ms110_getSensorID()` - Extract sensor ID
- `aerolog::ms110_getPodID()` - Extract pod ID
- `aerolog::ms110_getMissionPlan()` - Extract mission plan
- `aerolog::ms110_getMissionData()` - Extract comprehensive mission data
- `aerolog::ms110_getSysdisk()` - Extract system disk info

### 2. SBIT Results Extraction (Lines 450-500)

**Before**:
```r
# Tried to get data frame first, then call extraction
if (is.data.frame(rv$parsed_log)) {
  df <- rv$parsed_log
} else if (!is.null(rv$parsed_log$info_df)) {
  df <- rv$parsed_log$info_df
}

# Then called with df
sbit_results <- aerolog::ms110_getSBIT(df)
```

**After**:
```r
# Call extraction function directly with full log_data structure
sbit_df <- data.frame(
  Name = character(),
  TID = character(),
  Status = character(),
  time2 = character(),
  stringsAsFactors = FALSE
)

tryCatch({
  if (rv$log_type == "MS110") {
    # Use aerolog extraction function with full log_data structure
    sbit_results <- aerolog::ms110_getSBIT(rv$parsed_log)
    if (is.data.frame(sbit_results) && nrow(sbit_results) > 0) {
      sbit_df <- sbit_results
    }
  } else if (rv$log_type == "DB110") {
    # Use DB110 extraction function
    sbit_results <- aerolog::db110_getSBITResults(rv$parsed_log)
    if (is.data.frame(sbit_results) && nrow(sbit_results) > 0) {
      sbit_df <- sbit_results
    }
  }
}, error = function(e) {
  message("Error extracting SBIT results: ", e$message)
})
```

**Key Functions Used**:
- `aerolog::ms110_getSBIT(log_data)` - Extract MS110 SBIT results
- `aerolog::db110_getSBITResults(log_data)` - Extract DB110 SBIT results

### 3. SBIT Statistics (Lines 502-542)

**Before**:
```r
# Similar issue - extracted df first, then tried to use it
if (is.data.frame(rv$parsed_log)) {
  df <- rv$parsed_log
} else if (!is.null(rv$parsed_log$info_df)) {
  df <- rv$parsed_log$info_df
}

if (rv$log_type == "MS110") {
  sbit_results <- aerolog::ms110_getSBIT(df)  # Wrong!
}
```

**After**:
```r
# Direct extraction with full log_data structure
sbit_df <- tryCatch({
  if (rv$log_type == "MS110") {
    aerolog::ms110_getSBIT(rv$parsed_log)
  } else if (rv$log_type == "DB110") {
    aerolog::db110_getSBITResults(rv$parsed_log)
  } else {
    NULL
  }
}, error = function(e) {
  NULL
})

# Then calculate statistics
total <- nrow(sbit_df)
pass <- sum(sbit_df$Status == "PASS", na.rm = TRUE)
fail <- sum(sbit_df$Status == "FAIL", na.rm = TRUE)
degr <- sum(sbit_df$Status == "DEGR", na.rm = TRUE)
```

### 4. Maintenance Log Extraction (Lines 629-691)

**Before**:
```r
# Accessed info_df directly and filtered manually
df <- rv$parsed_log$info_df
fx_col <- df$fx
maint_rows <- !is.na(fx_col) & fx_col == "MaintLog"
maint_df <- df[maint_rows, , drop = FALSE]
```

**After**:
```r
# Use DB110-specific extraction when available
maint_df <- tryCatch({
  if (rv$log_type == "DB110") {
    # Use DB110-specific extraction
    aerolog::db110_getMaintLog(rv$parsed_log)
  } else if (rv$log_type == "MS110") {
    # For MS110, extract from info_df (no specific function available)
    if (!is.null(rv$parsed_log$info_df)) {
      df <- rv$parsed_log$info_df
      if ("fx" %in% names(df) && "text" %in% names(df)) {
        fx_col <- df$fx
        maint_rows <- !is.na(fx_col) & fx_col == "MaintLog"
        df[maint_rows, , drop = FALSE]
      } else {
        NULL
      }
    } else {
      NULL
    }
  } else {
    NULL
  }
}, error = function(e) {
  NULL
})
```

**Key Functions Used**:
- `aerolog::db110_getMaintLog(log_data)` - Extract DB110 maintenance log

### 5. System Messages Extraction (Lines 697-815)

**Before**:
```r
# Manual extraction from info_df
df <- rv$parsed_log$info_df
sw2_col <- df$sw2
irfpa_rows <- !is.na(sw2_col) & grepl("Fpa", sw2_col, ignore.case = TRUE)
irfpa_df <- df[irfpa_rows, , drop = FALSE]
```

**After**:
```r
# Use DB110-specific extraction when available
irfpa_df <- tryCatch({
  if (rv$log_type == "DB110") {
    # Use DB110-specific extraction
    aerolog::db110_getIRFPA(rv$parsed_log)
  } else if (rv$log_type == "MS110") {
    # For MS110, extract from info_df
    if (!is.null(rv$parsed_log$info_df)) {
      df <- rv$parsed_log$info_df
      if ("sw2" %in% names(df) && "text" %in% names(df)) {
        sw2_col <- df$sw2
        irfpa_rows <- !is.na(sw2_col) & grepl("Fpa", sw2_col, ignore.case = TRUE)
        df[irfpa_rows, , drop = FALSE]
      } else {
        NULL
      }
    } else {
      NULL
    }
  } else {
    NULL
  }
}, error = function(e) {
  NULL
})
```

**Key Functions Used**:
- `aerolog::db110_getIRFPA(log_data)` - Extract DB110 IRFPA messages
- `aerolog::db110_getPower(log_data)` - Extract DB110 power messages

---

## Testing Requirements

After these changes, the Quick View module should be tested with:

1. **MS110 info.log file**:
   - Verify Metadata tab shows: Sensor ID, Pod ID, Mission Plan, Flight Date, System Disk, and other mission fields
   - Verify SBIT Results tab shows test results with proper filtering
   - Verify Summary Statistics shows correct counts (Total, Pass, Fail, Degraded)
   - Verify Maintenance Log, IRFPA, and Power tables display correctly

2. **DB110 errorlog.log file**:
   - Verify Metadata tab shows DB110-specific metadata
   - Verify SBIT Results tab uses `db110_getSBITResults()`
   - Verify Maintenance Log uses `db110_getMaintLog()`
   - Verify System Messages use `db110_getIRFPA()` and `db110_getPower()`

---

## Key Takeaways

1. **Always use aerolog extraction functions** with the full `log_data` structure returned by `processInfoLog()` or `processLog()`
2. **Never try to extract by parsing data frames manually** - the aerolog package has specialized functions for this
3. **Use tryCatch** around all extraction calls to gracefully handle missing data
4. **Stick to base R** for data manipulation to avoid dplyr scoping issues
5. **Check function signatures** in AEROLOG_FUNCTIONS.md before implementing extraction logic

---

## Related Documentation

- [AEROLOG_FUNCTIONS.md](AEROLOG_FUNCTIONS.md) - Complete aerolog package function reference
- [ARCHITECTURE.md](ARCHITECTURE.md) - Log Compass architecture overview
- [R/modules/quick_view_module.R](R/modules/quick_view_module.R) - Updated module code

---

**Status**: Ready for testing with actual MS110 and DB110 log files.
