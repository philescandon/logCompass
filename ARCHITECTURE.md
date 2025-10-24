# Log Compass Suite - Architecture Documentation

**Author**: Phillip Escandon
**Organization**: RTX - Image Science
**Date**: 2025-10-23
**Version**: 2.0 - Unified Tool with Pod Compass Integration

---

## Executive Summary

Log Compass is being enhanced from a simple batch processing tool into a comprehensive suite for aerospace sensor log analysis. The tool will support three operational modes in a single integrated application:

1. **Quick View**: Rapid single-file viewing and exploration
2. **Batch Process**: Bulk log file processing, cleaning, and renaming
3. **Pod Compass Analysis**: Deep comparative analysis with automatic mode detection

The tool handles both **MS110 Info Logs** and **DB110 Error Logs** with automatic detection and intelligent analysis grouping (Single Pod vs Multi-Pod Fleet modes).

---

## Core Requirements

### Supported Log Types
- **MS110 Info Logs** (`info.log` files)
  - Uses `ms110` package for parsing
  - Newer system architecture
  - SBIT test structure similar to DB110
  - Additional milestones: SHA file validation, etc.

- **DB110 Error Logs** (`errorlog.log` files)
  - Uses `db110` package for parsing
  - Legacy system architecture
  - Standard SBIT test structure
  - Boot milestones, maintenance logs, system messages

### Key Principles
- **MS110 and DB110 logs are NEVER analyzed together** (different systems)
- **Automatic log type detection** (filename pattern or content search)
- **Automatic analysis mode detection** (Single Pod vs Multi-Pod based on sensor IDs)
- **All logs must be processed before analysis** (contractions, line continuations fixed)
- **Sensor ID is embedded in renamed filenames** as the key identifier

---

## Application Architecture

### High-Level Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                      LOG COMPASS                                 │
│         Navigate and Process Aerospace Sensor Logs              │
├─────────────────────────────────────────────────────────────────┤
│  [Quick View] [Batch Process] [Pod Compass Analysis]           │
└─────────────────────────────────────────────────────────────────┘
```

### Three Main Operational Modes

#### 1. Quick View Tab (NEW)
**Purpose**: Rapidly view and explore single log files without batch processing

**Features**:
- Single file selection (both MS110 and DB110 supported)
- Automatic log type detection
- Parse and display structured sections:
  - Metadata panel (sensor ID, version, mission, focal planes)
  - SBIT Test Results (interactive filterable table)
  - Boot Milestones (checkoff list with pass/fail)
  - Maintenance Log (chronological entries)
  - System Messages (IRFPA, Power, etc.)
- Search/filter within SBIT tests by status
- Export options (cleaned log text, CSV results)
- "Analyze in Pod Compass" button for deeper analysis

#### 2. Batch Process Tab (ENHANCED)
**Purpose**: Bulk processing, cleaning, and renaming of log files

**Structure**: Two sub-tabs
- **MS110 Info Logs** (already implemented)
- **DB110 Error Logs** (needs implementation)

**Common Workflow**:
1. Select source directory
2. Select output directory
3. Configure options:
   - Recursive search
   - Clean contractions
   - Fix line continuations
   - Keep original files
4. Process files
5. Review results with enhanced table:
   - Checkbox selection
   - "Open Quick View" per file
   - "Analyze Selected in Pod Compass" button

**DB110 Batch Processing Requirements**:
- Search pattern: `error.*\.log`
- Extract metadata: sensor ID, epoch, mission ID
- Rename format: `DB110_<sensorID>_<epoch>_<missionID>.log`
- Clean contractions and line continuations
- Write to output directory
- Track status (success/warning/error)

#### 3. Pod Compass Analysis Tab (INTEGRATED & ENHANCED)
**Purpose**: Deep comparative analysis of multiple logs

**Key Enhancement**: Automatic Mode Detection

**Two Analysis Modes**:

##### Single Pod Mode
- Triggered when all files have the same sensor ID
- Focus: Temporal trends for ONE sensor over time
- Analysis emphasis:
  - Timeline of failure rates across missions
  - Degradation patterns over time
  - Test variability across missions
  - Maintenance recommendations for this sensor
  - Historical anomalies

##### Multi-Pod Fleet Mode
- Triggered when files have mixed sensor IDs
- Focus: Fleet-wide comparison and systematic issues
- Analysis emphasis:
  - Sensor-specific behavior comparison
  - Fleet-wide failure rate analysis
  - Systematic issues across all sensors
  - Best/worst performing sensors
  - Standardization opportunities
  - Sensors requiring immediate maintenance

**File Selection Options**:
1. **From Batch Process**: Files auto-loaded from Tab 2 selection
2. **Direct Selection**: Manual file browser (multiple selection)

**Auto-Detection Logic**:
- Detect MS110 vs DB110 from filename pattern
- Validate all files are same type (error if mixed)
- Extract sensor IDs from filenames
- Determine analysis mode based on sensor ID uniqueness
- Display prominent mode indicator badge

**Analysis Sub-Tabs** (adapted from current Pod Compass):
- **Summary**: Test results, statistics, boot milestones, mission capability (FMC/PMC/NMC)
- **Pod Metadata**: Metadata comparison, calibration status
- **Focus Test**: Focus drive test analysis
- **Diagnostics**: Dynamic sub-tabs per log file (boot, tests, failures, maintenance, IRFPA, power)
- **Patterns**: Mode-dependent temporal or fleet-wide analysis
- **Recommendations**: Mode-dependent maintenance and systematic issue recommendations
- **Reports**: Generate HTML/PDF/PowerPoint/RData reports

---

## File Structure

```
logCompass/
├── app.R                           # Main entry point
├── ARCHITECTURE.md                 # This file
├── R/
│   ├── ui.R                        # Top-level navbar UI
│   ├── server.R                    # Main server routing
│   │
│   ├── modules/
│   │   ├── quick_view_module.R     # NEW: Quick View tab
│   │   ├── batch_ms110_module.R    # Enhanced MS110 batch
│   │   ├── batch_db110_module.R    # NEW: DB110 batch processing
│   │   └── pod_compass_module.R    # Enhanced Pod Compass with mode detection
│   │
│   └── utils/
│       ├── log_detection.R         # NEW: Auto-detect MS110/DB110
│       ├── mode_detection.R        # NEW: Detect Single Pod/Multi-Pod
│       ├── processing.R            # Shared batch processing logic
│       ├── data_processing.R       # Analysis data processing (from Pod Compass)
│       ├── table_helpers.R         # Table display helpers (from Pod Compass)
│       ├── boot_milestones.R       # Boot milestone extraction (from Pod Compass)
│       ├── error_detection.R       # Error pattern detection (from Pod Compass)
│       ├── focus_drive.R           # Focus test analysis (from Pod Compass)
│       └── mission_capability.R    # NEW: FMC/PMC/NMC assessment (placeholder)
```

---

## Key Technical Implementation Details

### 1. Log Type Detection

**Primary Strategy**: Filename pattern matching
```r
detect_log_type <- function(filename) {
  filename_lower <- tolower(basename(filename))
  if (grepl("info", filename_lower)) return("MS110")
  if (grepl("error", filename_lower)) return("DB110")

  # Fallback: read file content and search for "MS110" or "DB110" strings
  detect_log_type_from_content(filename)
}
```

**Rationale**:
- MS110 logs contain "info" in filename (`info.log`)
- DB110 logs contain "error" in filename (`errorlog.log`)
- Content search as fallback for ambiguous cases

### 2. Sensor ID Extraction

**From Processed Filenames**:
```r
extract_sensor_id_from_filename <- function(filename) {
  # Pattern: MS110_<sensorID>_<epoch>_<missionID>.log
  # Pattern: DB110_<sensorID>_<epoch>_<missionID>.log
  pattern <- "^(MS110|DB110)_([^_]+)_"
  match <- str_match(basename(filename), pattern)
  if (!is.na(match[3])) return(match[3])

  # Fallback: parse from file content
  extract_sensor_id_from_content(filename)
}
```

**Key Point**: Renamed filenames embed sensor ID as crucial metadata for analysis grouping.

### 3. Analysis Mode Detection

```r
detect_analysis_mode <- function(filenames) {
  sensor_ids <- sapply(filenames, extract_sensor_id_from_filename)
  unique_sensors <- unique(sensor_ids[!is.na(sensor_ids)])

  list(
    mode = if(length(unique_sensors) == 1) "single_pod" else "multi_pod",
    sensors = unique_sensors,
    sensor_count = length(unique_sensors),
    display_label = if(length(unique_sensors) == 1) {
      paste("Single Pod Analysis - Sensor:", unique_sensors)
    } else {
      paste("Multi-Pod Fleet Analysis -", length(unique_sensors), "sensors")
    }
  )
}
```

**Display**:
- Single Pod: 🔵 **Single Pod Mode** - Sensor: 12345 - Temporal Trend Analysis
- Fleet: 🟢 **Fleet Mode** - 4 sensors over time period

### 4. Inter-Tab Communication

**Reactive Values for File Passing**:
```r
# In server.R
rv <- reactiveValues(
  quick_view_file = NULL,              # File selected in Quick View
  batch_selected_files = NULL,         # Files selected from Batch Process
  pod_compass_files = NULL,            # Files loaded in Pod Compass
  analysis_mode = NULL,                # Detected mode info
  log_type = NULL                      # "MS110" or "DB110"
)

# Example: From Batch Process to Pod Compass
observeEvent(input$batch_analyze_selected_btn, {
  selected <- get_selected_files_from_batch_results()
  rv$pod_compass_files <- selected
  rv$log_type <- detect_log_type(selected[1])
  rv$analysis_mode <- detect_analysis_mode(selected)
  updateNavbarPage(session, "main_navbar", selected = "Pod Compass")
})

# Example: From Quick View to Pod Compass
observeEvent(input$quick_view_analyze_btn, {
  rv$pod_compass_files <- c(rv$quick_view_file)
  rv$log_type <- detect_log_type(rv$quick_view_file)
  rv$analysis_mode <- list(mode = "single_pod", sensors = extract_sensor_id(rv$quick_view_file))
  updateNavbarPage(session, "main_navbar", selected = "Pod Compass")
})
```

### 5. Mission Capability Assessment (Placeholder)

**Future Implementation**:
```r
assess_mission_capability <- function(sbit_results) {
  # FMC: Fully Mission Capable (0 critical failures)
  # PMC: Partial Mission Capable (1-5 failures, or non-critical only)
  # NMC: Not Mission Capable (>5 failures or critical system failure)

  # Placeholder logic - needs domain expertise for thresholds
  fail_count <- sum(sbit_results$Status == "FAIL")

  if (fail_count == 0) {
    return(list(status = "FMC", label = "Fully Mission Capable", color = "green"))
  } else if (fail_count <= 5) {
    return(list(status = "PMC", label = "Partial Mission Capable", color = "yellow"))
  } else {
    return(list(status = "NMC", label = "Not Mission Capable", color = "red"))
  }
}
```

**Display**:
- Summary tab: FMC/PMC/NMC badge per log file
- Fleet mode: Overall fleet capability summary
- Reports: Include mission capability assessment

---

## User Workflows

### Workflow A: Quick View → Analyze
1. User opens **Quick View** tab
2. Selects single `DB110_12345_epoch_mission.log`
3. Views SBIT results, identifies interesting failures
4. Clicks **"Analyze in Pod Compass"**
5. Pod Compass opens in Single Pod mode (one file)
6. User can add more files from same sensor for comparison

### Workflow B: Batch Process → Select → Analyze (Single Pod)
1. User opens **Batch Process** → **DB110 Error Logs**
2. Selects source directory with 50 raw error logs from various sensors
3. Processes all files (renamed and cleaned)
4. Reviews results table
5. Checks boxes next to 5 files from sensor 12345
6. Clicks **"Analyze Selected in Pod Compass"**
7. **Auto-detection**: All 5 files have same sensor → Single Pod mode
8. Pod Compass opens with temporal analysis for sensor 12345 across 5 missions

### Workflow C: Batch Process → Fleet Analysis
1. User opens **Batch Process** → **DB110 Error Logs**
2. Processes 2 weeks of logs (20 files from 4 different sensors)
3. Selects all 20 files via checkboxes
4. Clicks **"Analyze Selected in Pod Compass"**
5. **Auto-detection**: 4 unique sensor IDs → Multi-Pod Fleet mode
6. Pod Compass opens with fleet-wide comparative analysis
7. Identifies systematic issues across sensors, best/worst performers

### Workflow D: Direct Pod Compass Analysis
1. User opens **Pod Compass Analysis** tab directly
2. Uses file browser to select 10 pre-processed files
3. **Auto-detection**: Mixed sensors → Fleet Mode
4. Runs comparative analysis
5. Generates fleet-wide HTML/PDF report

### Workflow E: Quick View Only (Common Engineering Use Case)
1. User receives raw `errorlog.log` file
2. Opens **Quick View** tab
3. Selects raw file (not yet processed)
4. Tool auto-detects DB110, parses, displays structured view
5. User reads SBIT results, checks maintenance log
6. Done - no further analysis needed

---

## Implementation Phases

### Phase 1: Foundation & Quick View
**Goal**: Create quick single-file viewing capability

**Deliverable**: Functional Quick View tab that can parse and display both MS110 and DB110 logs

---

### Phase 2: Complete DB110 Batch Processing
**Goal**: Implement DB110 batch processing to match MS110 functionality

**Deliverable**: Fully functional DB110 batch processing matching MS110 capabilities

---

### Phase 3: Enhance Batch Process Results
**Goal**: Add selection and navigation capabilities to batch results

**Deliverable**: Enhanced batch results with seamless navigation to Quick View and Pod Compass

---

### Phase 4: Integrate & Enhance Pod Compass
**Goal**: Integrate Pod Compass functionality with mode detection

**Deliverable**: Fully integrated Pod Compass with automatic mode detection and MS110 support

---

### Phase 5: Testing & Refinement
**Goal**: Comprehensive testing of all workflows

**Deliverable**: Fully tested application with all workflows verified

---

### Phase 6: Polish & Documentation
**Goal**: Final refinements and user documentation

**Deliverable**: Production-ready application with complete documentation

---

## Package Dependencies

### Core Packages
- `shiny`: Web application framework
- `shinyFiles`: File/directory selection dialogs
- `bslib`: Modern Bootstrap UI components
- `DT`: Interactive data tables
- `dplyr`, `tidyr`, `tibble`: Data manipulation
- `stringr`: String operations
- `readr`: File reading
- `purrr`: Functional programming

### Analysis Packages (from Pod Compass)
- `plotly`: Interactive plots
- `ggplot2`: Static plots (for PDF reports)
- `gridExtra`: Multi-panel plots
- `flextable`: Styled tables
- `rmarkdown`, `knitr`: Report generation
- `kableExtra`: Enhanced tables for reports
- `tinytex`: PDF generation support

### Domain-Specific Packages
- `aerolog`: Base package for aerospace log parsing (MS110 and DB110)
- `ms110`: MS110-specific parsing functions
- `db110`: DB110-specific parsing functions

---

## Glossary

- **SBIT**: Self-Built-In Test - diagnostic test suite run on aerospace sensors
- **FMC**: Fully Mission Capable - system has no failures affecting mission
- **PMC**: Partial Mission Capable - system has minor failures but can still perform mission
- **NMC**: Not Mission Capable - system has critical failures preventing mission
- **Pod**: Reconnaissance sensor pod (contains MS110 or DB110 systems)
- **Sensor ID**: Unique identifier for a specific sensor unit
- **Boot Milestone**: Key initialization step during system startup
- **Maintenance Log**: Chronological record of system events and maintenance actions
- **Focal Plane**: Imaging sensor array (EO = Electro-Optical, IR = Infrared)
- **Focus Drive Test**: Diagnostic test of lens focusing mechanism
- **Epoch**: Time-based identifier for a specific log instance
- **Mission Plan**: Identifier for the mission or test scenario

---

## Contact & Support

**Developer**: Phillip Escandon
**Email**: Phillip.Escandon@pm.me
**Organization**: RTX - Image Science

---

*This architecture document is maintained alongside the Log Compass codebase and should be updated as features evolve.*
