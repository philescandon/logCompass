#' Log Type Detection Utilities
#'
#' Functions for automatically detecting log type (MS110 vs DB110) from
#' filenames and file content.
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-23

#' Detect log type from filename
#'
#' Primary detection strategy using filename patterns.
#' MS110 logs contain "info" in filename (info.log)
#' DB110 logs contain "error" in filename (errorlog.log)
#'
#' @param filename Character string with file path or filename
#' @return Character string: "MS110" or "DB110" or NULL if cannot detect
#' @export
#' @examples
#' detect_log_type("info.log")  # Returns "MS110"
#' detect_log_type("errorlog.log")  # Returns "DB110"
#' detect_log_type("MS110_12345_epoch_mission.log")  # Returns "MS110"
detect_log_type <- function(filename) {
  if (is.null(filename) || length(filename) == 0 || filename == "") {
    return(NULL)
  }

  # Extract basename and convert to lowercase
  filename_lower <- tolower(basename(filename))

  # Check for MS110 indicators (info, MS110)
  if (grepl("info", filename_lower) || grepl("ms110", filename_lower)) {
    return("MS110")
  }

  # Check for DB110 indicators (error, DB110)
  if (grepl("error", filename_lower) || grepl("db110", filename_lower)) {
    return("DB110")
  }

  # Fallback: try reading file content
  if (file.exists(filename)) {
    return(detect_log_type_from_content(filename))
  }

  # Cannot detect
  return(NULL)
}


#' Detect log type from file content
#'
#' Fallback detection strategy that reads the first 100 lines of the file
#' and searches for "MS110" or "DB110" strings.
#'
#' @param filepath Character string with full path to file
#' @return Character string: "MS110" or "DB110" or NULL if cannot detect
#' @export
detect_log_type_from_content <- function(filepath) {
  if (!file.exists(filepath)) {
    return(NULL)
  }

  tryCatch({
    # Read first 100 lines (enough to find system identifier)
    lines <- readLines(filepath, n = 100, warn = FALSE)
    content <- paste(lines, collapse = " ")

    # Search for MS110 identifier
    if (grepl("MS110", content, ignore.case = TRUE)) {
      return("MS110")
    }

    # Search for DB110 identifier
    if (grepl("DB110", content, ignore.case = TRUE)) {
      return("DB110")
    }

    # Check for "info.log" style patterns in header
    if (grepl("info log", content, ignore.case = TRUE)) {
      return("MS110")
    }

    # Check for "error log" patterns in header
    if (grepl("error log", content, ignore.case = TRUE)) {
      return("DB110")
    }

    return(NULL)
  }, error = function(e) {
    warning(paste("Error reading file for log type detection:", e$message))
    return(NULL)
  })
}


#' Detect log types for multiple files
#'
#' Batch detect log types for a vector of filenames.
#' Useful for validating that all files in a selection are the same type.
#'
#' @param filenames Character vector of file paths
#' @return Data frame with columns: filename, log_type
#' @export
#' @examples
#' files <- c("info.log", "errorlog.log", "MS110_12345.log")
#' detect_log_types_batch(files)
detect_log_types_batch <- function(filenames) {
  if (length(filenames) == 0) {
    return(data.frame(filename = character(0), log_type = character(0)))
  }

  results <- data.frame(
    filename = filenames,
    log_type = sapply(filenames, detect_log_type, USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )

  return(results)
}


#' Validate that all files are the same log type
#'
#' Checks that all files in a vector are either all MS110 or all DB110.
#' Used to prevent mixing MS110 and DB110 files in analysis.
#'
#' @param filenames Character vector of file paths
#' @return List with: valid (logical), log_type (character), message (character)
#' @export
#' @examples
#' files <- c("info.log", "info2.log")
#' validate_log_type_consistency(files)  # valid=TRUE, log_type="MS110"
#'
#' mixed_files <- c("info.log", "errorlog.log")
#' validate_log_type_consistency(mixed_files)  # valid=FALSE
validate_log_type_consistency <- function(filenames) {
  if (length(filenames) == 0) {
    return(list(
      valid = FALSE,
      log_type = NULL,
      message = "No files provided"
    ))
  }

  # Detect all log types
  log_types <- sapply(filenames, detect_log_type, USE.NAMES = FALSE)

  # Remove NULLs and NAs
  log_types <- log_types[!is.na(log_types) & !is.null(log_types)]

  if (length(log_types) == 0) {
    return(list(
      valid = FALSE,
      log_type = NULL,
      message = "Could not detect log type for any files"
    ))
  }

  # Get unique types
  unique_types <- unique(log_types)

  if (length(unique_types) > 1) {
    return(list(
      valid = FALSE,
      log_type = NULL,
      message = paste(
        "Mixed log types detected:",
        paste(unique_types, collapse = " and "),
        "\nMS110 and DB110 logs cannot be analyzed together."
      )
    ))
  }

  return(list(
    valid = TRUE,
    log_type = unique_types[1],
    message = paste("All files are", unique_types[1], "logs")
  ))
}


#' Get log type display information
#'
#' Returns display-friendly information about a log type including
#' color, icon, and full name.
#'
#' @param log_type Character string: "MS110" or "DB110"
#' @return List with: name, full_name, color, icon
#' @export
get_log_type_display_info <- function(log_type) {
  if (is.null(log_type) || is.na(log_type)) {
    return(list(
      name = "Unknown",
      full_name = "Unknown Log Type",
      color = "#666666",
      icon = "question-circle"
    ))
  }

  if (log_type == "MS110") {
    return(list(
      name = "MS110",
      full_name = "MS110 Info Log",
      color = "#0066CC",
      icon = "file-lines",
      file_pattern = "info.*\\.log"
    ))
  } else if (log_type == "DB110") {
    return(list(
      name = "DB110",
      full_name = "DB110 Error Log",
      color = "#CC6600",
      icon = "triangle-exclamation",
      file_pattern = "error.*\\.log"
    ))
  } else {
    return(list(
      name = log_type,
      full_name = paste(log_type, "Log"),
      color = "#666666",
      icon = "file"
    ))
  }
}
