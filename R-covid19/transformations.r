###########################################################
## Helper functions
###########################################################

articleView <- function(metadata, cordUids) {
  metadata %>% filter(cord_uid %in% cordUids) %>% View
}

distinctArticleCount <- function(data) {
  data %>%
    select(cord_uid) %>%
    distinct() %>% nrow
}

sortedFreqs <- function(column) {
  DT <- column %>% data.table(entity = .) 
  DT[, .(cnt=.N), by=.(entity)][order(-cnt)]
}

replacePattern <- function(text, rules) {
  pmap(list(names(rules), rules), list) %>% 
    reduce(
      .f=function(txt, repl) {
        str_replace_all(txt, repl[[1]], repl[[2]])
      }, 
      .init=text
    )
}

extractAllAuthors <- function(metadata) {
  metadata %>% 
    select(row_id, cord_uid, source_x, authors, title) %>% 
    # separate_rows(authors, sep=";") %>%  # too slow
    .[, .(authors =  unlist(strsplit(authors, ";", fixed = TRUE))), 
      by = .(row_id, cord_uid, source_x, title)] %>%
    mutate(
      authors=str_trim(authors)
    ) %>%
    distinct() %>%
    mutate(
      author_row=row_number()
    )
}

