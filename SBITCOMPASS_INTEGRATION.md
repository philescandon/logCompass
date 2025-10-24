# sbitCompass Integration Plan

**Date**: 2025-10-24
**Purpose**: Document what components from sbitCompass should be integrated into logCompass

---

## Overview

The sbitCompass application is a mature Pod Compass diagnostic analysis tool with extensive functionality that should be integrated into the unified Log Compass Suite. This document outlines the key components and integration strategy.

---

## Key Components in sbitCompass

### 1. **Utility Functions** (R/utils/)

#### boot_milestones.R
**Purpose**: Extracts 10 key boot sequence milestones with timestamps

**Key Functions**:
- `extract_boot_milestones()` - Main extraction function
- Tracks milestones:
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

**Integration Status**: ✅ **READY TO COPY**
- This is perfect for the "Boot Milestones" tab in Quick View
- Works with both MS110 and DB110 logs (uses info_data, maint_log, sbit_section)

#### error_detection.R
**Purpose**: Detects critical error patterns and sequences in logs

**Key Functions**:
- `get_critical_error_patterns()` - Database of known error patterns
- `detect_error_sequences()` - Analyzes logs for error patterns

**Error Patterns Detected**:
- IRFPA Communication Failure (CRITICAL)
- FPA Power State Failure (HIGH)
- Network Communication Timeout (MEDIUM)
- SBIT Cascading Failures (HIGH)

**Features**:
- Time-window based grouping
- Severity levels
- Actionable recommendations for each error type

**Integration Status**: ✅ **READY TO COPY**
- Can be used in Quick View to show detected issues
- Valuable for Pod Compass deep analysis mode

#### focus_drive.R
**Purpose**: Analyzes focus drive test data from DataLogger fastLog format

**Key Functions**:
- `validate_focus_drive_file()` - Validates focus drive test files
- `parse_focus_drive_log()` - Parses DataLogger fastLog format
- `analyze_focus_drive_data()` - Pass/Fail analysis (3 mils threshold)
- `create_focus_drive_plots()` - Interactive plotly visualizations
- `create_focus_drive_ggplot()` - Static plots for PDF reports
- `create_focus_drive_histogram()` - Error distribution analysis

**Integration Status**: ⚠️ **SPECIALIZED - LOW PRIORITY**
- Focus drive tests are specific diagnostic tests
- Not part of standard MS110/DB110 log analysis
- Could be added as optional module later

#### data_processing.R
**Purpose**: Main log processing orchestration for sbitCompass

**Key Functions**:
- `process_single_log()` - Orchestrates all extractions for one log
- `process_multiple_logs()` - Batch processing
- Extracts: metadata, cal_bpm, sbit, maint_log, irfpa, power, boot_milestones, error_sequences

**Integration Status**: ⚠️ **REFERENCE ONLY**
- This is already largely implemented in Quick View module
- Good reference for ensuring we extract all components correctly
- The extraction pattern is:
  ```r
  log_info <- processInfoLog(log_file)
  metadata <- log_info$info_df
  sbit <- log_info$sbitSection
  maint_log <- log_info$maintLog
  irfpa <- getIRFPA(log_info$sbitSection)
  power <- getPower(log_info$info)
  boot_milestones <- extract_boot_milestones(...)
  error_sequences <- detect_error_sequences(...)
  ```

---

## Integration Priority

### HIGH PRIORITY (Implement Now)

1. **boot_milestones.R** → `R/utils/boot_milestones.R`
   - Copy entire file
   - Update Boot Milestones tab in Quick View to use these functions
   - Works with existing MS110/DB110 structure

2. **error_detection.R** → `R/utils/error_detection.R`
   - Copy entire file
   - Add "Error Detection" section to Quick View
   - Can show critical issues at the top of tabs

### MEDIUM PRIORITY (Phase 4-5)

3. **Pod Compass Deep Analysis Mode**
   - Port the full sbitCompass comparative analysis features
   - Multi-log comparison
   - Trend analysis across logs
   - Fleet health dashboard

### LOW PRIORITY (Future Enhancement)

4. **focus_drive.R** → Optional module
   - Specialized test analysis
   - Not part of standard log workflow
   - Can be added as separate tab if needed

---

## Quick View Enhancements from sbitCompass

### Current Quick View Tabs:
1. ✅ Metadata - DONE
2. ✅ SBIT Results - IN PROGRESS (needs testing)
3. ⚠️ Boot Milestones - PLACEHOLDER (needs implementation)
4. ✅ Maintenance Log - DONE
5. ✅ System Messages - DONE
6. ✅ Raw Log - DONE (with sentiment highlighting)

### Recommended Additions:

**Add to Quick View:**
- **Error Detection** - Show critical errors at top of Metadata tab
  - Red alert box if critical errors detected
  - List of detected error patterns with severity
  - Recommendations for each issue

**Enhance Boot Milestones Tab:**
- Use `extract_boot_milestones()` function
- Display as timeline visualization
- Show time between milestones
- Highlight any missing or delayed milestones

---

## Implementation Steps

### Step 1: Copy Utility Files
```bash
# Copy boot milestones
cp ../sbitCompass/R/utils/boot_milestones.R R/utils/

# Copy error detection
cp ../sbitCompass/R/utils/error_detection.R R/utils/
```

### Step 2: Update Quick View Module

**Boot Milestones Tab:**
```r
# Source the utility
source("R/utils/boot_milestones.R", local = TRUE)

# In server
output$boot_milestones_display <- renderUI({
  req(rv$parsed_log)

  # Extract boot milestones
  milestones <- extract_boot_milestones(
    rv$selected_file,
    rv$parsed_log$info_df,  # or rv$parsed_log$info depending on structure
    rv$parsed_log$maintLog,
    rv$parsed_log$sbitSection
  )

  # Display as table or timeline
  if (!is.null(milestones) && nrow(milestones) > 0) {
    DT::datatable(milestones, ...)
  } else {
    p("No boot milestones found")
  }
})
```

**Error Detection:**
```r
# Source the utility
source("R/utils/error_detection.R", local = TRUE)

# Add to metadata tab at top
error_sequences <- detect_error_sequences(
  rv$parsed_log$info_df,
  rv$parsed_log$irfpa,
  rv$parsed_log$power,
  rv$parsed_log$sbitSection
)

if (!is.null(error_sequences) && nrow(error_sequences) > 0) {
  # Show red alert box with critical errors
}
```

### Step 3: Test with Sample Logs
- Test with MS110 info logs
- Test with DB110 error logs
- Verify all milestones are detected
- Verify error patterns are identified

---

## Code Compatibility Notes

### Dependencies from sbitCompass:
- `dplyr` - ✅ Already in logCompass
- `stringr` - ✅ Already in logCompass
- `db110` package - ⚠️ Check if installed (for DB110-specific functions)
- `aerolog` package - ✅ Already in logCompass (for MS110)

### Structure Differences:
- sbitCompass uses `db110::processInfoLog()` → returns `$info`, `$sbitSection`, `$maintLog`
- logCompass uses `aerolog::ms110_processInfoLog()` → returns `$info`, `$info_df`, `$missionSection`, `$sbitSection`

**Adaptation needed:**
- Boot milestones function expects `info_data`, `maint_log`, `sbit_section` parameters
- Need to pass correct components based on log type (MS110 vs DB110)

---

## Benefits of Integration

1. **Boot Performance Analysis** - See system startup timing and identify delays
2. **Proactive Error Detection** - Catch critical issues before deep analysis
3. **Unified Diagnostics** - All diagnostic tools in one place
4. **Better User Experience** - Comprehensive info in Quick View before deep analysis

---

## Next Actions

1. ✅ Review sbitCompass code - COMPLETE
2. ⏳ Create this integration plan - IN PROGRESS
3. ⬜ Copy boot_milestones.R
4. ⬜ Copy error_detection.R
5. ⬜ Implement Boot Milestones tab
6. ⬜ Add Error Detection to Metadata tab
7. ⬜ Test with sample logs

---

**Status**: Integration plan complete, ready to begin implementation
