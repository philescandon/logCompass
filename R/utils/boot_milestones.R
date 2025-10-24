#' Boot Milestone Extraction Functions
#'
#' Functions for extracting and analyzing boot sequence milestones from DB110 errorlog files
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-19

library(dplyr)
library(stringr)

#' Extract Boot Milestones from Log File
#'
#' Identifies 10 key boot milestones with timestamps to track system startup performance
#'
#' @param log_file Character. Path to the errorlog file
#' @param info_data Data frame. Full info data from processInfoLog()$info
#' @param maint_log Data frame. Maintenance log from processInfoLog()$maintLog
#' @param sbit_section Data frame. SBIT section from processInfoLog()$sbitSection
#'
#' @return Data frame with columns: milestone, timestamp, value, status
#'
#' @examples
#' milestones <- extract_boot_milestones(log_file, info_data, maint_log, sbit_section)
extract_boot_milestones <- function(log_file, info_data, maint_log = NULL, sbit_section = NULL) {

  milestones <- data.frame(
    milestone = character(),
    timestamp = as.POSIXct(character()),
    value = character(),
    status = character(),
    stringsAsFactors = FALSE
  )

  # Milestone 1: RSM Startup
  # Pattern: 'TR_Low Starting up the RSM' controller.c 906 startupRsm
  rsm_startup <- info_data %>%
    filter(grepl("TR_Low Starting up the RSM", text, ignore.case = TRUE)) %>%
    filter(grepl("startupRsm", fx, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(rsm_startup) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "RSM Startup",
      timestamp = rsm_startup$time2[1],
      value = NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 2: Time Synchronization (TSY) - from maintenance log
  # Pattern: TSY|122 1724225887 (with or without TR_Rare prefix)
  if (!is.null(maint_log) && is.data.frame(maint_log) && nrow(maint_log) > 0) {
    tsy <- maint_log %>%
      filter(grepl("TSY\\|", text, ignore.case = TRUE)) %>%
      slice(1)

    if (nrow(tsy) > 0) {
      milestones <- rbind(milestones, data.frame(
        milestone = "Time Sync (TSY)",
        timestamp = tsy$time2[1],
        value = NA,
        status = "PASS",
        stringsAsFactors = FALSE
      ))
    }
  }

  # Milestone 3: SCU Communication
  scu_comms <- info_data %>%
    filter(grepl("Established communications with the SCU", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(scu_comms) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "SCU Comms",
      timestamp = scu_comms$time2[1],
      value = NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 4: DTM Power Up
  dtm_power <- info_data %>%
    filter(grepl("DTM is powered up and disk mounted", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(dtm_power) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "DTM Power Up",
      timestamp = dtm_power$time2[1],
      value = NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 5: INS Power Up
  ins_power <- info_data %>%
    filter(grepl("INS is powered up", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(ins_power) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "INS Power Up",
      timestamp = ins_power$time2[1],
      value = NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 6: SSR Power Up
  ssr_ready <- info_data %>%
    filter(grepl("SSR SystemState changed from TUFSRV_NOTREADY to TUFSRV_READY", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(ssr_ready) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "SSR Power Up",
      timestamp = ssr_ready$time2[1],
      value = NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 7: SBIT Start
  sbit_start <- info_data %>%
    filter(grepl('bitRunSbit: running SBIT on "Pod", run level = "Sru"', text, fixed = TRUE)) %>%
    slice(1)

  if (nrow(sbit_start) > 0) {
    milestones <- rbind(milestones, data.frame(
      milestone = "SBIT Start",
      timestamp = sbit_start$time2[1],
      value = "Sru Level",
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 8: IRFPA Temp Acq
  irfpa_temp <- info_data %>%
    filter(grepl("MLV\\|.*\\|MwirFpa\\.Cooler\\|IR Cooler Temp\\. in degK", text)) %>%
    slice(1)

  if (nrow(irfpa_temp) > 0) {
    # Extract temperature value from MLV entry
    temp_match <- str_match(irfpa_temp$text[1], "\\|(\\d+\\.\\d+),")
    temp_value <- ifelse(!is.na(temp_match[1,2]), paste0(temp_match[1,2], " K"), "N/A")
    # Temperature must be > 0 to pass
    temp_numeric <- if (!is.na(temp_match[1,2])) as.numeric(temp_match[1,2]) else 0
    temp_status <- ifelse(temp_numeric > 0, "PASS", "FAIL")

    milestones <- rbind(milestones, data.frame(
      milestone = "IRFPA Temp Acq",
      timestamp = irfpa_temp$time2[1],
      value = temp_value,
      status = temp_status,
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 9: SBIT Complete
  # Find the last SBIT test or bitInProg=0 marker
  sbit_complete_time <- NA
  sbit_test_count <- NA

  if (!is.null(sbit_section) && is.data.frame(sbit_section) && nrow(sbit_section) > 0) {
    # Get last SBIT test result (last row with TID and status)
    last_sbit_test <- sbit_section %>%
      filter(grepl('TID.*status', text, ignore.case = TRUE)) %>%
      slice(n())

    if (nrow(last_sbit_test) > 0) {
      sbit_complete_time <- last_sbit_test$time2[1]

      # Count total SBIT tests
      sbit_test_count <- sbit_section %>%
        filter(grepl('TID.*status', text, ignore.case = TRUE)) %>%
        nrow()
    }
  }

  # Alternatively, look for bitInProg=0 (SBIT completion marker)
  if (is.na(sbit_complete_time)) {
    bit_done <- info_data %>%
      filter(grepl("bitInProg=0", text, ignore.case = TRUE)) %>%
      slice(1)

    if (nrow(bit_done) > 0) {
      sbit_complete_time <- bit_done$time2[1]
    }
  }

  if (!is.na(sbit_complete_time)) {
    milestones <- rbind(milestones, data.frame(
      milestone = "SBIT Complete",
      timestamp = sbit_complete_time,
      value = if (!is.na(sbit_test_count)) paste0(sbit_test_count, " tests") else NA,
      status = "PASS",
      stringsAsFactors = FALSE
    ))
  }

  # Milestone 10: System Ready
  # LOGIC: System Ready is PASS if ALL captured milestones passed (no specific requirements)
  system_ready <- info_data %>%
    filter(grepl("State changing event = READY", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(system_ready) > 0) {
    # Check if all captured milestones passed (handle NA values)
    all_passed <- if (nrow(milestones) > 0) {
      # Remove NA values first, then check if all are PASS
      status_values <- milestones$status[!is.na(milestones$status)]
      length(status_values) > 0 && all(status_values == "PASS")
    } else {
      FALSE
    }

    system_status <- ifelse(all_passed, "PASS", "FAIL")

    milestones <- rbind(milestones, data.frame(
      milestone = "System Ready",
      timestamp = system_ready$time2[1],
      value = NA,
      status = system_status,
      stringsAsFactors = FALSE
    ))
  }

  # Extract STU and SHD for flight time calculation
  stu_seconds <- NA
  stu_epoch <- NA
  shd_seconds <- NA
  flight_time_seconds <- NA

  if (!is.null(maint_log) && is.data.frame(maint_log) && nrow(maint_log) > 0) {
    # STU (Startup) - extract seconds after power applied and epoch timestamp
    # Pattern: STU|175 (with or without TR_Rare prefix)
    stu_entry <- maint_log %>%
      filter(grepl("STU\\|", text, ignore.case = TRUE)) %>%
      slice(1)

    if (nrow(stu_entry) > 0) {
      # Extract number after STU|
      stu_match <- str_match(stu_entry$text[1], "STU\\|(\\d+)")
      if (!is.na(stu_match[1,2])) {
        stu_seconds <- as.numeric(stu_match[1,2])
        # Get epoch timestamp of STU message - convert time2 (POSIXct) to epoch
        stu_epoch <- as.numeric(as.POSIXct(stu_entry$time2[1]))
      }
    }

    # SHD (Shutdown) - extract end count
    # Pattern: SHD|548 (with or without TR_Rare prefix)
    shd_entry <- maint_log %>%
      filter(grepl("SHD\\|", text, ignore.case = TRUE)) %>%
      slice(1)

    if (nrow(shd_entry) > 0) {
      # Extract number after SHD|
      shd_match <- str_match(shd_entry$text[1], "SHD\\|(\\d+)")
      if (!is.na(shd_match[1,2])) {
        shd_seconds <- as.numeric(shd_match[1,2])
      }
    } else {
      # No SHD message found - use last epoch time from log minus STU epoch
      if (!is.na(stu_epoch) && !is.null(info_data) && nrow(info_data) > 0) {
        # Get the last timestamp from the info log - convert time2 to epoch
        last_epoch <- max(as.numeric(as.POSIXct(info_data$time2)), na.rm = TRUE)
        # Calculate SHD as the difference from STU epoch
        shd_seconds <- last_epoch - stu_epoch
      }
    }

    # Calculate flight time if both are available
    if (!is.na(stu_seconds) && !is.na(shd_seconds)) {
      flight_time_seconds <- shd_seconds - stu_seconds
    }
  }

  # Add metadata columns
  milestones$LogFile <- basename(log_file)
  milestones$STU_seconds <- stu_seconds
  milestones$SHD_seconds <- shd_seconds
  milestones$FlightTime_seconds <- flight_time_seconds

  return(milestones)
}


#' Extract Boot Milestones from Multiple Logs
#'
#' Processes multiple log files and combines boot milestone data
#'
#' @param processed_logs List. Output from process_multiple_logs()
#'
#' @return Data frame with all milestones from all logs
#'
#' @examples
#' all_milestones <- extract_all_boot_milestones(processed_logs)
extract_all_boot_milestones <- function(processed_logs) {

  milestone_list <- list()

  for (log_file in names(processed_logs)) {
    # Get the full info data
    log_info <- processInfoLog(log_file)

    # Extract milestones (pass info, maintLog, and sbitSection)
    milestones <- extract_boot_milestones(log_file, log_info$info, log_info$maintLog, log_info$sbitSection)

    if (nrow(milestones) > 0) {
      milestone_list[[log_file]] <- milestones
    }
  }

  # Combine all milestones
  if (length(milestone_list) > 0) {
    all_milestones <- do.call(rbind, milestone_list)
    rownames(all_milestones) <- NULL
    return(all_milestones)
  } else {
    return(data.frame())
  }
}


#' Extract SBIT Subassembly Commands
#'
#' Extracts subassembly run commands from SBIT section by filtering on fx == bitRunCmdNode
#' Pattern: 'TR_Medium commanding "run" to subassembly "GPS"' BitAsTree.c 301 bitRunCmdNode
#'
#' @param info_data Data frame. Full info data from processInfoLog()$info
#'
#' @return Data frame with columns: time2, subassembly, text
#'
#' @examples
#' subassembly_cmds <- extract_sbit_subassembly_commands(info_data)
extract_sbit_subassembly_commands <- function(info_data) {

  # Filter for bitRunCmdNode function calls
  run_commands <- info_data %>%
    filter(fx == "bitRunCmdNode") %>%
    filter(grepl('commanding "run" to subassembly', text, ignore.case = TRUE))

  if (nrow(run_commands) == 0) {
    return(data.frame(
      time2 = as.POSIXct(character()),
      subassembly = character(),
      text = character(),
      stringsAsFactors = FALSE
    ))
  }

  # Extract subassembly name from quoted text
  # Pattern: "GPS", "TsgOther", "TekTufSrv", etc.
  run_commands <- run_commands %>%
    mutate(
      subassembly = str_extract(text, '(?<=to subassembly ")[^"]+')
    ) %>%
    select(time2, subassembly, text)

  return(run_commands)
}


#' Extract PPS and TS480 Version Information
#'
#' Extracts hardware and software version information for PPS and TS480 components
#'
#' PPS Pattern: 'PPS S/N v11r02, Board Rev ;, Manufactured on Unknown, Software Rev v11r02'
#' TS480 Pattern: 'TS480 SW Ver 2.3.9, Svn 6039, Merced Svn 864, PS Ver 2'
#'
#' @param info_data Data frame. Full info data from processInfoLog()$info
#'
#' @return Data frame with columns: component, version_string, software_version, hardware_version
#'
#' @examples
#' versions <- extract_pps_ts480_versions(info_data)
extract_pps_ts480_versions <- function(info_data) {

  versions <- data.frame(
    component = character(),
    version_string = character(),
    software_version = character(),
    hardware_version = character(),
    stringsAsFactors = FALSE
  )

  # Extract PPS Version
  # Pattern: 'PPS S/N v11r02, Board Rev ;, Manufactured on Unknown, Software Rev v11r02'
  # Note: Text may be split across lines in raw log, search by function name
  pps_entries <- info_data %>%
    filter(fx == "scuPpduStartup") %>%
    filter(grepl("PPS S/N|Software Rev|v\\d+r\\d+", text, ignore.case = TRUE))

  if (nrow(pps_entries) > 0) {
    # Combine all matching text to handle multi-line entries
    pps_text <- paste(pps_entries$text, collapse = " ")

    # Extract software version using str_match
    pps_sw_match <- str_match(pps_text, "Software Rev\\s+([^']+)")
    pps_sw <- if (!is.na(pps_sw_match[1,2])) trimws(pps_sw_match[1,2]) else "Unknown"

    # Extract S/N (serial number / hardware version)
    pps_hw_match <- str_match(pps_text, "PPS S/N\\s+([^,]+)")
    pps_hw <- if (!is.na(pps_hw_match[1,2])) trimws(pps_hw_match[1,2]) else "Unknown"

    # If we got valid data, add it
    if (pps_sw != "Unknown" || pps_hw != "Unknown") {
      versions <- rbind(versions, data.frame(
        component = "PPS",
        version_string = substr(pps_text, 1, 100),  # Truncate for display
        software_version = pps_sw,
        hardware_version = pps_hw,
        stringsAsFactors = FALSE
      ))
    }
  }

  # Extract TS480 Version
  # Pattern: 'TS480 SW Ver 2.3.9, Svn 6039, Merced Svn 864, PS Ver 2'
  ts480_entry <- info_data %>%
    filter(grepl("TS480 SW Ver", text, ignore.case = TRUE)) %>%
    slice(1)

  if (nrow(ts480_entry) > 0) {
    ts480_text <- ts480_entry$text[1]

    # Extract software version using str_match
    ts480_sw_match <- str_match(ts480_text, "TS480 SW Ver\\s+([^,]+)")
    ts480_sw <- if (!is.na(ts480_sw_match[1,2])) trimws(ts480_sw_match[1,2]) else "Unknown"

    # Extract SVN version as hardware identifier
    ts480_svn_match <- str_match(ts480_text, "Svn\\s+(\\d+)")
    ts480_svn <- if (!is.na(ts480_svn_match[1,2])) paste0("Svn ", trimws(ts480_svn_match[1,2])) else "Unknown"

    versions <- rbind(versions, data.frame(
      component = "TS480",
      version_string = ts480_text,
      software_version = ts480_sw,
      hardware_version = ts480_svn,
      stringsAsFactors = FALSE
    ))
  }

  return(versions)
}


#' Calculate Boot Time Metrics
#'
#' Computes boot duration metrics from milestone data
#'
#' @param milestones Data frame. Output from extract_boot_milestones()
#'
#' @return Data frame with boot time metrics per log file
#'
#' @examples
#' boot_metrics <- calculate_boot_metrics(all_milestones)
calculate_boot_metrics <- function(milestones) {

  metrics <- milestones %>%
    group_by(LogFile) %>%
    summarise(
      FirstMilestone = min(timestamp, na.rm = TRUE),
      LastMilestone = max(timestamp, na.rm = TRUE),
      TotalBootTime_sec = as.numeric(difftime(max(timestamp, na.rm = TRUE),
                                               min(timestamp, na.rm = TRUE),
                                               units = "secs")),
      MilestonesCompleted = n(),
      MilestonesFailed = sum(status == "FAIL", na.rm = TRUE),
      .groups = "drop"
    )

  return(metrics)
}


#' Create Boot Timeline Plot
#'
#' Generates a timeline visualization of boot milestones
#'
#' @param milestones Data frame. Output from extract_boot_milestones()
#' @param log_file Character. Specific log file to plot (optional)
#'
#' @return Plot object
#'
#' @examples
#' plot_boot_timeline(all_milestones, "errorlog.log")
plot_boot_timeline <- function(milestones, log_file = NULL) {

  if (!is.null(log_file)) {
    milestones <- milestones %>% filter(LogFile == log_file)
  }

  if (nrow(milestones) == 0) {
    plot.new()
    text(0.5, 0.5, "No milestone data available", cex = 1.5)
    return(invisible(NULL))
  }

  # Calculate relative time from first milestone
  milestones <- milestones %>%
    arrange(timestamp) %>%
    mutate(
      relative_time = as.numeric(difftime(timestamp, min(timestamp), units = "secs")),
      y_pos = seq(nrow(milestones), 1)
    )

  # Create plot
  par(mar = c(5, 12, 4, 2))
  plot(milestones$relative_time, milestones$y_pos,
       type = "n",
       xlab = "Time from First Milestone (seconds)",
       ylab = "",
       yaxt = "n",
       main = paste("Boot Timeline -", unique(milestones$LogFile)[1]),
       xlim = c(0, max(milestones$relative_time) * 1.1),
       ylim = c(0.5, nrow(milestones) + 0.5))

  # Add milestone points and labels
  colors <- ifelse(milestones$status == "FAIL", "red", "darkgreen")
  points(milestones$relative_time, milestones$y_pos, pch = 19, col = colors, cex = 1.5)

  # Add milestone names
  axis(2, at = milestones$y_pos, labels = milestones$milestone, las = 1, cex.axis = 0.8)

  # Add time labels
  text(milestones$relative_time, milestones$y_pos,
       labels = sprintf("+%.1fs", milestones$relative_time),
       pos = 4, cex = 0.7, col = "blue")

  # Add connecting lines
  segments(0, milestones$y_pos, milestones$relative_time, milestones$y_pos,
           col = "gray70", lty = 2)

  # Add grid
  abline(v = seq(0, max(milestones$relative_time), by = 60), col = "gray90", lty = 1)

  # Add total boot time
  total_time <- max(milestones$relative_time)
  mtext(sprintf("Total Boot Time: %.1f seconds (%.2f minutes)", total_time, total_time/60),
        side = 1, line = 4, cex = 0.9, col = "darkblue")
}
