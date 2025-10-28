#' Log Compass UI
#'
#' User interface for Log Compass application
#' Follows bslib and modern Shiny UI best practices
#'
#' Architecture: Three main operational modes
#' 1. Quick View: Rapid single-file viewing
#' 2. Batch Process: MS110 and DB110 batch processing
#' 3. Pod Compass Analysis: Comparative analysis (future)

# Source Quick View module
source("R/modules/quick_view_module.R", local = TRUE)

ui <- bslib::page_navbar(
  title = tags$div(
    style = "display: inline-flex; align-items: center; gap: 8px;",
    tags$img(
      src = "RTX.png",
      height = "28px",
      style = "display: inline-block;"
    ),
    tags$span("Log Compass", style = "font-weight: 500; font-size: 1.25rem;")
  ),
  id = "main_navbar",  # Add ID for programmatic tab switching
  theme = bslib::bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#0066CC",
    base_font = bslib::font_google("Open Sans")
  ),

  # ===========================================================================
  # TAB 1: Quick View
  # ===========================================================================
  bslib::nav_panel(
    title = "Quick View",
    icon = icon("eye"),
    value = "quick_view",  # Add value for tab identification

    # Introductory info card
    div(
      style = "margin-bottom: 20px;",
      bslib::accordion(
        id = "welcome_accordion",
        open = FALSE,  # Start collapsed to save space
        bslib::accordion_panel(
          title = "Using Log Compass & Preprocessing Workflow",
          icon = icon("circle-info"),
          shiny::markdown(
            "
            **Quick View** provides rapid analysis of single MS110 or DB110 log files without batch processing.

            ### Features
            - Automatic log type detection (MS110/DB110)
            - Structured display: Metadata, SBIT Results, Boot Milestones, System Messages
            - Searchable and filterable test results
            - Export cleaned logs and SBIT results

            ### Preprocessing Workflow

            Before using Quick View, you may want to preprocess your logs using the **Preprocess MS110 Logs** or **Preprocess DB110 Logs** tabs:

            1. Navigate to the appropriate preprocessing tab (MS110 or DB110)
            2. Select source directory containing raw log files (`info.log` or `errorlog.log`)
            3. Choose output directory for processed files
            4. Click **Process** - files are automatically renamed with metadata:
               - **MS110**: `info_SENSORID_EPOCH_MISSIONID.log`
               - **DB110**: `errorlog_SENSORID_EPOCH_MISSIONID.log`
               - **Example**: `info_12345ABC_20250128_FlightTest.log`
            5. Logs are cleaned (merged continuation lines, fixed contractions)

            **Then** use Quick View to explore individual processed files.

            ### Quick Start

            1. Click **Browse Files** below to select a log file
            2. View structured results in the tabs (Metadata, SBIT Results, Boot Milestones, etc.)
            3. Search and filter test results
            4. Download cleaned logs or export SBIT results as needed

            ---

            **Select a log file below to begin** →
            "
          )
        )
      )
    ),

    quick_view_ui("quick_view")
  ),

  # ===========================================================================
  # TAB 2: MS110 Processing
  # ===========================================================================
  bslib::nav_panel(
    title = "Preprocess MS110 Logs",
    icon = icon("file-lines"),
    value = "ms110_batch",

    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        title = "MS110 Processing Options",
        width = 350,

        # Source directory selection
        bslib::card(
          bslib::card_header("Source Directory"),
          shinyFiles::shinyDirButton(
            "ms110_source_dir",
            "Select Source Directory",
            "Select directory containing info.log files"
          ),
          verbatimTextOutput("ms110_source_path", placeholder = TRUE)
        ),

        # Output directory selection
        bslib::card(
          bslib::card_header("Output Directory"),
          shinyFiles::shinyDirButton(
            "ms110_output_dir",
            "Select Output Directory",
            "Select directory for processed files"
          ),
          verbatimTextOutput("ms110_output_path", placeholder = TRUE)
        ),

        # Processing options
        bslib::card(
          bslib::card_header("Processing Options"),
          checkboxInput("ms110_recursive", "Search subdirectories recursively", value = TRUE),
          checkboxInput("ms110_clean", "Clean log files (merge continuation lines)", value = TRUE),
          checkboxInput("ms110_keep_original", "Keep original files", value = FALSE),
          checkboxInput("ms110_verbose", "Verbose output", value = FALSE)
        ),

        # Process button
        actionButton(
          "ms110_process",
          "Process MS110 Logs",
          icon = icon("play"),
          class = "btn-primary btn-lg w-100"
        )
      ),

      # Main content area
      bslib::card(
        bslib::card_header(
          "Processing Results",
          class = "bg-primary text-white"
        ),
        bslib::navset_card_tab(
          bslib::nav_panel(
            "Results Table",
            DT::DTOutput("ms110_results_table")
          ),
          bslib::nav_panel(
            "Processing Log",
            verbatimTextOutput("ms110_log")
          ),
          bslib::nav_panel(
            "Summary Statistics",
            bslib::value_box(
              title = "Total Files Found",
              value = textOutput("ms110_total_files"),
              showcase = icon("file"),
              theme = "primary"
            ),
            bslib::value_box(
              title = "Successfully Processed",
              value = textOutput("ms110_success_count"),
              showcase = icon("circle-check"),
              theme = "success"
            ),
            bslib::value_box(
              title = "Warnings",
              value = textOutput("ms110_warning_count"),
              showcase = icon("triangle-exclamation"),
              theme = "warning"
            ),
            bslib::value_box(
              title = "Failed",
              value = textOutput("ms110_failed_count"),
              showcase = icon("circle-xmark"),
              theme = "danger"
            )
          )
        )
      )
    )
  ),

  # ===========================================================================
  # TAB 3: DB110 Processing
  # ===========================================================================
  bslib::nav_panel(
    title = "Preprocess DB110 Logs",
    icon = icon("triangle-exclamation"),
    value = "db110_batch",

    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        title = "DB110 Processing Options",
        width = 350,

        # Source directory selection
        bslib::card(
          bslib::card_header("Source Directory"),
          shinyFiles::shinyDirButton(
            "db110_source_dir",
            "Select Source Directory",
            "Select directory containing errorlog.log files"
          ),
          verbatimTextOutput("db110_source_path", placeholder = TRUE)
        ),

        # Output directory selection
        bslib::card(
          bslib::card_header("Output Directory"),
          shinyFiles::shinyDirButton(
            "db110_output_dir",
            "Select Output Directory",
            "Select directory for processed files"
          ),
          verbatimTextOutput("db110_output_path", placeholder = TRUE)
        ),

        # Processing options
        bslib::card(
          bslib::card_header("Processing Options"),
          checkboxInput("db110_recursive", "Search subdirectories recursively", value = TRUE),
          checkboxInput("db110_clean", "Clean log files", value = TRUE),
          checkboxInput("db110_keep_original", "Keep original files", value = FALSE),
          checkboxInput("db110_verbose", "Verbose output", value = FALSE)
        ),

        # Process button
        actionButton(
          "db110_process",
          "Process DB110 Logs",
          icon = icon("play"),
          class = "btn-primary btn-lg w-100"
        )
      ),

      # Main content area
      bslib::card(
        bslib::card_header(
          "Processing Results",
          class = "bg-primary text-white"
        ),
        bslib::navset_card_tab(
          bslib::nav_panel(
            "Results Table",
            DT::DTOutput("db110_results_table")
          ),
          bslib::nav_panel(
            "Processing Log",
            verbatimTextOutput("db110_log")
          ),
          bslib::nav_panel(
            "Summary Statistics",
            bslib::value_box(
              title = "Total Files Found",
              value = textOutput("db110_total_files"),
              showcase = icon("file"),
              theme = "primary"
            ),
            bslib::value_box(
              title = "Successfully Processed",
              value = textOutput("db110_success_count"),
              showcase = icon("circle-check"),
              theme = "success"
            ),
            bslib::value_box(
              title = "Failed",
              value = textOutput("db110_failed_count"),
              showcase = icon("circle-xmark"),
              theme = "danger"
            )
          )
        )
      )
    )
  ),

  # ===========================================================================
  # TAB 4: About
  # ===========================================================================
  bslib::nav_panel(
    title = "About",
    icon = icon("circle-info"),
    value = "about",

    bslib::card(
      bslib::card_header("About Log Compass"),
      shiny::markdown(
        "
        ## Log Compass Suite

        **Navigate and Process Aerospace Sensor Log Files**

        Log Compass is part of the **Compass Suite** of tools designed for aerospace
        sensor data analysis and processing.

        ### Three Operational Modes

        #### 1. Quick View
        Rapidly view and explore single log files without batch processing:
        - Automatic log type detection (MS110/DB110)
        - Structured display of metadata, SBIT results, boot milestones
        - Search and filter test results
        - Export cleaned logs and SBIT results

        #### 2. Batch Process
        Bulk processing, cleaning, and renaming of log files:
        - **Preprocess MS110 Logs**: Process MS110 info.log files
        - **Preprocess DB110 Logs**: Process DB110 errorlog.log files
        - Automatic metadata extraction
        - Smart renaming with sensor ID, epoch, and mission ID
        - Log cleaning (merge continuation lines, fix contractions)
        - Recursive directory processing

        #### 3. Pod Compass Analysis (Coming Soon)
        Deep comparative analysis with automatic mode detection:
        - **Single Pod Mode**: Temporal analysis for one sensor
        - **Multi-Pod Fleet Mode**: Comparative fleet analysis
        - Failure trend analysis and pattern detection
        - Mission capability assessment (FMC/PMC/NMC)
        - Comprehensive report generation

        ### Workflow Examples

        **Quick Read**: Select file → View structured log → Done

        **Batch Processing**: Select directory → Process files → Review results

        **Deep Analysis**: Process files → Select subset → Analyze in Pod Compass

        ### Powered By

        - **aerolog**: Core R package for log parsing
        - **ms110**: MS110-specific processing
        - **db110**: DB110-specific processing
        - **Shiny**: Interactive web framework
        - **bslib**: Modern Bootstrap UI

        ### Author

        **Phillip Escandon**
        Email: Phillip.Escandon@pm.me
        Organization: RTX - Image Science

        ### Version

        **v2.0** - Unified Tool with Pod Compass Integration

        ---

        *Part of the Compass Suite*
        "
      )
    )
  ),

  # Footer
  bslib::nav_spacer(),
  bslib::nav_item(
    tags$span(
      "Compass Suite © 2025",
      class = "navbar-text"
    )
  )
)
