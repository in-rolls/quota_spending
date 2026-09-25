# West Bengal rows of the all-India MNREGA reports, for the spending analysis.
#
#   Rscript --vanilla wb/scripts/04_spending_extract.R
#
# The only WB script that touches the network, and it is not called by run.R.
# The all-India r1/r3/r6 files are the published copies in doi:10.7910/DVN/ZHF9WC;
# their datafile ids and md5s are read from the dataset's own file listing, not
# ../DATAVERSE.md, which lists only the files deleted locally. Each file is
# cached under $INDIA_DATA_HOME/mnrega_dataverse, checked against its md5, and
# reduced to its WEST BENGAL rows with every original column
# kept and nothing recoded. The extracts and their provenance are tracked; the
# all-India files are not.

wb_spending_reports <- c("r1", "r3", "r6")
wb_spending_years <- 2013:2022

wb_dataverse_files <- function() {
  listing <- jsonlite::fromJSON(paste0(
    "https://dataverse.harvard.edu/api/datasets/:persistentId/versions/:latest/files",
    "?persistentId=doi:10.7910/DVN/ZHF9WC"
  ))$data$dataFile
  report <- sub("^(r\\d)[_-].*", "\\1", listing$filename)
  data.frame(
    path = file.path("data", "mnrega", report, listing$filename),
    datafile = as.character(listing$id),
    md5 = listing$md5
  )
}

wb_cached_report <- function(entry) {
  home <- path.expand(Sys.getenv("INDIA_DATA_HOME", "~/data"))
  target <- file.path(home, "mnrega_dataverse", sub("^data/mnrega/", "", entry$path))
  if (!file.exists(target)) {
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    url <- paste0("https://dataverse.harvard.edu/api/access/datafile/", entry$datafile)
    utils::download.file(url, target, mode = "wb", quiet = TRUE)
  }
  if (unname(tools::md5sum(target)) != entry$md5) {
    stop("md5 mismatch against Dataverse for ", target)
  }
  target
}

wb_extract_report <- function(entry, out_dir) {
  source_file <- wb_cached_report(entry)
  raw <- utils::read.csv(gzfile(source_file),
    colClasses = "character", check.names = FALSE, na.strings = character()
  )
  state_columns <- names(raw)[tolower(names(raw)) == "state"]
  if (!length(state_columns)) stop("No state column in ", entry$path)
  state <- do.call(pmax, c(lapply(raw[state_columns], toupper), na.rm = TRUE))
  keep <- raw[!is.na(state) & state == "WEST BENGAL", , drop = FALSE]
  if (!nrow(keep)) stop("No West Bengal rows in ", entry$path)
  year <- as.integer(sub(".*-(\\d{4})\\.csv\\.gz$", "\\1", entry$path))
  report <- sub("^data/mnrega/(r\\d).*", "\\1", entry$path)
  target <- file.path(out_dir, sprintf("%s_wb_%d.csv.gz", report, year))
  connection <- gzfile(target, "w")
  utils::write.csv(keep, connection, row.names = FALSE, na = "")
  close(connection)
  list(
    path = file.path("data", "spending_raw", basename(target)),
    sha256 = digest::digest(file = target, algo = "sha256"),
    report = report,
    file_year = year,
    raw_source = entry$path,
    dataverse = paste0("doi:10.7910/DVN/ZHF9WC datafile ", entry$datafile),
    raw_source_md5 = entry$md5,
    extraction = "state == WEST BENGAL; original columns retained; no recoding",
    rows = nrow(keep),
    rows_all_india = nrow(raw)
  )
}

wb_spending_extract <- function(module_root) {
  files <- wb_dataverse_files()
  wanted <- sprintf(
    "data/mnrega/%s/%s-all-%d.csv.gz",
    rep(wb_spending_reports, each = length(wb_spending_years)),
    rep(wb_spending_reports, each = length(wb_spending_years)),
    wb_spending_years
  )
  missing <- setdiff(wanted, files$path)
  if (length(missing)) stop("Not in the Dataverse dataset: ", paste(missing, collapse = ", "))
  out_dir <- file.path(module_root, "data", "spending_raw")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  provenance <- lapply(wanted, function(path) {
    record <- wb_extract_report(files[files$path == path, ], out_dir)
    cat(sprintf("  %-34s %5d WB rows\n", basename(record$path), record$rows))
    record
  })
  jsonlite::write_json(provenance, file.path(out_dir, "extraction_provenance.json"),
    auto_unbox = TRUE, pretty = TRUE
  )
  invisible(provenance)
}

if (sys.nframe() == 0) {
  invocation <- grep("^--file=", commandArgs(), value = TRUE)
  wb_spending_extract(dirname(dirname(normalizePath(sub("^--file=", "", invocation[1])))))
}
