#' Analysis Mode Detection Utilities
#'
#' Functions for detecting analysis mode (Single Pod vs Multi-Pod Fleet)
#' based on sensor IDs extracted from filenames or file content.
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-23

library(stringr)

#' Extract sensor ID from processed filename
#'
#' Extracts sensor ID from renamed log files using the pattern:
#' MS110_<sensorID>_<epoch>_<missionID>.log
#' DB110_<sensorID>_<epoch>_<missionID>.log
#'
#' @param filename Character string with file path or filename
#' @return Character string with sensor ID or NULL if not found
#' @export
#' @examples
#' extract_sensor_id_from_filename("MS110_12345_20250123_MISSION_A.log")  # Returns "12345"
#' extract_sensor_id_from_filename("DB110_67890_20250125_TEST_B.log")  # Returns "67890"
extract_sensor_id_from_filename <- function(filename) {
  if (is.null(filename) || length(filename) == 0 || filename == "") {
    return(NULL)
  }

  # Extract basename
  base_name <- basename(filename)

  # Pattern: MS110_<sensorID>_... or DB110_<sensorID>_...
  pattern <- "^(MS110|DB110)_([^_]+)_"
  match <- str_match(base_name, pattern)

  if (!is.na(match[1]) && !is.na(match[3])) {
    return(match[3])
  }

  # Fallback: try to extract from file content
  if (file.exists(filename)) {
    return(extract_sensor_id_from_content(filename))
  }

  return(NULL)
}


#' Extract sensor ID from file content
#'
#' Reads log file and extracts sensor ID from metadata sections.
#' Works with both MS110 and DB110 log formats.
#'
#' @param filepath Character string with full path to file
#' @return Character string with sensor ID or NULL if not found
#' @export
extract_sensor_id_from_content <- function(filepath) {
  if (!file.exists(filepath)) {
    return(NULL)
  }

  tryCatch({
    # Try using aerolog/db110/ms110 packages if available
    log_type <- detect_log_type(filepath)

    if (!is.null(log_type) && log_type == "DB110") {
      # Try DB110 parsing
      if (requireNamespace("aerolog", quietly = TRUE)) {
        log_data <- aerolog::db110_processLog(filepath)
        if (!is.null(log_data$info) && "Sensor" %in% names(log_data$info)) {
          sensor_id <- log_data$info$Sensor
          if (!is.na(sensor_id) && sensor_id != "") {
            return(as.character(sensor_id))
          }
        }
      }
    } else if (!is.null(log_type) && log_type == "MS110") {
      # Try MS110 parsing
      if (requireNamespace("aerolog", quietly = TRUE)) {
        log_data <- aerolog::ms110_readInfoLog(filepath)
        if (!is.null(log_data$info) && "Sensor" %in% names(log_data$info)) {
          sensor_id <- log_data$info$Sensor
          if (!is.na(sensor_id) && sensor_id != "") {
            return(as.character(sensor_id))
          }
        }
      }
    }

    # Fallback: manual search in first 200 lines
    lines <- readLines(filepath, n = 200, warn = FALSE)

    # Search for sensor ID patterns
    # Common patterns: "Sensor: XXXXX", "Sensor ID: XXXXX", "SensorID: XXXXX"
    for (line in lines) {
      # Pattern 1: "Sensor: <ID>"
      match <- str_match(line, "Sensor:\\s+([A-Za-z0-9]+)")
      if (!is.na(match[1]) && !is.na(match[2])) {
        return(match[2])
      }

      # Pattern 2: "Sensor ID: <ID>"
      match <- str_match(line, "Sensor\\s+ID:\\s+([A-Za-z0-9]+)")
      if (!is.na(match[1]) && !is.na(match[2])) {
        return(match[2])
      }

      # Pattern 3: "SensorID: <ID>"
      match <- str_match(line, "SensorID:\\s+([A-Za-z0-9]+)")
      if (!is.na(match[1]) && !is.na(match[2])) {
        return(match[2])
      }
    }

    return(NULL)
  }, error = function(e) {
    warning(paste("Error extracting sensor ID from content:", e$message))
    return(NULL)
  })
}


#' Extract sensor IDs from multiple files
#'
#' Batch extract sensor IDs from a vector of filenames.
#'
#' @param filenames Character vector of file paths
#' @return Data frame with columns: filename, sensor_id
#' @export
extract_sensor_ids_batch <- function(filenames) {
  if (length(filenames) == 0) {
    return(data.frame(filename = character(0), sensor_id = character(0)))
  }

  results <- data.frame(
    filename = filenames,
    sensor_id = sapply(filenames, extract_sensor_id_from_filename, USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )

  return(results)
}


#' Detect analysis mode based on sensor IDs
#'
#' Determines whether files should be analyzed in Single Pod mode (all same sensor)
#' or Multi-Pod Fleet mode (multiple sensors).
#'
#' @param filenames Character vector of file paths
#' @return List with components:
#'   - mode: "single_pod" or "multi_pod"
#'   - sensors: Vector of unique sensor IDs
#'   - sensor_count: Number of unique sensors
#'   - display_label: User-friendly label for display
#'   - display_color: Color for mode badge
#'   - display_icon: Icon for mode badge
#' @export
#' @examples
#' # Single sensor
#' files1 <- c("MS110_12345_...", "MS110_12345_...")
#' detect_analysis_mode(files1)  # mode = "single_pod"
#'
#' # Multiple sensors
#' files2 <- c("DB110_12345_...", "DB110_67890_...")
#' detect_analysis_mode(files2)  # mode = "multi_pod"
detect_analysis_mode <- function(filenames) {
  if (length(filenames) == 0) {
    return(list(
      mode = NULL,
      sensors = character(0),
      sensor_count = 0,
      display_label = "No files selected",
      display_color = "#666666",
      display_icon = "question-circle"
    ))
  }

  # Extract sensor IDs from all files
  sensor_ids <- sapply(filenames, extract_sensor_id_from_filename, USE.NAMES = FALSE)

  # Remove NULLs and NAs
  sensor_ids <- sensor_ids[!is.na(sensor_ids) & !is.null(sensor_ids)]

  # Get unique sensors
  unique_sensors <- unique(sensor_ids)

  # Determine mode
  if (length(unique_sensors) == 0) {
    # Could not extract sensor IDs - default to multi-pod
    return(list(
      mode = "unknown",
      sensors = character(0),
      sensor_count = 0,
      display_label = "Unable to determine sensor IDs",
      display_color = "#666666",
      display_icon = "question-circle"
    ))
  } else if (length(unique_sensors) == 1) {
    # Single Pod Mode
    return(list(
      mode = "single_pod",
      sensors = unique_sensors,
      sensor_count = 1,
      display_label = paste("Single Pod Analysis - Sensor:", unique_sensors),
      display_subtitle = "Temporal Trend Analysis",
      display_color = "#0066CC",
      display_icon = "bullseye"
    ))
  } else {
    # Multi-Pod Fleet Mode
    return(list(
      mode = "multi_pod",
      sensors = unique_sensors,
      sensor_count = length(unique_sensors),
      display_label = paste("Multi-Pod Fleet Analysis -", length(unique_sensors), "sensors"),
      display_subtitle = paste("Sensors:", paste(unique_sensors, collapse = ", ")),
      display_color = "#28a745",
      display_icon = "layer-group"
    ))
  }
}


#' Create mode badge HTML
#'
#' Generates HTML for displaying the analysis mode badge in the UI.
#'
#' @param mode_info List returned from detect_analysis_mode()
#' @return HTML string for mode badge
#' @export
create_mode_badge_html <- function(mode_info) {
  if (is.null(mode_info$mode) || mode_info$mode == "unknown") {
    return("")
  }

  # Badge icon
  icon_html <- sprintf('<i class="fa fa-%s" style="margin-right: 8px;"></i>', mode_info$display_icon)

  # Badge HTML
  badge_html <- sprintf(
    '<div style="background-color: %s; color: white; padding: 12px 20px; border-radius: 8px; margin: 15px 0; text-align: center; font-size: 16px; font-weight: bold; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
      %s%s
      <div style="font-size: 12px; font-weight: normal; margin-top: 5px; opacity: 0.9;">%s</div>
    </div>',
    mode_info$display_color,
    icon_html,
    mode_info$display_label,
    mode_info$display_subtitle
  )

  return(badge_html)
}


#' Get mode-specific analysis configuration
#'
#' Returns configuration settings that differ between Single Pod and Fleet modes.
#'
#' @param mode Character string: "single_pod" or "multi_pod"
#' @return List with configuration options for the specified mode
#' @export
get_mode_config <- function(mode) {
  if (mode == "single_pod") {
    return(list(
      focus = "temporal",
      patterns_emphasis = c("temporal_trends", "degradation", "test_variability"),
      recommendations_emphasis = c("maintenance", "historical_anomalies"),
      grouping_variable = "date",
      report_title_suffix = "Temporal Analysis"
    ))
  } else if (mode == "multi_pod") {
    return(list(
      focus = "comparative",
      patterns_emphasis = c("sensor_comparison", "fleet_trends", "systematic_issues"),
      recommendations_emphasis = c("fleet_issues", "sensor_ranking", "standardization"),
      grouping_variable = "sensor",
      report_title_suffix = "Fleet Analysis"
    ))
  } else {
    return(list(
      focus = "general",
      patterns_emphasis = c("basic_statistics"),
      recommendations_emphasis = c("general"),
      grouping_variable = "file",
      report_title_suffix = "Analysis"
    ))
  }
}


#' Validate files for analysis mode
#'
#' Checks that files are suitable for the specified analysis mode.
#' For single_pod mode, ensures all files are from the same sensor.
#'
#' @param filenames Character vector of file paths
#' @param expected_mode Character string: "single_pod" or "multi_pod"
#' @return List with: valid (logical), message (character)
#' @export
validate_mode_consistency <- function(filenames, expected_mode) {
  mode_info <- detect_analysis_mode(filenames)

  if (mode_info$mode == expected_mode) {
    return(list(
      valid = TRUE,
      message = paste("Files are valid for", expected_mode, "mode")
    ))
  } else {
    return(list(
      valid = FALSE,
      message = paste(
        "File selection mismatch:",
        "\nExpected:", expected_mode,
        "\nDetected:", mode_info$mode,
        "\n\nPlease adjust your file selection."
      )
    ))
  }
}
