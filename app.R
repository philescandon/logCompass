#!/usr/bin/env Rscript
#' Log Compass - Aerospace Log File Processing Tool
#'
#' Main entry point for Log Compass, part of the Compass Suite.
#' Navigate and process MS110 and DB110 log files with automated renaming,
#' cleaning, and batch processing capabilities.
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-23
#'
#' Usage:
#'   Rscript app.R
#'   Or from R console: shiny::runApp('app.R')
#'
#' Architecture:
#'   - R/ui.R: User interface definition
#'   - R/server.R: Server logic
#'   - R/utils/processing.R: Log file processing functions
#'   - R/utils/helpers.R: Helper functions and utilities

# ===========================================================================
# PACKAGE LOADING
# ===========================================================================

# Check and load required packages
required_packages <- c(
  "shiny", "shinyFiles", "DT", "bslib", "htmltools",
  "dplyr", "tidyr", "tibble", "stringr", "readr", "purrr",
  "tidytext",  # For sentiment analysis in raw log display
  "aerolog"  # Core package for MS110 and DB110 processing
)

# Function to check if packages are installed
check_packages <- function(pkgs) {
  missing <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }

  # Load all required packages
  invisible(lapply(pkgs, library, character.only = TRUE, quietly = TRUE))
}

# Check and load all packages
check_packages(required_packages)

# ===========================================================================
# SOURCE UTILITY FUNCTIONS
# ===========================================================================

# Source helper functions for log processing
source("R/utils/processing.R", local = TRUE)
cat("✓ Loaded log processing functions\n")

# Source general helper functions
source("R/utils/helpers.R", local = TRUE)
cat("✓ Loaded helper functions\n")

# ===========================================================================
# SOURCE UI AND SERVER
# ===========================================================================

# Source UI definition
source("R/ui.R", local = TRUE)
cat("✓ Loaded UI definition\n")

# Source server logic
source("R/server.R", local = TRUE)
cat("✓ Loaded server logic\n")

# ===========================================================================
# LAUNCH APPLICATION
# ===========================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════\n")
cat(" Log Compass - Compass Suite\n")
cat(" Navigate and Process Aerospace Sensor Log Files\n")
cat(" Launching Shiny application...\n")
cat("═══════════════════════════════════════════════════════\n")
cat("\n")

# Run the Shiny app
shinyApp(ui = ui, server = server)
