# Log Compass

**Navigate and Process Aerospace Sensor Log Files**

Log Compass is part of the **Compass Suite** - a collection of tools designed for aerospace sensor data analysis and processing.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Status](https://img.shields.io/badge/status-production-green)

---

## Overview

Log Compass provides an intuitive Shiny web interface for batch processing MS110 and DB110 sensor log files. It automates the tedious tasks of:

- **Cleaning** log files (merging continuation lines)
- **Extracting** metadata (sensor ID, mission ID, timestamps)
- **Renaming** files with standardized format
- **Organizing** logs across directory structures

## Features

### MS110 Info Log Processing ✓

- Batch process multiple `info.log` files
- Recursive directory search
- Automatic metadata extraction:
  - Sensor ID (Pod ID)
  - Mission ID
  - Epoch timestamp
  - System information
- Smart file renaming: `info_{sensorID}_{epoch}_{missionID}.log`
- Log file cleaning (continuation line merging)
- Interactive results table with export options
- Real-time processing log

### DB110 Error Log Processing 🔜

- Coming soon: Batch processing for `errorlog.log` files
- Currently supports single-file processing via `aerolog` package

## Installation

### Prerequisites

```r
# Required R packages
install.packages(c(
  "shiny", "shinyFiles", "DT", "bslib",
  "dplyr", "tidyr", "tibble", "stringr", "readr", "purrr"
))

# Install aerolog package (required)
devtools::install("path/to/aerolog")
```

### Running the App

```r
# From R console
shiny::runApp("D:/R_Shiny/logCompass")

# Or navigate to the directory and run
setwd("D:/R_Shiny/logCompass")
source("app.R")
```

## Usage

### Processing MS110 Info Logs

1. **Select Source Directory**
   - Click "Select Source Directory"
   - Navigate to folder containing raw `info.log` files
   - Can be nested in subdirectories if "Search subdirectories" is enabled

2. **Select Output Directory**
   - Click "Select Output Directory"
   - Choose where processed files should be saved
   - Directory will be created if it doesn't exist

3. **Configure Options**
   - **Search subdirectories recursively**: Find logs in all nested folders
   - **Clean log files**: Merge continuation lines (recommended)
   - **Keep original files**: Don't delete source files after processing
   - **Verbose output**: Show detailed processing messages

4. **Process**
   - Click "Process MS110 Logs"
   - Monitor progress in the Processing Log tab
   - Review results in the Results Table

5. **Review Results**
   - **Results Table**: View all processed files with metadata
   - **Processing Log**: See detailed processing messages
   - **Summary Statistics**: Quick overview of success/failure counts
   - Export results as CSV or Excel

### Example Workflow

```r
# Source Directory Structure:
D:/Missions/
├── 2025-01-15_Mission1/
│   └── info.log
├── 2025-01-16_Mission2/
│   └── info.log
└── 2025-01-17_Mission3/
    └── info.log

# After Processing:
D:/ProcessedLogs/
├── info_12_1737022006_Mission1.log
├── info_12_1737108406_Mission2.log
└── info_12_1737194806_Mission3.log
```

## Architecture

Log Compass follows **Mastering Shiny** and **R for Data Science** best practices:

```
logCompass/
├── app.R                    # Entry point, loads dependencies
├── R/
│   ├── ui.R                 # User interface definition
│   ├── server.R             # Server logic (reactive programming)
│   └── utils/
│       ├── processing.R     # Log processing functions
│       └── helpers.R        # Utility functions
├── www/                     # Static assets (images, CSS, JS)
└── README.md                # This file
```

### Design Principles

- **Modular**: Separation of UI, server, and business logic
- **Reactive**: Efficient reactive programming patterns
- **Maintainable**: Clear function naming, comprehensive documentation
- **Extensible**: Easy to add new features and log types
- **User-Friendly**: Modern UI with bslib/Bootstrap 5

## Powered By

### Core Package

- **[aerolog](../RPackage/aerolog/)**: Base package for MS110/DB110 log analysis
  - `ms110_collectInfoLogs()`: Batch MS110 processing
  - `ms110_processRawInfoLog()`: Single file processing
  - `db110_processLog()`: DB110 error log processing

### UI Framework

- **[Shiny](https://shiny.posit.co/)**: Interactive web framework
- **[bslib](https://rstudio.github.io/bslib/)**: Modern Bootstrap 5 theming
- **[DT](https://rstudio.github.io/DT/)**: Interactive DataTables

### Data Processing

- **[dplyr](https://dplyr.tidyverse.org/)**: Data manipulation
- **[tidyr](https://tidyr.tidyverse.org/)**: Data tidying
- **[stringr](https://stringr.tidyverse.org/)**: String operations
- **[purrr](https://purrr.tidyverse.org/)**: Functional programming

## Future Enhancements

### Version 1.1 (Planned)

- [ ] DB110 batch processing (`db110_collectErrorLogs`)
- [ ] Download processing reports as PDF/HTML
- [ ] File preview before processing
- [ ] Advanced filtering options (date range, sensor ID)
- [ ] Processing history/log persistence

### Version 2.0 (Proposed)

- [ ] Log file analysis and visualization
- [ ] Error pattern detection
- [ ] Timeline visualization
- [ ] Integration with other Compass apps
- [ ] Docker deployment

## Part of the Compass Suite

Log Compass is one of several tools in the Compass Suite:

- **[MissionCompass](../MissionCompass/)**: Mission analysis and reporting
- **[CoverageCompass](../CoverageCompass/)**: Geographic coverage validation
- **[Log Compass](../logCompass/)**: Log file processing (this app)
- **[sbitCompass (Pod Compass)](../sbitCompass/)**: Pod diagnostics and health

See [compass-suite-strategy.md](../compass-suite-strategy.md) for the complete vision.

## Technical Details

### File Naming Convention

Processed files follow this standardized format:

```
info_{sensorID}_{epoch}_{missionID}.log
```

Where:
- **sensorID**: Extracted from `Sensor ID #` or `podID:` in log
- **epoch**: Unix timestamp from STU or first log entry
- **missionID**: Extracted from MID pattern or Mission Plan name

### Metadata Extraction

The app extracts metadata by searching the first 2000 lines for:

1. **Sensor ID**: Patterns like `'Sensor ID #12'` or `podID: 12`
2. **Mission ID**: From `MID|timestamp|MissionName` or Mission Plan
3. **Epoch**: From `STU|timestamp` or first log entry timestamp

### Error Handling

- Invalid directories show clear error messages
- Failed file processing is tracked in results table
- Verbose mode provides detailed debugging information
- Original files optionally preserved for safety

## Troubleshooting

### "No directory selected" error
- Ensure you click the directory selection button and choose a valid path

### "No files found" warning
- Check that `info.log` files exist in the source directory
- Enable "Search subdirectories" if logs are nested
- Verify file naming matches `info.log` (case-sensitive on Linux)

### Sensor ID shows hash instead of actual ID
- Ensure aerolog package is updated to v1.0.0+
- The older version had pattern matching issues (fixed in Oct 2025)
- Reinstall: `devtools::install("D:/RPackage/aerolog")`

### Processing is very slow
- Expected for large numbers of files (cleaning is I/O intensive)
- Disable cleaning if files are already clean
- Process subdirectories separately

## Contributing

This tool is maintained by RTX Image Science. For bug reports or feature requests, contact:

**Phillip Escandon**
Email: Phillip.Escandon@pm.me
Organization: RTX - Image Science

## License

MIT License + file LICENSE

---

## Changelog

### Version 1.0.0 (2025-10-23)

- Initial release
- MS110 batch processing
- Modern bslib UI
- Interactive results table
- Export functionality
- Processing log capture
- Summary statistics

---

**Part of the Compass Suite** | Navigate Your Data | © 2025 RTX
