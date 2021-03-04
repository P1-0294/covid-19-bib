###########################################################
## Helper functions
###########################################################

articleView <- function(metadata, cordUids, short=FALSE) {
  metadata %>% 
    filter(cord_uid %in% cordUids) %>% 
    (function(data) {
      if(short) {
        data %>% select(cord_uid, title, authors)
      } else {
        data
      }
    }) %>% 
    View
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

authorTitleLinksInExcel <- function(data, fname) {
  data %>% 
    select(source_x, title, authors) %>%
    mutate(
      url = sprintf("https://www.google.com/search?q=%s", str_replace_all(title, " ", "+"))
    ) %>%
    (function(data) {
      class(data$url) <- "hyperlink"
      data
    }) %>% 
    write.xlsx(fname)
}
