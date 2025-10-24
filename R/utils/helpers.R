#' General Helper Functions
#'
#' Utility functions for Log Compass application

#' Null-coalescing Operator
#'
#' Return the right-hand side if left-hand side is NULL
#'
#' @param x Value to check for NULL
#' @param y Default value if x is NULL
#' @return x if not NULL, otherwise y
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}


#' Format File Size
#'
#' Convert bytes to human-readable format
#'
#' @param bytes Number of bytes
#' @return Character string with formatted size
format_file_size <- function(bytes) {
  if (is.na(bytes) || bytes < 0) {
    return("Unknown")
  }

  units <- c("B", "KB", "MB", "GB", "TB")
  unit_index <- 1

  size <- bytes
  while (size >= 1024 && unit_index < length(units)) {
    size <- size / 1024
    unit_index <- unit_index + 1
  }

  sprintf("%.2f %s", size, units[unit_index])
}


#' Format Timestamp
#'
#' Convert epoch timestamp to readable datetime
#'
#' @param epoch Epoch timestamp (seconds since 1970-01-01)
#' @return Character string with formatted datetime
format_timestamp <- function(epoch) {
  if (is.na(epoch) || is.null(epoch)) {
    return("Unknown")
  }

  tryCatch({
    dt <- as.POSIXct(as.numeric(epoch), origin = "1970-01-01", tz = "UTC")
    format(dt, "%Y-%m-%d %H:%M:%S UTC")
  }, error = function(e) {
    "Invalid timestamp"
  })
}


#' Get File Count in Directory
#'
#' Count files matching pattern in directory
#'
#' @param path Directory path
#' @param pattern File pattern to match
#' @param recursive Search recursively
#' @return Integer count of files
count_files <- function(path, pattern = NULL, recursive = FALSE) {
  if (!dir.exists(path)) {
    return(0L)
  }

  files <- list.files(path, pattern = pattern, recursive = recursive, full.names = FALSE)
  length(files)
}


#' Create Summary Statistics
#'
#' Generate summary stats from processing results
#'
#' @param results Processing results tibble
#' @return List with summary statistics
create_summary_stats <- function(results) {
  if (is.null(results) || nrow(results) == 0) {
    return(list(
      total = 0,
      success = 0,
      failed = 0,
      success_rate = 0
    ))
  }

  list(
    total = nrow(results),
    success = sum(results$status == "success", na.rm = TRUE),
    failed = sum(results$status != "success", na.rm = TRUE),
    success_rate = round(sum(results$status == "success", na.rm = TRUE) / nrow(results) * 100, 1)
  )
}


#' Safe Directory Creation
#'
#' Create directory if it doesn't exist, with error handling
#'
#' @param path Directory path to create
#' @return Logical, TRUE if successful
safe_create_dir <- function(path) {
  tryCatch({
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE, showWarnings = FALSE)
    }
    TRUE
  }, error = function(e) {
    message("Failed to create directory: ", e$message)
    FALSE
  })
}


#' Extract Unique Sensor IDs
#'
#' Get list of unique sensor IDs from results
#'
#' @param results Processing results tibble
#' @return Character vector of unique sensor IDs
get_unique_sensors <- function(results) {
  if (is.null(results) || nrow(results) == 0) {
    return(character(0))
  }

  unique(results$sensor_id[!is.na(results$sensor_id)])
}


#' Extract Unique Mission IDs
#'
#' Get list of unique mission IDs from results
#'
#' @param results Processing results tibble
#' @return Character vector of unique mission IDs
get_unique_missions <- function(results) {
  if (is.null(results) || nrow(results) == 0) {
    return(character(0))
  }

  unique(results$mission_id[!is.na(results$mission_id)])
}


#' Generate Processing Report
#'
#' Create a text report of processing results
#'
#' @param results Processing results tibble
#' @param sensor_type Type of sensor ("MS110" or "DB110")
#' @return Character string with report text
generate_report_text <- function(results, sensor_type = "MS110") {
  stats <- create_summary_stats(results)
  sensors <- get_unique_sensors(results)
  missions <- get_unique_missions(results)

  report <- sprintf(
    "=== %s Processing Report ===\n\n",
    sensor_type
  )

  report <- paste0(report, sprintf("Total Files: %d\n", stats$total))
  report <- paste0(report, sprintf("Successful: %d (%.1f%%)\n", stats$success, stats$success_rate))
  report <- paste0(report, sprintf("Failed: %d\n\n", stats$failed))

  if (length(sensors) > 0) {
    report <- paste0(report, sprintf("Sensor IDs Found: %s\n", paste(sensors, collapse = ", ")))
  }

  if (length(missions) > 0) {
    report <- paste0(report, sprintf("Mission IDs Found: %s\n", paste(missions, collapse = ", ")))
  }

  report
}
