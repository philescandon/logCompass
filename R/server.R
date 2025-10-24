#' Log Compass Server
#'
#' Server logic for Log Compass application
#' Follows Mastering Shiny reactive programming best practices
#'
#' Architecture: Modular design with separate modules for each operational mode

# Source Quick View module
source("R/modules/quick_view_module.R", local = TRUE)

server <- function(input, output, session) {

  # ===========================================================================
  # SHARED: Directory Selection Setup and Reactive Values
  # ===========================================================================

  # Get system volumes for directory selection
  volumes <- c(Home = fs::path_home(), getVolumes()())

  # Shared reactive values for inter-tab communication
  rv <- reactiveValues(
    quick_view_file = NULL,              # File selected in Quick View
    batch_selected_files = NULL,         # Files selected from Batch Process
    pod_compass_files = NULL,            # Files loaded in Pod Compass
    analysis_mode = NULL,                # Detected mode info
    log_type = NULL                      # "MS110" or "DB110"
  )

  # ===========================================================================
  # QUICK VIEW MODULE
  # ===========================================================================

  # Initialize Quick View module
  quick_view_return <- quick_view_server("quick_view", volumes = volumes, parent_session = session)

  # Handle "Analyze in Pod Compass" action from Quick View
  # This will be used when Pod Compass module is integrated
  observeEvent(quick_view_return$selected_file(), {
    rv$quick_view_file <- quick_view_return$selected_file()
    rv$log_type <- quick_view_return$log_type()
  })

  # ===========================================================================
  # MS110 Processing Logic
  # ===========================================================================

  # MS110 Source directory selection
  shinyFiles::shinyDirChoose(input, "ms110_source_dir", roots = volumes, session = session)

  ms110_source_path <- reactive({
    req(input$ms110_source_dir)
    shinyFiles::parseDirPath(volumes, input$ms110_source_dir)
  })

  output$ms110_source_path <- renderText({
    path <- ms110_source_path()
    if (length(path) > 0) path else "No directory selected"
  })

  # MS110 Output directory selection
  shinyFiles::shinyDirChoose(input, "ms110_output_dir", roots = volumes, session = session)

  ms110_output_path <- reactive({
    req(input$ms110_output_dir)
    shinyFiles::parseDirPath(volumes, input$ms110_output_dir)
  })

  output$ms110_output_path <- renderText({
    path <- ms110_output_path()
    if (length(path) > 0) path else "No directory selected"
  })

  # MS110 Processing reactive values
  ms110_results <- reactiveVal(NULL)
  ms110_log_output <- reactiveVal("")

  # MS110 Process button handler
  observeEvent(input$ms110_process, {
    req(ms110_source_path(), ms110_output_path())

    # Clear previous results
    ms110_results(NULL)
    ms110_log_output("")

    # Initial status message
    ms110_log_output(paste0(
      "=== MS110 Processing Started ===\n",
      "Source: ", ms110_source_path(), "\n",
      "Output: ", ms110_output_path(), "\n",
      "Recursive: ", input$ms110_recursive, "\n",
      "Clean: ", input$ms110_clean, "\n",
      "Verbose: ", input$ms110_verbose, "\n",
      "Keep Original: ", input$ms110_keep_original, "\n",
      "=====================================\n\n"
    ))

    # Show progress indicator with detailed tracking
    withProgress(message = 'Processing MS110 log files...', value = 0, {

      incProgress(0.05, detail = "Searching for files...")

      tryCatch({
        # Use custom batch processor with progress callback
        results <- process_ms110_batch(
          source_dirs = ms110_source_path(),
          output_dir = ms110_output_path(),
          recursive = input$ms110_recursive,
          clean = input$ms110_clean,
          keep_original = input$ms110_keep_original,
          verbose = input$ms110_verbose,
          progress_callback = function(current, total, filename) {
            # Update progress bar
            incProgress(
              amount = 0.9 * (1 / total),  # Reserve 0.05 for initial, 0.05 for final
              detail = sprintf("File %d/%d: %s", current, total, filename)
            )
          }
        )

        incProgress(0.05, detail = "Finalizing results...")
        ms110_results(results)

        # Show success notification
        success_count <- sum(results$status == "success")
        warning_count <- sum(results$status == "warning")
        error_count <- sum(results$status == "error")

        if (warning_count > 0) {
          notification_msg <- sprintf(
            "Processing complete: %d success, %d warnings, %d errors",
            success_count, warning_count, error_count
          )
          notification_type <- "warning"
        } else if (error_count > 0) {
          notification_msg <- sprintf(
            "Processing complete: %d success, %d errors",
            success_count, error_count
          )
          notification_type <- "warning"
        } else {
          notification_msg <- sprintf(
            "Successfully processed all %d files",
            success_count
          )
          notification_type <- "message"
        }

        showNotification(
          notification_msg,
          type = notification_type,
          duration = 5
        )

      }, error = function(e) {
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = 10
        )
      })

      # Create summary
      if (!is.null(ms110_results())) {
        summary_text <- sprintf(
          "\n\n=== Processing Complete ===\nTotal: %d | Success: %d | Warnings: %d | Failed: %d\n",
          nrow(ms110_results()),
          sum(ms110_results()$status == "success"),
          sum(ms110_results()$status == "warning"),
          sum(ms110_results()$status == "error")
        )
      } else {
        summary_text <- "\n\n=== Processing Complete ===\n"
      }

      # Update final log output
      initial_log <- paste0(
        "=== MS110 Processing Started ===\n",
        "Source: ", ms110_source_path(), "\n",
        "Output: ", ms110_output_path(), "\n",
        "Recursive: ", input$ms110_recursive, "\n",
        "Clean: ", input$ms110_clean, "\n",
        "Verbose: ", input$ms110_verbose, "\n",
        "Keep Original: ", input$ms110_keep_original, "\n",
        "=====================================\n\n"
      )

      ms110_log_output(paste0(
        initial_log,
        summary_text
      ))
    })
  })

  # MS110 Results table
  output$ms110_results_table <- DT::renderDT({
    req(ms110_results())

    DT::datatable(
      ms110_results(),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      extensions = 'Buttons',
      rownames = FALSE,
      class = 'cell-border stripe'
    ) |>
      DT::formatStyle(
        'status',
        backgroundColor = DT::styleEqual(
          c('success', 'warning', 'error'),
          c('#d4edda', '#fff3cd', '#f8d7da')
        )
      )
  })

  # MS110 Processing log
  output$ms110_log <- renderText({
    ms110_log_output()
  })

  # MS110 Summary statistics
  output$ms110_total_files <- renderText({
    results <- ms110_results()
    if (is.null(results)) "0" else as.character(nrow(results))
  })

  output$ms110_success_count <- renderText({
    results <- ms110_results()
    if (is.null(results)) "0" else as.character(sum(results$status == "success"))
  })

  output$ms110_warning_count <- renderText({
    results <- ms110_results()
    if (is.null(results)) "0" else as.character(sum(results$status == "warning"))
  })

  output$ms110_failed_count <- renderText({
    results <- ms110_results()
    if (is.null(results)) "0" else as.character(sum(results$status == "error"))
  })

  # ===========================================================================
  # DB110 Processing Logic
  # ===========================================================================

  # DB110 Source directory selection
  shinyFiles::shinyDirChoose(input, "db110_source_dir", roots = volumes, session = session)

  db110_source_path <- reactive({
    req(input$db110_source_dir)
    shinyFiles::parseDirPath(volumes, input$db110_source_dir)
  })

  output$db110_source_path <- renderText({
    path <- db110_source_path()
    if (length(path) > 0) path else "No directory selected"
  })

  # DB110 Output directory selection
  shinyFiles::shinyDirChoose(input, "db110_output_dir", roots = volumes, session = session)

  db110_output_path <- reactive({
    req(input$db110_output_dir)
    shinyFiles::parseDirPath(volumes, input$db110_output_dir)
  })

  output$db110_output_path <- renderText({
    path <- db110_output_path()
    if (length(path) > 0) path else "No directory selected"
  })

  # DB110 Processing reactive values
  db110_results <- reactiveVal(NULL)
  db110_log_output <- reactiveVal("")

  # DB110 Process button handler
  observeEvent(input$db110_process, {
    req(db110_source_path(), db110_output_path())

    # Clear previous results
    db110_results(NULL)
    db110_log_output("")

    # Initial status message
    db110_log_output(paste0(
      "=== DB110 Processing Started ===\n",
      "Source: ", db110_source_path(), "\n",
      "Output: ", db110_output_path(), "\n",
      "Recursive: ", input$db110_recursive, "\n",
      "Clean: ", input$db110_clean, "\n",
      "Verbose: ", input$db110_verbose, "\n",
      "Keep Original: ", input$db110_keep_original, "\n",
      "=====================================\n\n"
    ))

    # Show progress indicator with detailed tracking
    withProgress(message = 'Processing DB110 log files...', value = 0, {

      incProgress(0.05, detail = "Searching for files...")

      tryCatch({
        # Use custom batch processor with progress callback
        results <- process_db110_batch(
          source_dirs = db110_source_path(),
          output_dir = db110_output_path(),
          recursive = input$db110_recursive,
          clean = input$db110_clean,
          keep_original = input$db110_keep_original,
          verbose = input$db110_verbose,
          progress_callback = function(current, total, filename) {
            # Update progress bar
            incProgress(
              amount = 0.9 * (1 / total),  # Reserve 0.05 for initial, 0.05 for final
              detail = sprintf("File %d/%d: %s", current, total, filename)
            )
          }
        )

        incProgress(0.05, detail = "Finalizing results...")
        db110_results(results)

        # Show success notification
        success_count <- sum(results$status == "success")
        error_count <- sum(results$status == "error")

        if (error_count > 0) {
          notification_msg <- sprintf(
            "Processing complete: %d success, %d errors",
            success_count, error_count
          )
          notification_type <- "warning"
        } else {
          notification_msg <- sprintf(
            "Successfully processed all %d files",
            success_count
          )
          notification_type <- "message"
        }

        showNotification(
          notification_msg,
          type = notification_type,
          duration = 5
        )

      }, error = function(e) {
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = 10
        )
      })

      # Create summary
      if (!is.null(db110_results())) {
        summary_text <- sprintf(
          "\n\n=== Processing Complete ===\nTotal: %d | Success: %d | Failed: %d\n",
          nrow(db110_results()),
          sum(db110_results()$status == "success"),
          sum(db110_results()$status == "error")
        )
      } else {
        summary_text <- "\n\n=== Processing Complete ===\n"
      }

      # Update final log output
      initial_log <- paste0(
        "=== DB110 Processing Started ===\n",
        "Source: ", db110_source_path(), "\n",
        "Output: ", db110_output_path(), "\n",
        "Recursive: ", input$db110_recursive, "\n",
        "Clean: ", input$db110_clean, "\n",
        "Verbose: ", input$db110_verbose, "\n",
        "Keep Original: ", input$db110_keep_original, "\n",
        "=====================================\n\n"
      )

      db110_log_output(paste0(
        initial_log,
        summary_text
      ))
    })
  })

  # DB110 Results table
  output$db110_results_table <- DT::renderDT({
    req(db110_results())

    DT::datatable(
      db110_results(),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      extensions = 'Buttons',
      rownames = FALSE,
      class = 'cell-border stripe'
    ) |>
      DT::formatStyle(
        'status',
        backgroundColor = DT::styleEqual(
          c('success', 'error'),
          c('#d4edda', '#f8d7da')
        )
      )
  })

  # DB110 Processing log
  output$db110_log <- renderText({
    db110_log_output()
  })

  # DB110 Summary statistics
  output$db110_total_files <- renderText({
    results <- db110_results()
    if (is.null(results)) "0" else as.character(nrow(results))
  })

  output$db110_success_count <- renderText({
    results <- db110_results()
    if (is.null(results)) "0" else as.character(sum(results$status == "success"))
  })

  output$db110_failed_count <- renderText({
    results <- db110_results()
    if (is.null(results)) "0" else as.character(sum(results$status != "success"))
  })
}
