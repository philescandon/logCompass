#' Log Processing Utility Functions
#'
#' Helper functions for processing MS110 and DB110 log files
#' These wrap aerolog package functions with additional Shiny-specific handling

#' Process MS110 Info Logs with Progress Tracking
#'
#' Wrapper around aerolog::ms110_collectInfoLogs with progress notifications
#'
#' @param source_dirs Character vector of source directories
#' @param output_dir Output directory for processed files
#' @param recursive Logical, search recursively
#' @param clean Logical, clean files before processing
#' @param keep_original Logical, keep original files
#' @param verbose Logical, verbose output
#' @param progress Optional progress object for Shiny
#' @param progress_callback Optional callback function(current, total, file) for progress updates
#' @return Tibble with processing results
process_ms110_batch <- function(source_dirs,
                                 output_dir,
                                 recursive = TRUE,
                                 clean = TRUE,
                                 keep_original = FALSE,
                                 verbose = FALSE,
                                 progress = NULL,
                                 progress_callback = NULL) {

  # Find all info*.log files (including info.log and info_*.log)
  all_files <- c()
  for (dir in source_dirs) {
    files <- list.files(
      path = dir,
      pattern = "^info.*\\.log$",
      recursive = recursive,
      full.names = TRUE
    )
    all_files <- c(all_files, files)
  }

  total_files <- length(all_files)

  if (total_files == 0) {
    message("No info.log files found in specified directories")
    return(tibble::tibble(
      original_path = character(),
      final_path = character(),
      sensor_id = character(),
      epoch = character(),
      mission_id = character(),
      status = character(),
      message = character()
    ))
  }

  if (!is.null(progress_callback)) {
    progress_callback(0, total_files, "Starting...")
  }

  # Process each file individually
  results_list <- list()

  for (i in seq_along(all_files)) {
    file <- all_files[i]

    if (!is.null(progress_callback)) {
      progress_callback(i, total_files, basename(file))
    }

    if (verbose) {
      cat(sprintf("[%d/%d] Processing: %s\n", i, total_files, file))
    }

    tryCatch({
      result <- aerolog::ms110_processRawInfoLog(
        file_path = file,
        output_dir = output_dir,
        clean = clean,
        keep_original = keep_original,
        verbose = verbose
      )

      # Handle different return types from aerolog function
      if (is.list(result)) {
        # Result is a list with components
        final_path <- result$output_path %||% result$final_path %||% NA_character_
        sensor_id <- result$sensor_id %||% NA_character_
        epoch <- result$epoch %||% NA_character_
        mission_id <- result$mission_id %||% NA_character_
      } else if (is.character(result)) {
        # Result is just the output path as a string
        final_path <- result

        # Try to extract metadata from the renamed filename
        # Expected format: info_SENSORID_EPOCH_MISSIONID.log
        filename <- tools::file_path_sans_ext(basename(final_path))
        parts <- strsplit(filename, "_")[[1]]

        if (length(parts) >= 4 && parts[1] == "info") {
          # Format: info_SENSORID_EPOCH_MISSIONID
          sensor_id <- parts[2]
          epoch <- parts[3]
          mission_id <- parts[4]
        } else if (length(parts) >= 3) {
          # Fallback: assume SENSORID_EPOCH_MISSIONID
          sensor_id <- parts[1]
          epoch <- parts[2]
          mission_id <- parts[3]
        } else {
          sensor_id <- NA_character_
          epoch <- NA_character_
          mission_id <- NA_character_
        }
      } else {
        # Unknown return type
        final_path <- NA_character_
        sensor_id <- NA_character_
        epoch <- NA_character_
        mission_id <- NA_character_
      }

      # Validate sensor ID (should be <= 150)
      status_val <- "success"
      message_val <- "Processed successfully"

      if (!is.na(sensor_id) && is.numeric(suppressWarnings(as.numeric(sensor_id)))) {
        sensor_id_num <- as.numeric(sensor_id)
        if (sensor_id_num > 150) {
          status_val <- "warning"
          message_val <- "Sensor ID not found in log file - using fallback naming"
        }
      }

      results_list[[i]] <- tibble::tibble(
        original_path = file,
        final_path = final_path,
        sensor_id = sensor_id,
        epoch = epoch,
        mission_id = mission_id,
        status = status_val,
        message = message_val
      )

      if (verbose) {
        cat(sprintf("  ✓ Success: %s\n", basename(final_path %||% "")))
      }

    }, error = function(e) {
      if (verbose) {
        cat(sprintf("  ✗ ERROR: %s\n", e$message))
      }

      results_list[[i]] <<- tibble::tibble(
        original_path = file,
        final_path = NA_character_,
        sensor_id = NA_character_,
        epoch = NA_character_,
        mission_id = NA_character_,
        status = "error",
        message = e$message
      )
    })
  }

  # Combine all results
  results <- dplyr::bind_rows(results_list)

  return(results)
}


#' Process Single MS110 Info Log
#'
#' Process a single MS110 info.log file
#'
#' @param file_path Path to info.log file
#' @param output_dir Output directory
#' @param clean Logical, clean file before processing
#' @param keep_original Logical, keep original file
#' @return Path to processed file
process_ms110_single <- function(file_path,
                                  output_dir = NULL,
                                  clean = TRUE,
                                  keep_original = FALSE) {

  result <- aerolog::ms110_processRawInfoLog(
    file_path = file_path,
    output_dir = output_dir,
    clean = clean,
    keep_original = keep_original,
    verbose = TRUE
  )

  return(result)
}


#' Process DB110 Error Logs with Progress Tracking
#'
#' Batch process DB110 errorlog.log files with progress notifications
#' Mirrors the MS110 batch processing functionality
#'
#' @param source_dirs Character vector of source directories
#' @param output_dir Output directory for processed files
#' @param recursive Logical, search recursively
#' @param clean Logical, clean files before processing
#' @param keep_original Logical, keep original files
#' @param verbose Logical, verbose output
#' @param progress Optional progress object for Shiny
#' @param progress_callback Optional callback function(current, total, file) for progress updates
#' @return Tibble with processing results
process_db110_batch <- function(source_dirs,
                                 output_dir,
                                 recursive = TRUE,
                                 clean = TRUE,
                                 keep_original = FALSE,
                                 verbose = FALSE,
                                 progress = NULL,
                                 progress_callback = NULL) {

  # Find all error*.log files (including errorlog.log and error_*.log)
  all_files <- c()
  for (dir in source_dirs) {
    files <- list.files(
      path = dir,
      pattern = "error.*\\.log$",
      recursive = recursive,
      full.names = TRUE,
      ignore.case = TRUE
    )
    all_files <- c(all_files, files)
  }

  total_files <- length(all_files)

  if (total_files == 0) {
    message("No errorlog.log files found in specified directories")
    return(tibble::tibble(
      original_path = character(),
      final_path = character(),
      sensor_id = character(),
      epoch = character(),
      mission_id = character(),
      status = character(),
      message = character()
    ))
  }

  if (!is.null(progress_callback)) {
    progress_callback(0, total_files, "Starting...")
  }

  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Process each file individually
  results_list <- list()

  for (i in seq_along(all_files)) {
    file <- all_files[i]

    if (!is.null(progress_callback)) {
      progress_callback(i, total_files, basename(file))
    }

    if (verbose) {
      cat(sprintf("[%d/%d] Processing: %s\n", i, total_files, file))
    }

    tryCatch({
      # Parse the log file to extract metadata
      parsed_log <- aerolog::db110_processLog(file)

      # Extract metadata
      sensor_id <- NA_character_
      epoch <- NA_character_
      mission_id <- NA_character_

      if (!is.null(parsed_log$info)) {
        # Extract sensor ID
        if ("Sensor" %in% names(parsed_log$info)) {
          sensor_id <- as.character(parsed_log$info$Sensor)
        }

        # Extract epoch (use flight date or timestamp)
        if ("FlightDate" %in% names(parsed_log$info)) {
          flight_date <- parsed_log$info$FlightDate
          # Convert to epoch format (YYYYMMDD)
          epoch <- gsub("-", "", as.character(flight_date))
        } else if ("time" %in% names(parsed_log$info_df) && nrow(parsed_log$info_df) > 0) {
          # Use first timestamp as epoch
          first_time <- min(parsed_log$info_df$time, na.rm = TRUE)
          epoch <- format(first_time, "%Y%m%d")
        }

        # Extract mission ID
        if ("Mission Plan" %in% names(parsed_log$info)) {
          mission_id <- as.character(parsed_log$info$`Mission Plan`)
          # Clean mission ID (remove spaces, special characters)
          mission_id <- gsub("[^A-Za-z0-9]", "_", mission_id)
        }
      }

      # Generate output filename
      # Format: DB110_<sensorID>_<epoch>_<missionID>.log
      if (!is.na(sensor_id) && !is.na(epoch)) {
        if (!is.na(mission_id)) {
          output_filename <- sprintf("DB110_%s_%s_%s.log", sensor_id, epoch, mission_id)
        } else {
          output_filename <- sprintf("DB110_%s_%s.log", sensor_id, epoch)
        }
      } else {
        # Fallback: use original filename with DB110 prefix
        output_filename <- paste0("DB110_", basename(file))
      }

      output_path <- file.path(output_dir, output_filename)

      # Read original file
      log_lines <- readLines(file, warn = FALSE)

      # Clean log if requested
      if (clean) {
        # Merge continuation lines
        log_lines <- merge_continuation_lines(log_lines)

        # Fix contractions
        log_lines <- fix_contractions(log_lines)
      }

      # Write processed file
      writeLines(log_lines, output_path)

      # Copy original file if requested
      if (keep_original) {
        original_backup <- file.path(output_dir, paste0("original_", basename(file)))
        file.copy(file, original_backup, overwrite = TRUE)
      }

      results_list[[i]] <- tibble::tibble(
        original_path = file,
        final_path = output_path,
        sensor_id = sensor_id,
        epoch = epoch,
        mission_id = mission_id,
        status = "success",
        message = "Processed successfully"
      )

      if (verbose) {
        cat(sprintf("  ✓ Success: %s\n", basename(output_path)))
      }

    }, error = function(e) {
      if (verbose) {
        cat(sprintf("  ✗ ERROR: %s\n", e$message))
      }

      results_list[[i]] <<- tibble::tibble(
        original_path = file,
        final_path = NA_character_,
        sensor_id = NA_character_,
        epoch = NA_character_,
        mission_id = NA_character_,
        status = "error",
        message = e$message
      )
    })
  }

  # Combine all results
  results <- dplyr::bind_rows(results_list)

  return(results)
}


#' Process Single DB110 Error Log
#'
#' Process a single DB110 errorlog.log file
#'
#' @param file_path Path to errorlog.log file
#' @return List with processed sections
process_db110_single <- function(file_path) {

  result <- aerolog::db110_processLog(file_path)

  return(result)
}


#' Validate Directory Path
#'
#' Check if directory exists and is accessible
#'
#' @param path Directory path to validate
#' @return Logical, TRUE if valid
validate_directory <- function(path) {
  if (is.null(path) || length(path) == 0) {
    return(FALSE)
  }

  if (!dir.exists(path)) {
    return(FALSE)
  }

  # Check if readable
  tryCatch({
    list.files(path, all.files = FALSE)
    TRUE
  }, error = function(e) {
    FALSE
  })
}


#' Format Processing Results for Display
#'
#' Add human-readable columns to processing results
#'
#' @param results Tibble from processing functions
#' @return Enhanced tibble with display columns
format_results_for_display <- function(results) {
  if (is.null(results) || nrow(results) == 0) {
    return(results)
  }

  results |>
    dplyr::mutate(
      status_icon = dplyr::case_when(
        status == "success" ~ "✓",
        TRUE ~ "✗"
      ),
      filename = basename(final_path)
    ) |>
    dplyr::select(status_icon, filename, sensor_id, epoch, mission_id, status, original_path, final_path)
}


#' Merge Continuation Lines
#'
#' Merge lines that are continuations of previous lines (typically indented)
#'
#' @param lines Character vector of log lines
#' @return Character vector with continuation lines merged
merge_continuation_lines <- function(lines) {
  if (length(lines) == 0) {
    return(lines)
  }

  merged <- character()
  current_line <- ""

  for (i in seq_along(lines)) {
    line <- lines[i]

    # Check if line starts with whitespace (continuation)
    if (grepl("^\\s+", line) && current_line != "") {
      # Merge with previous line
      current_line <- paste(current_line, trimws(line))
    } else {
      # Start of new line
      if (current_line != "") {
        merged <- c(merged, current_line)
      }
      current_line <- line
    }
  }

  # Add the last line
  if (current_line != "") {
    merged <- c(merged, current_line)
  }

  return(merged)
}


#' Fix Contractions in Log Text
#'
#' Expand contractions to full words (e.g., "can't" -> "cannot")
#' This helps with consistent parsing
#'
#' @param lines Character vector of log lines
#' @return Character vector with contractions fixed
fix_contractions <- function(lines) {
  if (length(lines) == 0) {
    return(lines)
  }

  # Common contractions map
  contractions <- list(
    "can't" = "cannot",
    "won't" = "will not",
    "don't" = "do not",
    "doesn't" = "does not",
    "didn't" = "did not",
    "isn't" = "is not",
    "aren't" = "are not",
    "wasn't" = "was not",
    "weren't" = "were not",
    "hasn't" = "has not",
    "haven't" = "have not",
    "hadn't" = "had not",
    "shouldn't" = "should not",
    "wouldn't" = "would not",
    "couldn't" = "could not",
    "mightn't" = "might not",
    "mustn't" = "must not"
  )

  # Apply replacements
  fixed_lines <- lines
  for (contraction in names(contractions)) {
    pattern <- paste0("\\b", contraction, "\\b")
    replacement <- contractions[[contraction]]
    fixed_lines <- gsub(pattern, replacement, fixed_lines, ignore.case = TRUE)
  }

  return(fixed_lines)
}
