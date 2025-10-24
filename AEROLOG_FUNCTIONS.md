# Aerolog Package Function Reference

**Package**: `aerolog`
**Purpose**: Core R package for MS110/DB110 aerospace sensor log analysis
**Last Updated**: 2025-10-23

This document provides a reference for all functions available in the `aerolog` package.

---

## General Utility Functions

### `cleanInfoLog()`
Clean info log files (merge continuations, fix formatting).

### `displayDT()`
Display data as DataTable (DT package wrapper).

### `displayFT()`
Display data as FlexTable (flextable package wrapper).

### `extract_quoted_content()`
Extract content between quotes from text.

### `fixFileEnd()`
Fix file endings and ensure proper line termination.

### `getSensorID()`
General function to extract sensor ID from logs.

### `safe_extract()`
Safely extract values with error handling.

---

## DB110 Error Log Functions

### Processing Functions

#### `db110_processLog(file_path)`
**Primary function to process a single DB110 error log.**
- **Input**: Path to errorlog.log file
- **Output**: List with components:
  - `$info`: Named list of metadata (Sensor, Mission Plan, etc.)
  - `$info_df`: Data frame with parsed log entries
  - Additional component-specific data frames

#### `db110_processRawErrorLog(file_path, output_dir, clean, keep_original, verbose)`
Process raw DB110 error log with cleaning and renaming.
- **Input**:
  - `file_path`: Path to raw errorlog.log
  - `output_dir`: Directory for processed output
  - `clean`: Logical, whether to clean the log
  - `keep_original`: Logical, whether to keep original file
  - `verbose`: Logical, verbose output
- **Output**: Path to processed file or processing result

#### `db110_renameErrorLog(file_path)`
Rename DB110 error log file based on extracted metadata.
- **Format**: `DB110_<sensorID>_<epoch>_<missionID>.log`

### Extraction Functions

#### `db110_getCalBPM(log_data)`
Extract calibration and BPM (Bad Pixel Map) information.

#### `db110_getIRFPA(log_data)`
Extract IRFPA (Infrared Focal Plane Array) messages.

#### `db110_getMaintLog(log_data)`
Extract maintenance log entries.

#### `db110_getPower(log_data)`
Extract power system messages.

#### `db110_getSBITResults(log_data)`
Extract SBIT (Self-Built-In Test) test results.
- **Output**: Data frame with columns: Name, TID, Status, time

---

## MS110 Info Log Functions

### Processing Functions

#### `ms110_processInfoLog(file_path)`
**Primary function to process a single MS110 info log.**
- **Input**: Path to info.log file
- **Output**: List with components:
  - `$info`: Named list of metadata
  - `$info_df`: Data frame with parsed log entries
  - Task and mission-specific data

#### `ms110_processRawInfoLog(file_path, output_dir, clean, keep_original, verbose)`
Process raw MS110 info log with cleaning and renaming.
- **Input**: Similar to DB110 version
- **Output**: Path to processed file or processing result

#### `ms110_readInfoLog(file_path)`
Read and parse MS110 info log file into structured format.

#### `ms110_renameInfoLog(file_path)`
Rename MS110 info log file based on extracted metadata.
- **Format**: `MS110_<sensorID>_<epoch>_<missionID>.log`

#### `ms110_writeInfoLogCSV(log_data, output_path)`
Write processed log data to CSV format.

### Batch Processing

#### `ms110_collectInfoLogs(source_dirs, output_dir, recursive, clean, keep_original, verbose)`
**Batch process multiple MS110 info logs.**
- **Input**:
  - `source_dirs`: Vector of source directories
  - `output_dir`: Output directory
  - `recursive`: Search recursively (logical)
  - `clean`: Clean logs (logical)
  - `keep_original`: Keep originals (logical)
  - `verbose`: Verbose output (logical)
- **Output**: Data frame with processing results

### Metadata Extraction Functions

#### `ms110_getSensorID(log_data)`
Extract sensor ID from MS110 log.

#### `ms110_getPodID(log_data)`
Extract pod ID information.

#### `ms110_getMissionPlan(log_data)`
Extract mission plan information.

#### `ms110_getMP2(log_data)`
Alternative mission plan extraction.

#### `ms110_getMissionData(log_data)`
Extract comprehensive mission data.

#### `ms110_getPodDF(log_data)`
Get pod data as data frame.

#### `ms110_getSysdisk(log_data)`
Extract system disk information.

#### `ms110_getValue(log_data, key)`
Extract specific value by key.

### SBIT and Calibration Functions

#### `ms110_getSBIT(log_data)`
Extract SBIT test results.

#### `ms110_getPretaskCal(log_data)`
Extract pre-task calibration data.

#### `ms110_getNUC(log_data)`
Extract NUC (Non-Uniformity Correction) data.

#### `ms110_determine_nuc_success_mixed(log_data)`
Determine NUC success status with mixed results handling.

### Focal Plane Functions

#### `ms110_geteofpa(log_data)`
Extract EO (Electro-Optical) focal plane data.

#### `ms110_getirfpa(log_data)`
Extract IR (Infrared) focal plane data.

#### `ms110_getABSW(log_data)`
Extract ABSW (?) data.

#### `ms110_getPlus(log_data)`
Extract Plus focal plane data.

### Task Analysis Functions

#### `ms110_createTaskClass(task_data)`
Create task classification object.

#### `ms110_findTasks(log_data)`
Find all tasks in log.

#### `ms110_findPlannedTasks(log_data)`
Find planned tasks from mission plan.

#### `ms110_findTaskStartStop2(log_data)`
Find task start and stop times.

#### `ms110_splitTask(log_data)`
Split tasks into individual components.

#### `ms110_getTaskData(log_data, task_id)`
Get data for specific task.

#### `ms110_getTaskMetrics(task_data)`
Calculate task performance metrics.

#### `ms110_getTaskModeID(task_data)`
Extract task mode identifier.

#### `ms110_getTaskScanCount(task_data)`
Get scan count for task.

#### `ms110_getScans(log_data)`
Extract all scan data.

### Display Functions

#### `ms110_displayMetricTable(metrics)`
Display metrics in formatted table.

#### `ms110_displayMissionData(mission_data)`
Display mission data in formatted view.

#### `ms110_displayTask(task_data)`
Display single task information.

#### `ms110_displayTaskMetrics(task_metrics)`
Display task performance metrics.

#### `ms110_displayTaskScans(task_scans)`
Display task scan information.

### Pattern Matching Functions

#### `ms110_fpaPattern()`
Return regex pattern for FPA sections.

#### `ms110_fpaEndPattern()`
Return regex pattern for FPA section end.

#### `ms110_planPattern()`
Return regex pattern for mission plan.

#### `ms110_tspattern()`
Return regex pattern for timestamps.

#### `ms110_testNUCPattern()`
Return regex pattern for NUC test results.

### Parsing Utility Functions

#### `ms110_extract_quoted_text(text)`
Extract text between quotes.

#### `ms110_parens2parens(text)`
Extract text between parentheses.

#### `ms110_semi2end(text)`
Extract text from semicolon to end.

#### `ms110_semi2single(text)`
Extract text from semicolon to single quote.

#### `ms110_single2single(text)`
Extract text between single quotes.

#### `ms110_start2parens(text)`
Extract text from start to parentheses.

#### `ms110_start2semi(text)`
Extract text from start to semicolon.

#### `ms110_double2double(text)`
Extract text between double quotes.

### File Utility Functions

#### `ms110_list_files_in_directory_recursively(directory)`
Recursively list files in directory.

#### `ms110_split_path(file_path)`
Split file path into components.

#### `ms110_findRate(text)`
Find rate values in text.

#### `ms110_findState(text)`
Find state information in text.

---

## Usage Examples

### Process a Single DB110 Error Log

```r
# Load package
library(aerolog)

# Process log file
log_data <- db110_processLog("path/to/errorlog.log")

# Access metadata
sensor_id <- log_data$info$Sensor
mission <- log_data$info$`Mission Plan`

# Access SBIT results
sbit_results <- db110_getSBITResults(log_data)

# View results
head(sbit_results)
```

### Process a Single MS110 Info Log

```r
# Load package
library(aerolog)

# Process log file
log_data <- ms110_processInfoLog("path/to/info.log")

# Access metadata
sensor_id <- ms110_getSensorID(log_data)
mission_data <- ms110_getMissionData(log_data)

# Access SBIT results
sbit_results <- ms110_getSBIT(log_data)

# View results
head(sbit_results)
```

### Batch Process MS110 Logs

```r
# Load package
library(aerolog)

# Batch process all info.log files in directory
results <- ms110_collectInfoLogs(
  source_dirs = c("path/to/raw/logs"),
  output_dir = "path/to/processed",
  recursive = TRUE,
  clean = TRUE,
  keep_original = FALSE,
  verbose = TRUE
)

# View processing results
View(results)
```

### Process and Rename DB110 Log

```r
# Load package
library(aerolog)

# Process raw error log with cleaning and renaming
output_path <- db110_processRawErrorLog(
  file_path = "path/to/errorlog.log",
  output_dir = "path/to/output",
  clean = TRUE,
  keep_original = TRUE,
  verbose = TRUE
)

print(paste("Processed file:", output_path))
```

---

## Log Data Structure

Both `ms110_processInfoLog()` and `db110_processLog()` return a list with the following common structure:

```r
log_data <- list(
  info = list(
    Sensor = "12345",
    `Mission Plan` = "TEST_MISSION",
    FlightDate = "2025-01-15",
    # ... other metadata fields
  ),
  info_df = data.frame(
    time = c(...),      # Timestamp
    time2 = c(...),     # Alternative timestamp format
    fx = c(...),        # Function/category
    sw2 = c(...),       # Software component
    text = c(...),      # Log text
    Name = c(...),      # Test name (for SBIT)
    TID = c(...),       # Test ID (for SBIT)
    Status = c(...)     # PASS/FAIL/DEGR (for SBIT)
  ),
  # ... additional component-specific data
)
```

---

## Notes for Developers

1. **Function Naming Convention**:
   - `ms110_*`: Functions specific to MS110 info logs
   - `db110_*`: Functions specific to DB110 error logs
   - No prefix: General utility functions

2. **Primary Processing Functions**:
   - Use `ms110_processInfoLog()` for quick single-file MS110 processing
   - Use `db110_processLog()` for quick single-file DB110 processing
   - Use `ms110_processRawInfoLog()` / `db110_processRawErrorLog()` when you need cleaning and renaming
   - Use `ms110_collectInfoLogs()` for batch MS110 processing

3. **Batch Processing**:
   - Currently only `ms110_collectInfoLogs()` exists for batch processing
   - For DB110 batch processing, use the custom `process_db110_batch()` function in `R/utils/processing.R`

4. **Error Handling**:
   - All processing functions return structured data or throw errors
   - Use `tryCatch()` when processing multiple files
   - Check for `NULL` values in returned data structures

---

## Related Documentation

- [Log Compass Architecture](ARCHITECTURE.md)
- [R/utils/processing.R](R/utils/processing.R) - Custom batch processing wrappers
- [R/utils/log_detection.R](R/utils/log_detection.R) - Log type detection utilities
- [R/utils/mode_detection.R](R/utils/mode_detection.R) - Analysis mode detection

---

**Maintained by**: Phillip Escandon (Phillip.Escandon@pm.me)
**Organization**: RTX - Image Science
**Last Updated**: 2025-10-23
