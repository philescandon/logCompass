#' MS110 Boot Milestone Extraction Functions
#'
#' For MS110 logs, "boot milestones" are key boot sequence events
#' extracted from the full info log tibble (text column)
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-24

#' Extract MS110 Boot Milestones from Log Data
#'
#' Searches log entries for MS110-specific boot sequence patterns
#'
#' @param log_file Character. Path to the MS110 info log file
#' @param info_data Data frame. Full log tibble from ms110_processInfoLog()$info (with text column)
#' @param maint_log Data frame. Maintenance log (may be NULL for MS110)
#' @param sbit_section Data frame. SBIT section from ms110_processInfoLog()$sbitSection
#'
#' @return Data frame with columns: milestone, timestamp, value, status
#'
#' @examples
#' milestones <- extract_ms110_boot_milestones(log_file, info_data, maint_log, sbit_section)
extract_ms110_boot_milestones <- function(log_file, info_data, maint_log = NULL, sbit_section = NULL) {

  milestones <- data.frame(
    milestone = character(),
    timestamp = as.POSIXct(character()),
    value = character(),
    status = character(),
    stringsAsFactors = FALSE
  )

  # Return early if no data
  if (is.null(info_data) || !is.data.frame(info_data) || nrow(info_data) == 0) {
    return(milestones)
  }

  # Helper function to add milestones
  add_milestone <- function(name, data_row, val = NA) {
    if (nrow(data_row) > 0) {
      timestamp <- if ("time2" %in% names(data_row)) {
        data_row$time2[1]
      } else if ("time" %in% names(data_row)) {
        data_row$time[1]
      } else {
        NA
      }

      milestones <<- rbind(milestones, data.frame(
        milestone = name,
        timestamp = timestamp,
        value = ifelse(is.na(val), NA_character_, as.character(val)),
        status = "PASS",
        stringsAsFactors = FALSE
      ))
    }
  }

  # Extract milestones from the full info tibble (text column)
  if ("text" %in% names(info_data)) {

    # 1. System Power-On (first timestamped entry)
    if ("time2" %in% names(info_data) || "time" %in% names(info_data)) {
      add_milestone("System Power-On", info_data[1, , drop = FALSE])
    }

    # 2. ABSW Version
    absw_rows <- info_data[!is.na(info_data$text) &
                          grepl("ABSW|software version|SW version", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(absw_rows) > 0) {
      add_milestone("ABSW Version Detected", absw_rows[1, , drop = FALSE])
    }

    # 3. Sensor Initialization
    sensor_rows <- info_data[!is.na(info_data$text) &
                            grepl("sensor.*init|initializing.*sensor|sensor.*start", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(sensor_rows) > 0) {
      add_milestone("Sensor Initialization", sensor_rows[1, , drop = FALSE])
    }

    # 4. Mission Plan Loaded
    mission_rows <- info_data[!is.na(info_data$text) &
                             grepl("mission.*plan|loading.*mission|mission.*loaded", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(mission_rows) > 0) {
      add_milestone("Mission Plan Loaded", mission_rows[1, , drop = FALSE])
    }

    # 5. EO Focal Plane
    eo_rows <- info_data[!is.na(info_data$text) &
                        grepl("EO.*focal.*plane|EOFPA|EO.*ready", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(eo_rows) > 0) {
      add_milestone("EO Focal Plane Ready", eo_rows[1, , drop = FALSE])
    }

    # 6. IR Focal Plane
    ir_rows <- info_data[!is.na(info_data$text) &
                        grepl("IR.*focal.*plane|IRFPA|IR.*ready", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(ir_rows) > 0) {
      add_milestone("IR Focal Plane Ready", ir_rows[1, , drop = FALSE])
    }

    # 7. System Ready
    ready_rows <- info_data[!is.na(info_data$text) &
                           grepl("system.*ready|operational|ready.*for.*mission", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(ready_rows) > 0) {
      add_milestone("System Ready", ready_rows[1, , drop = FALSE])
    }

    # 8. Mission Start
    start_rows <- info_data[!is.na(info_data$text) &
                           grepl("mission.*start|start.*mission|beginning.*mission", info_data$text, ignore.case = TRUE), , drop = FALSE]
    if (nrow(start_rows) > 0) {
      add_milestone("Mission Start", start_rows[1, , drop = FALSE])
    }
  }

  # 9-11. SBIT milestones from sbit_section
  if (!is.null(sbit_section) && is.data.frame(sbit_section) && nrow(sbit_section) > 0) {
    if ("text" %in% names(sbit_section)) {
      # Extract unique tests from sbit_section using extract_sbit_tests
      sbit_tests <- sbit_section %>%
        filter(grepl('TID.*status', text, ignore.case = TRUE)) %>%
        mutate(
          Name = stringr::str_extract(text, stringr::regex("(?<=node name = )\\w+", ignore_case = TRUE)),
          TID = stringr::str_extract(text, stringr::regex("(?<=TID = )[^,]+", ignore_case = TRUE))
        ) %>%
        filter(!is.na(Name) & !is.na(TID))

      # Count unique test combinations (Name + TID), excluding INS tests
      unique_tests <- sbit_tests %>%
        mutate(test_id = paste(Name, TID, sep = "_")) %>%
        filter(!grepl("^INS_", test_id)) %>%
        select(Name, TID) %>%
        distinct() %>%
        nrow()

      if ("time2" %in% names(sbit_section)) {
        sbit_times <- sbit_section$time2[!is.na(sbit_section$time2)]
        if (length(sbit_times) > 0 && unique_tests > 0) {
          # SBIT Start
          milestones <- rbind(milestones, data.frame(
            milestone = "SBIT Start",
            timestamp = min(sbit_times, na.rm = TRUE),
            value = paste(unique_tests, "tests"),
            status = "PASS",
            stringsAsFactors = FALSE
          ))
        }
      }
    }

    # SHA Validation Errors
    # Pattern: 'SHA Validation Results: 0 errors' in sbit_section text column
    # PASS if errors = 0, FAIL if errors > 0
    if ("text" %in% names(sbit_section)) {
      sha_validation <- sbit_section %>%
        filter(!is.na(text) & grepl("SHA Validation Results:", text, ignore.case = TRUE)) %>%
        slice(1)

      if (nrow(sha_validation) > 0) {
        # Extract number of errors from text like "SHA Validation Results: 0 errors"
        error_match <- stringr::str_match(sha_validation$text[1], "SHA Validation Results:\\s*(\\d+)")
        error_count <- if (!is.na(error_match[1,2])) as.integer(error_match[1,2]) else NA

        if (!is.na(error_count)) {
          validation_status <- ifelse(error_count == 0, "PASS", "FAIL")
          validation_value <- paste0(error_count, " errors")

          milestones <- rbind(milestones, data.frame(
            milestone = "Validation Errors",
            timestamp = sha_validation$time2[1],
            value = validation_value,
            status = validation_status,
            stringsAsFactors = FALSE
          ))
        }
      }
    }

    # SBIT Complete
    if ("time2" %in% names(sbit_section)) {
      sbit_times <- sbit_section$time2[!is.na(sbit_section$time2)]
      if (length(sbit_times) > 0 && exists("unique_tests") && unique_tests > 0) {
        # Use the same unique_tests count from SBIT Start
        milestones <- rbind(milestones, data.frame(
          milestone = "SBIT Complete",
          timestamp = max(sbit_times, na.rm = TRUE),
          value = paste(unique_tests, "tests"),
          status = "PASS",
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Fallback: if no milestones found, at least show log was parsed
  if (nrow(milestones) == 0 && nrow(info_data) > 0) {
    add_milestone("Log File Parsed", info_data[1, , drop = FALSE])
  }

  return(milestones)
}
