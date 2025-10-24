#' Quick View Module
#'
#' Shiny module for rapid single-file viewing and exploration of log files.
#' Supports both MS110 and DB110 logs with automatic detection.
#'
#' Key Architecture:
#' - MS110: Uses aerolog::ms110_processInfoLog() which returns list with:
#'   * $mission: Mission metadata
#'   * $sbit: SBIT test results
#'   * $info_df: Main data frame with parsed log entries
#' - DB110: Uses aerolog::db110_processLog() which returns similar structure
#' - All extraction uses aerolog package functions (e.g., ms110_getSensorID, db110_getSBITResults)
#' - All data manipulation uses base R (no dplyr) to avoid scoping issues
#'
#' Author: Phillip Escandon (Phillip.Escandon@pm.me)
#' Date: 2025-10-23
#' Last Updated: 2025-10-23 - Fixed metadata/SBIT extraction to use aerolog functions

library(shiny)
library(shinyFiles)
library(DT)
library(bslib)
library(dplyr)
library(stringr)

# Source detection and table utilities
source("R/utils/log_detection.R", local = TRUE)
source("R/utils/mode_detection.R", local = TRUE)
source("R/utils/table_helpers.R", local = TRUE)
source("R/utils/boot_milestones.R", local = TRUE)  # DB110 boot milestones
source("R/utils/ms110_boot_milestones.R", local = TRUE)  # MS110 boot milestones

#' Quick View UI Module
#'
#' @param id Character string - module namespace ID
#' @return Shiny UI
#' @export
quick_view_ui <- function(id) {
  ns <- NS(id)

  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = "File Selection",
      width = 350,

      # File selection card
      bslib::card(
        bslib::card_header("Select Log File"),
        shinyFiles::shinyFilesButton(
          ns("file_select"),
          "Browse Files",
          "Select a log file to view",
          multiple = FALSE,
          style = "width: 100%; margin-bottom: 10px;"
        ),
        verbatimTextOutput(ns("selected_file"), placeholder = TRUE),

        # Log type indicator
        uiOutput(ns("log_type_badge"))
      ),

      # Quick actions card
      bslib::card(
        bslib::card_header("Quick Actions"),
        actionButton(
          ns("analyze_in_pod_compass"),
          "Analyze in Pod Compass",
          icon = icon("chart-line"),
          class = "btn-primary",
          style = "width: 100%; margin-bottom: 10px;"
        ),
        downloadButton(
          ns("download_cleaned"),
          "Download Cleaned Log",
          style = "width: 100%; margin-bottom: 10px;"
        ),
        downloadButton(
          ns("download_sbit_csv"),
          "Download SBIT Results (CSV)",
          style = "width: 100%;"
        )
      ),

      # File info card
      bslib::card(
        bslib::card_header("File Information"),
        uiOutput(ns("file_info"))
      )
    ),

    # Main content area
    bslib::card(
      bslib::card_header(
        "Log File Viewer",
        class = "bg-primary text-white"
      ),

      # Status message
      uiOutput(ns("status_message")),

      # Tabbed content
      bslib::navset_card_tab(
        bslib::nav_panel(
          "Metadata",
          icon = icon("info-circle"),
          uiOutput(ns("metadata_display"))
        ),
        bslib::nav_panel(
          "SBIT Results",
          icon = icon("list-check"),
          uiOutput(ns("sbit_display"))
        ),
        bslib::nav_panel(
          "Boot Milestones",
          icon = icon("rocket"),
          uiOutput(ns("boot_milestones_display"))
        ),
        bslib::nav_panel(
          "Maintenance Log",
          icon = icon("wrench"),
          DT::DTOutput(ns("maintenance_table"))
        ),
        bslib::nav_panel(
          "System Messages",
          icon = icon("message"),

          # IRFPA Messages Section
          div(style = "background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); color: white; padding: 12px 15px; border-radius: 5px; margin-bottom: 15px; font-weight: bold;",
              icon("thermometer-half"), " IR Focal Plane Array (IRFPA) Messages"),
          p("TirFpa component messages. Rows highlighted in red indicate FAIL or Error conditions."),
          uiOutput(ns("irfpa_table")),

          br(), br(),

          # Power System Messages Section
          div(style = "background: linear-gradient(135deg, #fa709a 0%, #fee140 100%); color: white; padding: 12px 15px; border-radius: 5px; margin-bottom: 15px; font-weight: bold;",
              icon("bolt"), " Power System Messages"),
          p("Power and PPS-related entries. Rows highlighted in red indicate FAIL or Error conditions."),
          uiOutput(ns("power_table"))
        ),
        bslib::nav_panel(
          "Raw Log",
          icon = icon("file-code"),
          uiOutput(ns("raw_log"))
        )
      )
    )
  )
}


#' Quick View Server Module
#'
#' @param id Character string - module namespace ID
#' @param volumes Named character vector - file system volumes for shinyFiles
#' @param parent_session Shiny session object from parent (for tab switching)
#' @return List of reactive values for communication with parent
#' @export
quick_view_server <- function(id, volumes, parent_session = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive values
    rv <- reactiveValues(
      selected_file = NULL,
      log_type = NULL,
      parsed_log = NULL,
      error_message = NULL
    )

    # ===========================================================================
    # FILE SELECTION
    # ===========================================================================

    # Configure file browser
    shinyFileChoose(input, 'file_select', roots = volumes,
                    filetypes = c('log', 'txt'),
                    session = session)

    # Handle file selection
    observeEvent(input$file_select, {
      if (!is.null(input$file_select) && !is.integer(input$file_select)) {
        files <- parseFilePaths(volumes, input$file_select)
        if (nrow(files) > 0) {
          file_path <- as.character(files$datapath[1])
          rv$selected_file <- file_path

          # Detect log type
          rv$log_type <- detect_log_type(file_path)

          # Parse log file
          parse_log_file(file_path)
        }
      }
    })

    # Parse log file based on detected type
    parse_log_file <- function(file_path) {
      tryCatch({
        rv$error_message <- NULL

        if (is.null(rv$log_type)) {
          rv$error_message <- "Could not detect log type. Please ensure file is a valid MS110 or DB110 log."
          rv$parsed_log <- NULL
          return()
        }

        # Parse based on log type
        if (rv$log_type == "DB110") {
          if (!requireNamespace("aerolog", quietly = TRUE)) {
            rv$error_message <- "aerolog package not available. Please install it to view DB110 logs."
            return()
          }

          # Use correct function name: db110_processLog
          rv$parsed_log <- aerolog::db110_processLog(file_path)
        } else if (rv$log_type == "MS110") {
          if (!requireNamespace("aerolog", quietly = TRUE)) {
            rv$error_message <- "aerolog package not available. Please install it to view MS110 logs."
            return()
          }

          # Use processInfoLog which returns a list with info_df, sbit, mission, etc.
          rv$parsed_log <- aerolog::ms110_processInfoLog(file_path)
        } else {
          rv$error_message <- paste("Unknown log type:", rv$log_type)
          rv$parsed_log <- NULL
        }

      }, error = function(e) {
        rv$error_message <- paste("Error parsing log file:", e$message)
        rv$parsed_log <- NULL
      })
    }

    # Display selected file path
    output$selected_file <- renderText({
      if (is.null(rv$selected_file)) {
        "No file selected"
      } else {
        basename(rv$selected_file)
      }
    })

    # Log type badge
    output$log_type_badge <- renderUI({
      if (is.null(rv$log_type)) {
        return(NULL)
      }

      info <- get_log_type_display_info(rv$log_type)

      div(
        style = sprintf("background-color: %s; color: white; padding: 10px; border-radius: 5px; margin-top: 10px; text-align: center;", info$color),
        icon(info$icon),
        " ",
        strong(info$full_name)
      )
    })

    # File information
    output$file_info <- renderUI({
      if (is.null(rv$selected_file)) {
        return(p("No file selected", style = "color: #999;"))
      }

      file_info <- file.info(rv$selected_file)
      file_size <- format(file_info$size, big.mark = ",")
      file_mtime <- format(file_info$mtime, "%Y-%m-%d %H:%M:%S")

      tagList(
        p(strong("File Size:"), " ", file_size, " bytes"),
        p(strong("Modified:"), " ", file_mtime),
        p(strong("Path:"), br(), tags$small(rv$selected_file, style = "word-break: break-all;"))
      )
    })

    # ===========================================================================
    # STATUS MESSAGE
    # ===========================================================================

    output$status_message <- renderUI({
      if (!is.null(rv$error_message)) {
        div(
          class = "alert alert-danger",
          icon("exclamation-circle"),
          " ",
          rv$error_message
        )
      } else if (is.null(rv$selected_file)) {
        div(
          class = "alert alert-info",
          icon("info-circle"),
          " Please select a log file to view its contents."
        )
      } else if (!is.null(rv$parsed_log)) {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          " Log file parsed successfully!"
        )
      } else {
        NULL
      }
    })

    # ===========================================================================
    # METADATA TAB
    # ===========================================================================

    output$metadata_display <- renderUI({
      req(rv$parsed_log)

      # info_df contains the metadata - extract key fields
      if (!is.null(rv$parsed_log$info_df) && is.data.frame(rv$parsed_log$info_df)) {
        df <- rv$parsed_log$info_df

        # Extract metadata fields from the first few rows
        # Assuming metadata is stored with Attribute and Value columns
        metadata_list <- list()

        if ("Attribute" %in% names(df) && "Value" %in% names(df)) {
          # Extract all rows with Attribute and Value
          for (i in 1:min(nrow(df), 50)) {
            attr_name <- df$Attribute[i]
            attr_value <- df$Value[i]

            if (!is.na(attr_name) && !is.na(attr_value) &&
                nchar(as.character(attr_name)) > 0) {
              metadata_list[[as.character(attr_name)]] <- as.character(attr_value)
            }
          }
        }

        # Create display items
        if (length(metadata_list) > 0) {
          metadata_items <- lapply(names(metadata_list), function(name) {
            p(
              strong(paste0(name, ":")),
              " ",
              metadata_list[[name]],
              style = "margin-bottom: 8px;"
            )
          })

          bslib::card(
            bslib::card_header("Log File Metadata"),
            div(style = "padding: 10px;",
              do.call(tagList, metadata_items)
            )
          )
        } else {
          bslib::card(
            bslib::card_header("Log File Metadata"),
            p("No metadata fields found in info_df", style = "color: #999;")
          )
        }
      } else {
        bslib::card(
          bslib::card_header("Log File Metadata"),
          p("No info_df data available", style = "color: #999;")
        )
      }
    })

    # ===========================================================================
    # SBIT RESULTS TAB
    # ===========================================================================

    # Extract SBIT results - just get the raw data without filters
    sbit_data_raw <- reactive({
      req(rv$parsed_log)

      # Initialize empty data frame
      sbit_df <- data.frame(
        Name = character(),
        TID = character(),
        Status = character(),
        time2 = character(),
        stringsAsFactors = FALSE
      )

      # Extract SBIT results based on log type
      tryCatch({
        if (rv$log_type == "MS110") {
          # First try to get directly from sbitSection component
          if (!is.null(rv$parsed_log$sbitSection)) {
            if (is.data.frame(rv$parsed_log$sbitSection) || inherits(rv$parsed_log$sbitSection, "tbl_df")) {
              sbit_df <- as.data.frame(rv$parsed_log$sbitSection)
            }
          }
        } else if (rv$log_type == "DB110") {
          # Use DB110 extraction function
          sbit_results <- aerolog::db110_getSBITResults(rv$parsed_log)
          if (is.data.frame(sbit_results) && nrow(sbit_results) > 0) {
            sbit_df <- sbit_results
          }
        }
      }, error = function(e) {
        # If extraction fails, log error but continue
        message("Error extracting SBIT results: ", e$message)
      })

      return(sbit_df)
    })

    # SBIT display - using sbitCompass style with extract_sbit_tests
    output$sbit_display <- renderUI({
      req(rv$parsed_log)

      sbit_section <- sbit_data_raw()

      # Check if we have valid SBIT section
      if (is.null(sbit_section) || nrow(sbit_section) == 0) {
        return(
          div(
            class = "alert alert-info",
            icon("info-circle"),
            " No SBIT results found in this log file."
          )
        )
      }

      # Extract test results using table_helpers function (from sbitCompass)
      all_tests <- extract_sbit_tests(sbit_section)
      failures <- extract_sbit_tests(sbit_section, status_filter = "FAIL", include_message = TRUE)
      degraded <- extract_sbit_tests(sbit_section, status_filter = "DEGR", include_message = TRUE)

      # Calculate statistics
      total <- nrow(all_tests)
      pass <- sum(all_tests$Status == "PASS", na.rm = TRUE)
      fail <- sum(all_tests$Status == "FAIL", na.rm = TRUE)
      degr <- sum(all_tests$Status == "DEGR", na.rm = TRUE)

      tagList(
        # Summary statistics
        div(
          style = "padding: 15px; background-color: #f8f9fa; border-radius: 5px; margin-bottom: 20px;",
          fluidRow(
            column(3, p(strong("Total Tests:"), " ", total)),
            column(3, p(strong("Pass:"), " ", span(pass, style = "color: green; font-weight: bold;"))),
            column(3, p(strong("Fail:"), " ", span(fail, style = "color: red; font-weight: bold;"))),
            column(3, p(strong("Degraded:"), " ", span(degr, style = "color: orange; font-weight: bold;")))
          )
        ),

        # Failures section (if any)
        if (nrow(failures) > 0) {
          tagList(
            h4(
              style = "color: #dc3545; margin-top: 20px;",
              icon("exclamation-triangle"),
              " Failed Tests"
            ),
            DT::renderDT({
              create_sbit_datatable(
                failures,
                column_names = c('Test Name', 'TID', 'Status', 'Message', 'Timestamp'),
                page_length = 10,
                apply_status_colors = FALSE
              )
            }),
            hr()
          )
        } else {
          NULL
        },

        # Degraded section (if any)
        if (nrow(degraded) > 0) {
          tagList(
            h4(
              style = "color: #f0ad4e; margin-top: 20px;",
              icon("exclamation-circle"),
              " Degraded Tests"
            ),
            DT::renderDT({
              create_sbit_datatable(
                degraded,
                column_names = c('Test Name', 'TID', 'Status', 'Message', 'Timestamp'),
                page_length = 10,
                apply_status_colors = FALSE
              )
            }),
            hr()
          )
        } else {
          NULL
        },

        # Success message if no failures or degraded
        if (nrow(failures) == 0 && nrow(degraded) == 0) {
          div(
            class = "alert alert-success",
            style = "margin-top: 20px;",
            icon("check-circle"),
            " All SBIT tests passed!"
          )
        } else {
          NULL
        },

        # All tests section
        h4(
          style = "margin-top: 20px;",
          icon("list"),
          " All SBIT Test Results"
        ),
        DT::renderDT({
          create_sbit_datatable(
            all_tests,
            column_names = c('Test Name', 'TID', 'Status', 'Timestamp'),
            page_length = 25,
            apply_status_colors = TRUE
          )
        })
      )
    })

    # ===========================================================================
    # BOOT MILESTONES TAB
    # ===========================================================================

    output$boot_milestones_display <- renderUI({
      req(rv$parsed_log)
      req(rv$selected_file)

      # Extract boot milestones using appropriate function based on log type
      boot_milestones <- tryCatch({
        # Get the necessary components for boot milestone extraction
        # For MS110: info = full log tibble, info_df = metadata (Attribute/Value)
        # For DB110: info_df = full log data
        info_data <- if (!is.null(rv$parsed_log$info)) {
          rv$parsed_log$info
        } else if (!is.null(rv$parsed_log$info_df)) {
          rv$parsed_log$info_df
        } else {
          NULL
        }

        maint_log <- if (!is.null(rv$parsed_log$maintLog)) {
          rv$parsed_log$maintLog
        } else {
          NULL
        }

        sbit_section <- if (!is.null(rv$parsed_log$sbitSection)) {
          rv$parsed_log$sbitSection
        } else {
          NULL
        }

        # Call the appropriate extraction function based on log type
        if (!is.null(info_data)) {
          if (rv$log_type == "MS110") {
            # Use MS110-specific function
            extract_ms110_boot_milestones(
              rv$selected_file,
              info_data,
              maint_log,
              sbit_section
            )
          } else if (rv$log_type == "DB110") {
            # Use DB110-specific function (from sbitCompass)
            extract_boot_milestones(
              rv$selected_file,
              info_data,
              maint_log,
              sbit_section
            )
          } else {
            NULL
          }
        } else {
          NULL
        }
      }, error = function(e) {
        message("Error extracting boot milestones: ", e$message)
        NULL
      })

      # Display the results
      if (is.null(boot_milestones) || nrow(boot_milestones) == 0) {
        # Debug: Show what data we have
        info_preview <- if (!is.null(rv$parsed_log$info_df)) {
          head(rv$parsed_log$info_df, 20)
        } else {
          NULL
        }

        return(
          div(
            class = "alert alert-warning",
            h5(icon("info-circle"), " Boot Milestones Debug Information"),
            p(strong("Log Type:"), " ", rv$log_type),
            p(strong("Info DF available:"), " ", !is.null(rv$parsed_log$info_df)),
            p(strong("Info DF rows:"), " ", if (!is.null(rv$parsed_log$info_df)) nrow(rv$parsed_log$info_df) else "N/A"),
            p(strong("Info DF columns:"), " ", if (!is.null(rv$parsed_log$info_df)) paste(names(rv$parsed_log$info_df), collapse = ", ") else "N/A"),
            p(strong("SBIT Section available:"), " ", !is.null(rv$parsed_log$sbitSection)),
            p(strong("SBIT Section rows:"), " ", if (!is.null(rv$parsed_log$sbitSection)) nrow(rv$parsed_log$sbitSection) else "N/A"),
            hr(),
            if (!is.null(info_preview)) {
              tagList(
                h5("First 20 rows of info_df (for pattern identification):"),
                DT::renderDT({
                  DT::datatable(
                    info_preview,
                    options = list(scrollX = TRUE, pageLength = 20),
                    rownames = FALSE
                  )
                })
              )
            } else {
              p("No info_df data available")
            }
          )
        )
      }

      tagList(
        h4(
          icon("rocket"),
          " Boot Sequence Milestones"
        ),
        p("Key system initialization events tracked from power-on to mission start:"),
        DT::renderDT({
          # Format timestamp for display
          display_df <- boot_milestones
          if ("timestamp" %in% names(display_df)) {
            display_df$timestamp <- format(display_df$timestamp, "%Y-%m-%d %H:%M:%S")
          }

          datatable(
            display_df,
            options = list(
              pageLength = 15,
              scrollX = TRUE,
              dom = 't'  # No search/pagination for small table
            ),
            colnames = c('Milestone', 'Timestamp', 'Value', 'Status'),
            rownames = FALSE,
            class = 'cell-border stripe'
          ) %>%
            formatStyle(
              'status',
              backgroundColor = styleEqual(
                c('PASS', 'FAIL', 'WARN'),
                c('#d4edda', '#f8d7da', '#fff3cd')
              ),
              color = styleEqual(
                c('PASS', 'FAIL', 'WARN'),
                c('#155724', '#721c24', '#856404')
              ),
              fontWeight = 'bold'
            )
        })
      )
    })

    # ===========================================================================
    # MAINTENANCE LOG TAB
    # ===========================================================================

    output$maintenance_table <- DT::renderDT({
      req(rv$parsed_log)

      # Try to extract maintenance log using appropriate function
      maint_df <- tryCatch({
        if (rv$log_type == "DB110") {
          # Use DB110-specific extraction
          aerolog::db110_getMaintLog(rv$parsed_log)
        } else if (rv$log_type == "MS110") {
          # For MS110, extract from info (full log tibble)
          if (!is.null(rv$parsed_log$info)) {
            df <- rv$parsed_log$info
            if ("fx" %in% names(df) && "text" %in% names(df)) {
              fx_col <- df$fx
              maint_rows <- !is.na(fx_col) & (fx_col == "MaintLog" | grepl("maint", fx_col, ignore.case = TRUE))
              df[maint_rows, , drop = FALSE]
            } else {
              NULL
            }
          } else {
            NULL
          }
        } else {
          NULL
        }
      }, error = function(e) {
        NULL
      })

      # Check if we have valid results
      if (is.null(maint_df) || !is.data.frame(maint_df) || nrow(maint_df) == 0) {
        return(datatable(
          data.frame(Message = "No maintenance log entries found"),
          options = list(dom = 't'),
          rownames = FALSE
        ))
      }

      # Prepare data for display - select time2, text, fx columns if available
      if (all(c("time2", "text", "fx") %in% names(maint_df))) {
        display_df <- maint_df[, c("time2", "text", "fx"), drop = FALSE]
        # Use sbitCompass helper function for styled table
        create_maint_log_table(display_df)
      } else {
        # Fallback: simple display
        if ("time2" %in% names(maint_df)) {
          display_df <- maint_df[, c("time2", "text"), drop = FALSE]
          col_names <- c("Timestamp", "Message")
        } else if ("time" %in% names(maint_df)) {
          display_df <- maint_df[, c("time", "text"), drop = FALSE]
          col_names <- c("Timestamp", "Message")
        } else {
          display_df <- maint_df[, "text", drop = FALSE]
          col_names <- c("Message")
        }

        datatable(
          display_df,
          options = list(
            pageLength = 20,
            scrollX = TRUE,
            dom = 'frtip'
          ),
          colnames = col_names,
          rownames = FALSE
        )
      }
    })

    # ===========================================================================
    # SYSTEM MESSAGES TAB
    # ===========================================================================

    output$irfpa_table <- renderUI({
      req(rv$parsed_log)

      # Try to extract IRFPA messages using appropriate function
      irfpa_df <- tryCatch({
        if (rv$log_type == "DB110") {
          # Use DB110-specific extraction - pass the info tibble
          aerolog::db110_getIRFPA(rv$parsed_log$info)
        } else if (rv$log_type == "MS110") {
          # For MS110, extract from info (full log tibble)
          if (!is.null(rv$parsed_log$info)) {
            df <- rv$parsed_log$info
            if ("sw2" %in% names(df) && "text" %in% names(df)) {
              sw2_col <- df$sw2
              irfpa_rows <- !is.na(sw2_col) & grepl("Fpa", sw2_col, ignore.case = TRUE)
              df[irfpa_rows, , drop = FALSE]
            } else {
              NULL
            }
          } else {
            NULL
          }
        } else {
          NULL
        }
      }, error = function(e) {
        NULL
      })

      # Check if we have valid results
      if (is.null(irfpa_df) || !is.data.frame(irfpa_df) || nrow(irfpa_df) == 0) {
        return(p("No IRFPA messages found", style = "color: #999;"))
      }

      # Prepare display with all columns (time, fx, sw2, text) like sbitCompass
      display_cols <- c("time", "fx", "sw2", "text")
      if ("time2" %in% names(irfpa_df)) {
        display_cols[1] <- "time2"
      }

      # Select available columns
      available_cols <- display_cols[display_cols %in% names(irfpa_df)]
      display_df <- irfpa_df[, available_cols, drop = FALSE]

      # Convert all columns to character for flextable
      if ("time2" %in% names(display_df)) {
        display_df$time2 <- as.character(format(display_df$time2, "%Y-%m-%d %H:%M:%S"))
      } else if ("time" %in% names(display_df)) {
        display_df$time <- as.character(format(display_df$time, "%Y-%m-%d %H:%M:%S"))
      }
      display_df$fx <- as.character(display_df$fx)
      display_df$sw2 <- as.character(display_df$sw2)
      display_df$text <- as.character(display_df$text)

      # Create flextable
      ft <- flextable::flextable(display_df)

      # Highlight FAIL/Error rows in red (like sbitCompass)
      fail_rows <- grepl('FAIL|Error', display_df$text, ignore.case = TRUE)
      if (any(fail_rows)) {
        ft <- flextable::bg(ft, i = which(fail_rows), bg = "#f8d7da", part = "body")
        ft <- flextable::color(ft, i = which(fail_rows), color = "#721c24", part = "body")
      }

      # Apply theme and set headers
      ft <- ft |>
        flextable::theme_box() |>
        flextable::set_header_labels(
          time = "Time", time2 = "Time",
          fx = "Function",
          sw2 = "Component",
          text = "Message"
        ) |>
        flextable::autofit()

      # Return as HTML
      HTML(as.character(flextable::htmltools_value(ft)))
    })

    output$power_table <- renderUI({
      req(rv$parsed_log)

      # Try to extract power messages using appropriate function
      power_df <- tryCatch({
        # Both DB110 and MS110 can use db110_getPower since they have the same column structure
        if (!is.null(rv$parsed_log$info)) {
          aerolog::db110_getPower(rv$parsed_log$info)
        } else {
          NULL
        }
      }, error = function(e) {
        message("Error extracting power messages: ", e$message)
        NULL
      })

      # Check if we have valid results
      if (is.null(power_df) || !is.data.frame(power_df) || nrow(power_df) == 0) {
        return(p("No power messages found", style = "color: #999;"))
      }

      # Prepare display with all columns (time2, text, sw2, fx) like sbitCompass
      display_cols <- c("time2", "text", "sw2", "fx")
      if (!"time2" %in% names(power_df) && "time" %in% names(power_df)) {
        display_cols[1] <- "time"
      }

      # Select available columns
      available_cols <- display_cols[display_cols %in% names(power_df)]
      display_df <- power_df[, available_cols, drop = FALSE]

      # Format time column and convert to character for flextable
      if ("time2" %in% names(display_df)) {
        display_df$time2 <- as.character(format(display_df$time2, "%Y-%m-%d %H:%M:%S"))
      } else if ("time" %in% names(display_df)) {
        display_df$time <- as.character(format(display_df$time, "%Y-%m-%d %H:%M:%S"))
      }

      # Convert all columns to character for flextable
      display_df$text <- as.character(display_df[[names(display_df)[2]]])
      display_df$sw2 <- as.character(display_df[[names(display_df)[3]]])
      display_df$fx <- as.character(display_df[[names(display_df)[4]]])

      # Create flextable
      ft <- flextable::flextable(display_df)

      # Highlight FAIL/Error rows in red (like sbitCompass)
      fail_rows <- grepl('FAIL|Error', display_df$text, ignore.case = TRUE)
      if (any(fail_rows)) {
        ft <- flextable::bg(ft, i = which(fail_rows), bg = "#f8d7da", part = "body")
        ft <- flextable::color(ft, i = which(fail_rows), color = "#721c24", part = "body")
      }

      # Apply theme and set headers
      ft <- ft |>
        flextable::theme_box() |>
        flextable::set_header_labels(
          time2 = "Timestamp", time = "Timestamp",
          text = "Message",
          sw2 = "Component",
          fx = "Function"
        ) |>
        flextable::autofit()

      # Return as HTML
      HTML(as.character(flextable::htmltools_value(ft)))
    })

    # ===========================================================================
    # RAW LOG TAB
    # ===========================================================================

    output$raw_log <- renderUI({
      req(rv$parsed_log)

      tryCatch({
        # Extract time2 and text from info tibble
        # Both MS110 and DB110: info = full log tibble, info_df = metadata only
        log_data <- rv$parsed_log$info

        if (is.null(log_data) || nrow(log_data) == 0) {
          return(div(
            class = "alert alert-warning",
            "No log data available"
          ))
        }

        # Extract only time2 and text columns
        time_col <- if ("time2" %in% names(log_data)) "time2" else if ("time" %in% names(log_data)) "time" else NULL
        text_col <- if ("text" %in% names(log_data)) "text" else NULL

        if (is.null(text_col)) {
          return(div(
            class = "alert alert-warning",
            "No text column found in log data"
          ))
        }

        # Format log entries: [timestamp] text
        if (!is.null(time_col)) {
          # Format timestamps
          timestamps <- format(log_data[[time_col]], "%Y-%m-%d %H:%M:%S")
          log_lines <- paste0("[", timestamps, "] ", log_data[[text_col]])
        } else {
          log_lines <- log_data[[text_col]]
        }

        # Load Bing sentiment lexicon from tidytext
        bing_negative <- NULL
        if (requireNamespace("tidytext", quietly = TRUE)) {
          tryCatch({
            bing_lexicon <- tidytext::get_sentiments("bing")
            bing_negative <- bing_lexicon$word[bing_lexicon$sentiment == "negative"]
          }, error = function(e) {
            # If lexicon not available, continue without highlighting
          })
        }

        # Process each line and highlight negative words
        if (!is.null(bing_negative) && length(bing_negative) > 0) {
          highlighted_lines <- sapply(log_lines, function(line) {
            # Split line into words while preserving spaces
            words <- strsplit(line, "\\s+")[[1]]

            # Check each word and wrap negative ones in span
            highlighted_words <- sapply(words, function(word) {
              # Remove punctuation for checking but keep original word
              word_clean <- tolower(gsub("[^a-z]", "", word))

              if (word_clean %in% bing_negative) {
                # Highlight negative words
                paste0('<span style="background-color: #fff3cd; color: #856404; font-weight: bold;">',
                       htmltools::htmlEscape(word), '</span>')
              } else {
                htmltools::htmlEscape(word)
              }
            })

            paste(highlighted_words, collapse = " ")
          }, USE.NAMES = FALSE)

          # Combine lines with <br> tags
          html_content <- paste(highlighted_lines, collapse = "<br>")

          # Return as HTML with monospace font
          div(
            style = "font-family: monospace; white-space: pre-wrap; padding: 10px; background-color: #f8f9fa; border-radius: 5px; overflow-x: auto;",
            HTML(html_content)
          )
        } else {
          # Fallback: display without highlighting
          pre(
            style = "background-color: #f8f9fa; padding: 10px; border-radius: 5px; overflow-x: auto;",
            paste(log_lines, collapse = "\n")
          )
        }
      }, error = function(e) {
        div(
          class = "alert alert-danger",
          paste("Error reading log data:", e$message)
        )
      })
    })

    # ===========================================================================
    # DOWNLOAD HANDLERS
    # ===========================================================================

    # Download cleaned log
    output$download_cleaned <- downloadHandler(
      filename = function() {
        if (!is.null(rv$selected_file)) {
          base_name <- tools::file_path_sans_ext(basename(rv$selected_file))
          paste0(base_name, "_cleaned.log")
        } else {
          "cleaned_log.log"
        }
      },
      content = function(file) {
        req(rv$selected_file)

        # Read and clean log
        lines <- readLines(rv$selected_file, warn = FALSE)

        # Basic cleaning: merge continuation lines, fix contractions
        # This is a placeholder - actual cleaning logic from aerolog package
        cleaned_lines <- lines

        writeLines(cleaned_lines, file)
      }
    )

    # Download SBIT results as CSV
    output$download_sbit_csv <- downloadHandler(
      filename = function() {
        if (!is.null(rv$selected_file)) {
          base_name <- tools::file_path_sans_ext(basename(rv$selected_file))
          paste0(base_name, "_sbit_results.csv")
        } else {
          "sbit_results.csv"
        }
      },
      content = function(file) {
        req(rv$parsed_log)
        req(!is.null(rv$parsed_log$info_df))

        sbit_df <- rv$parsed_log$info_df %>%
          filter(!is.na(Status), Status %in% c("PASS", "FAIL", "DEGR")) %>%
          select(Name, TID, Status, time2)

        write.csv(sbit_df, file, row.names = FALSE)
      }
    )

    # ===========================================================================
    # ANALYZE IN POD COMPASS
    # ===========================================================================

    observeEvent(input$analyze_in_pod_compass, {
      req(rv$selected_file)
      req(rv$log_type)

      # Return values to parent for Pod Compass navigation
      # Parent will handle switching to Pod Compass tab
      if (!is.null(parent_session)) {
        # Signal parent to switch tabs and load file
        parent_session$sendCustomMessage(
          "quick_view_to_pod_compass",
          list(
            file = rv$selected_file,
            log_type = rv$log_type
          )
        )
      }

      showNotification(
        "Preparing file for Pod Compass analysis...",
        type = "message",
        duration = 3
      )
    })

    # ===========================================================================
    # RETURN VALUES FOR PARENT
    # ===========================================================================

    return(list(
      selected_file = reactive({ rv$selected_file }),
      log_type = reactive({ rv$log_type }),
      parsed_log = reactive({ rv$parsed_log })
    ))
  })
}
