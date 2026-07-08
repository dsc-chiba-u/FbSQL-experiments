# Render the related-work comparison template (data/related_work.csv, the
# hand-maintained source of truth) as a Markdown pipe table for drafting
# the manuscript. Cells still to be evaluated are marked TBD.
#
# Run inside the fbsql-dev container from the repo root:
#     docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/exp -w /exp fbsql-dev \
#         Rscript scripts/50_make_related_work_table.R
#
# Base R only (the pinned container has no knitr).

rw <- read.csv("data/related_work.csv", stringsAsFactors = FALSE,
               check.names = FALSE)

md_escape <- function(x) gsub("|", "\\|", x, fixed = TRUE)
md_row <- function(cells) paste0("| ", paste(md_escape(cells), collapse = " | "), " |")

lines <- c(
    md_row(names(rw)),
    md_row(rep("---", ncol(rw))),
    vapply(seq_len(nrow(rw)),
           function(i) md_row(unlist(rw[i, ], use.names = FALSE)),
           character(1L))
)

dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)
writeLines(lines, "results/tables/related_work.md")
cat("OK: wrote results/tables/related_work.md (",
    nrow(rw), "systems x", ncol(rw), "columns )\n")
