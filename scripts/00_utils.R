# Gen. Util. Functions

# Remove diacritics, convert to lowercase, convert to single ws, trim extra ws, remove punct
normalize_string <- function(input_string) {
     normalized_string <- stri_trans_general(input_string, "Latin-ASCII")
     normalized_string <- stri_trans_tolower(normalized_string)
     normalized_string <- gsub("\\s+", " ", normalized_string)
     normalized_string <- trimws(normalized_string)
     normalized_string <- gsub("[[:punct:]]", "", normalized_string)
     return(normalized_string)
}

# Remove NA columns
remove_na_columns <- function(df) {
     na_percentages <- df %>% summarise(across(everything(), ~sum(is.na(.)) / n() * 100))
     df <- df %>% select(where(~sum(is.na(.)) < nrow(df)))
     return(df)
}

# Add year suffix
add_year_suffix_remove_year_col <- function(df) {
     
     suffix <- paste0("_", unique(df$year))
     df <- df %>%
          rename_with(~paste0(.x, suffix), -c(key, year)) %>%
          select(-year)
     return(df)
}

# Proportion significant p-values in a list of models via tidy
proportion_significant_pvalues <- function(models) {

count_significant_pvalues <- function(model) {
     tidy_model <- tidy(model)
     tidy_model %>%
          filter(term != "(Intercept)" & p.value < 0.05) %>%
          nrow()
}

count_coefficients <- function(model) {
     tidy_model <- tidy(model)
     tidy_model %>%
          filter(term != "(Intercept)") %>%
          nrow()
}

total_significant_pvalues <- models %>%
     map_dbl(count_significant_pvalues) %>%
     sum()

total_coefficients <- models %>%
     map_dbl(count_coefficients) %>%
     sum()

proportion_significant <- total_significant_pvalues / total_coefficients
proportion_significant
}

## Custom Stargazer

library(stargazer)

# Constant term 
cons_term <- "Statistical significance symbols for the constant terms are suppressed."

custom_stargazer <- function(models, notes, digits = 2, float.env = "table", ..., out = NULL) {
     stargazer_output <- capture.output(
          stargazer(
               models,
               header = FALSE,
               type = "latex",
               model.names = FALSE,
               omit.stat = c("rsq", "ser", "f"),
               digits = digits,
               column.sep.width = "0pt",
               dep.var.caption = "",
               dep.var.labels.include = FALSE,
               star.cutoffs = c(0.05, 0.01, 0.001),
               report = "vc*s",
               no.space = TRUE,
               single.row = FALSE,
               font.size = "scriptsize",
               notes.append = FALSE,
               notes = NULL,
               notes.align = "l",
               ...
          )
     )
     
     repeat {
          new_output <- gsub(
               pattern = "(Constant.*?)(\\$.*?\\$)",
               replacement = "\\1",
               x = stargazer_output,
               perl = TRUE
          )
          if(identical(new_output, stargazer_output)) break
          stargazer_output <- new_output
     }
     
     
     
     # Remove any existing table or sidewaystable environments
     stargazer_output <- stargazer_output[
          !grepl("\\\\begin\\{table\\}|\\\\end\\{table\\}|\\\\begin\\{sidewaystable\\}|\\\\end\\{sidewaystable\\}", stargazer_output)
     ]
     
     # Generate the output for `table`
     if (float.env == "table") {
          wrapped_output <- paste0(
               "\\begin{table}[!htbp]\n",
               "\\centering\n",
               "\\begin{threeparttable}\n",
               paste(stargazer_output, collapse = "\n"),
               "\n\\begin{tablenotes}[flushleft]\n\\scriptsize\n",
               paste0("\\item[] ", notes, collapse = "\n"),
               "\n\\end{tablenotes}\n",
               "\\end{threeparttable}\n",
               "\\end{table}"
          )
     }
     # Generate the output for `sidewaystable`
     else if (float.env == "sidewaystable") {
          wrapped_output <- paste0(
               "\\begin{sidewaystable}[!htbp]\n",
               "\\centering\n",
               "\\begin{threeparttable}\n",
               paste(stargazer_output, collapse = "\n"),
               "\n\\begin{tablenotes}[flushleft]\n\\setlength{\\itemindent}{0em}\n\\scriptsize\n",
               paste0("\\item[] ", notes, collapse = "\n"), # Add custom multiline notes
               "\n\\end{tablenotes}\n",
               "\\end{threeparttable}\n",
               "\\end{sidewaystable}"
          )
     } else {
          stop("Invalid float_env. Use 'table' or 'sidewaystable'.")
     }
     
     # Write to file or print to console
     if (!is.null(out)) {
          writeLines(wrapped_output, con = out)
     } else {
          cat(wrapped_output, sep = "\n")
     }
}

## ---------------------------------------------------------------------------
## Data this repo uses but does not own
## ---------------------------------------------------------------------------
## data/manifest.yaml pins a version and a sha256 for every file that another
## repository produces. sibling_path() resolves one: cache, then a sibling clone,
## then a download -- and verifies the checksum before returning, every time,
## including on the cache hit. A mismatch stops the run; it never silently hands
## back different data.
##
## The point is not disk space. quota_spending, quota_representation, local_elections and others all
## read the same UP sarpanch files, and until now each kept its own copy with
## nothing to notice when they drifted apart.

.manifest <- function() {
     yaml::read_yaml(here::here("data", "manifest.yaml"))
}

.cache_root <- function(man) {
     root <- Sys.getenv("INDIA_DATA_HOME", unset = man$cache_dir)
     path.expand(root)
}

sibling_path <- function(file, source = "local_elections_up") {
     man <- .manifest()
     spec <- man$upstream[[source]]
     if (is.null(spec))
          stop("no manifest entry for source '", source, "'", call. = FALSE)

     want <- spec$files[[file]]
     if (is.null(want))
          stop(file, " is not pinned in data/manifest.yaml for ", source, ".\n",
               "  Add it with its sha256 rather than reading an unpinned copy.",
               call. = FALSE)

     dest <- file.path(.cache_root(man), source, spec$ref, file)

     if (!file.exists(dest)) {
          dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
          local <- file.path(spec$sibling, file)
          if (file.exists(local)) {
               file.copy(local, dest)
          } else {
               url <- paste(spec$raw, spec$ref, file, sep = "/")
               message("Fetching ", file, " from ", source, "@", spec$ref)
               utils::download.file(url, dest, mode = "wb", quiet = TRUE)
          }
     }

     got <- digest::digest(dest, algo = "sha256", file = TRUE)
     if (!identical(got, want)) {
          unlink(dest)
          stop(file, " does not match the sha256 pinned in data/manifest.yaml.\n",
               "  expected ", want, "\n  got      ", got, "\n",
               "  Either ", source, "@", spec$ref, " changed, or the copy is corrupt.",
               call. = FALSE)
     }
     dest
}

## Convenience wrappers so call sites read as what they are.
up_path  <- function(f) sibling_path(file.path("data/fin", f))
ref_path <- function(f) sibling_path(file.path("data/external/weaver", f))

## Reference datasets: public downloads shared by several repos, held once in the
## cache rather than copied into each. Unlike sibling_path() there is nothing to
## fetch from -- SHRUG is a manual download from devdatalab.org -- so an absent
## file is reported with the instructions to get it rather than failing obscurely.

reference_path <- function(rel, key = "shrug") {
     man <- .manifest()
     spec <- man$reference[[key]]
     if (is.null(spec))
          stop("no reference entry for '", key, "' in data/manifest.yaml", call. = FALSE)

     dest <- file.path(.cache_root(man), spec$cache, rel)
     if (!file.exists(dest))
          stop(key, " file not in the cache: ", rel, "\n",
               "  expected at: ", dest, "\n",
               "  ", key, " ", spec$version, " is a manual download from ", spec$source,
               "\n  Set INDIA_DATA_HOME to point elsewhere if the cache lives on another disk.",
               call. = FALSE)

     want <- spec$files[[rel]]
     if (!is.null(want)) {
          got <- digest::digest(dest, algo = "sha256", file = TRUE)
          if (!identical(got, want))
               stop(rel, " does not match the sha256 pinned in data/manifest.yaml.\n",
                    "  expected ", want, "\n  got      ", got, "\n",
                    "  The cached copy differs from the one the results were built on.",
                    call. = FALSE)
     }
     dest
}

shrug_path <- function(rel) reference_path(rel, "shrug")

raj_path <- function(file) sibling_path(file, source = "local_elections_rajasthan")
