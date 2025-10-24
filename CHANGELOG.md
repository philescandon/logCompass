# Changelog

All notable changes to Log Compass will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-23

### Added
- Initial release of Log Compass
- MS110 info.log batch processing functionality
- Interactive Shiny web interface using bslib/Bootstrap 5
- Directory selection with shinyFiles
- Real-time processing log capture
- Interactive results table with DT
- Export functionality (CSV, Excel)
- Summary statistics dashboard with value boxes
- Processing options:
  - Recursive directory search
  - Log file cleaning (continuation line merging)
  - Keep/remove original files
  - Verbose output mode
- Comprehensive documentation:
  - README.md with user guide
  - ARCHITECTURE.md with technical details
  - QUICKSTART.md for rapid onboarding
  - Inline code documentation
- Utility functions for:
  - File processing and validation
  - Timestamp formatting
  - File size formatting
  - Summary statistics generation
  - Report generation
- Modern UI features:
  - Responsive layout
  - Card-based design
  - Tab-based navigation
  - Progress notifications
  - Error handling with user feedback

### Technical Details
- Follows Mastering Shiny best practices
- Modular architecture (ui.R, server.R, utils/)
- Reactive programming patterns
- Integration with aerolog v1.0.0 package
- Tidyverse data processing pipeline

### Known Limitations
- DB110 batch processing not yet implemented (coming in v1.1)
- No download functionality for processing reports (coming in v1.1)
- No file preview before processing (coming in v1.1)
- Processing is blocking (no async support yet)

## [Unreleased]

### Planned for v1.1
- DB110 errorlog.log batch processing
- Download processing reports as PDF/HTML
- File preview functionality
- Advanced filtering (date range, sensor ID)
- Processing history persistence
- Progress bars for long operations

### Planned for v2.0
- Log file analysis and visualization
- Error pattern detection
- Timeline visualization
- Integration with other Compass apps
- Docker deployment support
- Async processing with promises
- Database backend for history

---

**Maintainer**: Phillip Escandon (Phillip.Escandon@pm.me)
**Repository**: Part of the Compass Suite
**License**: MIT
