#' Table Helper Functions
#'
#' This file contains reusable functions for creating and styling tables
#' in the SBIT Comparison Analysis Shiny app.
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-18

# Load required packages
library(dplyr)
library(stringr)
library(DT)

#' Extract SBIT Test Data from Log Section
#'
#' Parses SBIT test results from a log section and extracts test name,
#' TID, and status information using regex patterns.
#'
#' @param sbit_section Data frame containing SBIT log section with 'text' column
#' @param status_filter Character string to filter by status (e.g., "FAIL", "DEGR").
#'                      If NULL, returns all tests with status information.
#' @param include_message Logical. If TRUE, includes full message text in output.
#'
#' @return Data frame with columns: Name, TID, Status, [text], time2
#'
#' @examples
#' # Get all tests
#' all_tests <- extract_sbit_tests(sbit_section)
#'
#' # Get only failed tests with messages
#' failures <- extract_sbit_tests(sbit_section, status_filter = "FAIL",
#'                                include_message = TRUE)
extract_sbit_tests <- function(sbit_section, status_filter = NULL,
                               include_message = FALSE) {

  # Build regex pattern based on filter
  if (is.null(status_filter)) {
    pattern <- 'TID.*status'
  } else {
    pattern <- paste0('TID.*', status_filter)
  }

  # Extract test information using regex
  # Handle both "status = PASS" and "BIT status = PASS" formats
  result <- sbit_section %>%
    filter(grepl(pattern, text, ignore.case = TRUE)) %>%
    mutate(
      Name = str_extract(text, regex("(?<=node name = )\\w+", ignore_case = TRUE)),
      TID = str_extract(text, regex("(?<=TID = )[^,]+", ignore_case = TRUE)),
      Status = str_extract(text, regex("(?<=(BIT )?status = )\\w+", ignore_case = TRUE))
    ) %>%
    filter(!is.na(Name) & !is.na(TID) & !is.na(Status))

  # Select columns based on whether message is needed
  if (include_message) {
    result <- result %>% select(Name, TID, Status, text, time2)
  } else {
    result <- result %>% select(Name, TID, Status, time2)
  }

  return(result)
}


#' Create Styled DataTable for SBIT Results
#'
#' Creates a DT::datatable with consistent styling and configuration
#' for displaying SBIT test results.
#'
#' @param data Data frame to display
#' @param column_names Character vector of display names for columns
#' @param page_length Integer. Number of rows per page (default: 10)
#' @param apply_status_colors Logical. Apply color coding to Status column (default: TRUE)
#' @param enable_filters Logical. Show column filters at top (default: TRUE)
#'
#' @return DT::datatable object
#'
#' @examples
#' create_sbit_datatable(failures,
#'                       column_names = c('Name', 'TID', 'Status', 'Message', 'Time'),
#'                       page_length = 25)
create_sbit_datatable <- function(data, column_names = NULL, page_length = 10,
                                  apply_status_colors = TRUE,
                                  enable_filters = TRUE) {

  # Handle empty data
  if (nrow(data) == 0 || is.null(data)) {
    return(data.frame(Message = "No data available"))
  }

  # Build datatable options
  dt_options <- list(
    pageLength = page_length,
    scrollX = TRUE
  )

  # Add column width for message columns if present
  if ("text" %in% names(data)) {
    dt_options$columnDefs <- list(
      list(width = '500px', targets = which(names(data) == "text") - 1)
    )
  }

  # Create base datatable
  dt <- datatable(
    data,
    options = dt_options,
    filter = if (enable_filters) 'top' else 'none',
    rownames = FALSE,
    colnames = column_names
  )

  # Apply status color coding if requested and Status column exists
  if (apply_status_colors && "Status" %in% names(data)) {
    dt <- dt %>%
      formatStyle('Status',
                  backgroundColor = styleEqual(
                    c('PASS', 'FAIL', 'DEGR'),
                    c('#d4edda', '#f8d7da', '#fff3cd')  # Green, Red, Yellow
                  ),
                  fontWeight = styleEqual(
                    c('FAIL', 'DEGR'),
                    c('bold', 'bold')
                  ))
  }

  return(dt)
}


#' Create Empty Data Frame with Specific Schema
#'
#' Helper function to create empty data frames with correct column types
#' for different data types used in the app.
#'
#' @param type Character. One of "maint_log", "irfpa", or "power"
#'
#' @return Empty tibble with appropriate column structure
#'
#' @examples
#' empty_maint_log <- create_empty_df("maint_log")
create_empty_df <- function(type = c("maint_log", "irfpa", "power")) {
  type <- match.arg(type)

  schemas <- list(
    maint_log = data.frame(
      time2 = as.POSIXct(character(0), tz = "Asia/Dubai"),
      text = character(0),
      fx = character(0),
      LogFile = character(0),
      stringsAsFactors = FALSE
    ),
    irfpa = data.frame(
      time = character(0),
      fx = character(0),
      sw2 = character(0),
      text = character(0),
      LogFile = character(0),
      stringsAsFactors = FALSE
    ),
    power = data.frame(
      time2 = as.POSIXct(character(0), tz = "Asia/Dubai"),
      text = character(0),
      sw2 = character(0),
      fx = character(0),
      LogFile = character(0),
      stringsAsFactors = FALSE
    )
  )

  return(schemas[[type]])
}


#' Create Maintenance Log DataTable
#'
#' Specialized datatable for maintenance log entries with function-based coloring.
#'
#' @param maint_log_data Data frame containing maintenance log entries
#'
#' @return DT::datatable object
create_maint_log_table <- function(maint_log_data) {

  if (!is.data.frame(maint_log_data) || nrow(maint_log_data) == 0) {
    return(data.frame(Message = "No maintenance log entries found"))
  }

  datatable(
    maint_log_data,
    options = list(
      pageLength = 10,
      scrollX = TRUE,
      columnDefs = list(
        list(width = '400px', targets = 1)  # text column
      )
    ),
    filter = 'top',
    rownames = FALSE,
    colnames = c('Timestamp', 'Log Entry', 'Function')
  ) %>%
    formatStyle('fx',
                backgroundColor = styleEqual(
                  c('CS_addMaintLogEnt', 'bitMaintLogWrite'),
                  c('#e3f2fd', '#fff3e0')  # Light blue, Light orange
                ))
}
