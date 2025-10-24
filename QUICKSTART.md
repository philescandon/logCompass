# Log Compass - Quick Start Guide

Get up and running with Log Compass in 5 minutes!

## Prerequisites

1. **R installed** (version 4.1.0 or higher recommended)
2. **RStudio** (optional but recommended)
3. **aerolog package** installed

## Step 1: Install aerolog Package

```r
# Install aerolog from local source
devtools::install("D:/RPackage/aerolog")

# Verify installation
library(aerolog)
```

## Step 2: Install Shiny Dependencies

```r
# Install required packages (if not already installed)
install.packages(c(
  "shiny", "shinyFiles", "DT", "bslib",
  "dplyr", "tidyr", "stringr", "purrr"
))
```

## Step 3: Launch Log Compass

### From RStudio:
1. Open `D:/R_Shiny/logCompass/app.R` in RStudio
2. Click the "Run App" button (top right of editor)
3. App opens in browser or RStudio Viewer

### From R Console:
```r
shiny::runApp("D:/R_Shiny/logCompass")
```

### From Command Line:
```bash
cd D:/R_Shiny/logCompass
Rscript app.R
```

## Step 4: Process Your First Logs

### For MS110 Info Logs:

1. **Click the "MS110 Info Logs" tab**

2. **Select Source Directory**
   - Click "Select Source Directory" button
   - Navigate to folder with your `info.log` files
   - Example: `D:/OrganizingLogData/ForPhilElogs/`

3. **Select Output Directory**
   - Click "Select Output Directory" button
   - Choose where processed files should go
   - Example: `D:/OrganizingLogData/renamedLogFiles/`

4. **Configure Options** (recommended defaults):
   - ✅ Search subdirectories recursively
   - ✅ Clean log files
   - ❌ Keep original files
   - ❌ Verbose output (enable for troubleshooting)

5. **Click "Process MS110 Logs"**
   - Wait for processing to complete
   - View results in the Results Table tab
   - Check Summary Statistics for success/failure counts

6. **Review Results**
   - **Results Table**: See all processed files with extracted metadata
   - **Processing Log**: View detailed processing messages
   - **Summary Statistics**: Quick success/failure overview

7. **Export Results** (optional)
   - Click "CSV" or "Excel" button in Results Table
   - Save processing report for records

## Example Processing Session

```r
# Your source directory might look like:
D:/Missions/
├── 2025-01-15/
│   └── info.log          # Raw MS110 log
├── 2025-01-16/
│   └── info.log          # Raw MS110 log
└── 2025-01-17/
    └── info.log          # Raw MS110 log

# After processing, output directory contains:
D:/ProcessedLogs/
├── info_12_1737022006_Mission1.log
├── info_12_1737108406_Mission2.log
└── info_12_1737194806_Mission3.log
```

## Common Issues & Solutions

### Issue: "No directory selected"
**Solution**: Make sure you click the directory selection button and choose a valid path

### Issue: "No files found"
**Solution**:
- Verify `info.log` files exist in source directory
- Enable "Search subdirectories" if logs are nested
- Check file naming (case-sensitive on Linux)

### Issue: Sensor ID shows hash (e.g., "1607") instead of actual ID
**Solution**:
- Update aerolog package to v1.0.0+
- `devtools::install("D:/RPackage/aerolog")`
- Restart R session: `.rs.restartR()`

### Issue: App won't launch
**Solution**:
```r
# Check package installation
library(shiny)
library(aerolog)

# Check for errors
traceback()

# Try verbose launch
options(shiny.trace = TRUE)
shiny::runApp("D:/R_Shiny/logCompass")
```

## Next Steps

- Read the [README.md](README.md) for detailed documentation
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Process DB110 logs (coming soon!)
- Explore other [Compass Suite](../compass-suite-strategy.md) apps

## Need Help?

Contact: **Phillip Escandon** (Phillip.Escandon@pm.me)

---

**Happy Log Processing! 🧭**
