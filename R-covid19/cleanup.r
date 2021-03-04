## Comment
## `test.xxx` variables contain cord_uids of papers on which certain anomalies are detected.
## Use metadata0 %>% articleView(test.xxx) to see original entries

###########################################################
## Packages, code
###########################################################

packages <- c(
  "readr", 
  "dplyr", 
  "tidyr", 
  "tictoc", 
  "stringr", 
  "openxlsx", 
  "rvest", 
  "purrr", 
  "data.table",
  "tools",
  "utf8"
)

for (package in packages) {
  if (!package %in% installed.packages()) {
    install.packages(
      package,
      dependencies = TRUE
    )
  }
  if (!package %in% .packages()) {
    library(
      package,
      character.only = TRUE
    )
  }
}

source("transformations.r")

###########################################################
## Settings
###########################################################

# If you do not have current metadata, set DOWNLOAD to TRUE and run the below if statement
DATA_FOLDER <- "../../data"
PATH_TO_DATA <- file.path(DATA_FOLDER, "latest_metadata")
METADATA <- file.path(PATH_TO_DATA, "metadata.csv") 
TMP_DATA_FOLDER <- "tmp_data"
dir.create(TMP_DATA_FOLDER, showWarnings = FALSE)
DOWNLOAD <- TRUE
LOAD <- TRUE

# Download metadata.csv from 
# https://ai2-semanticscholar-cord-19.s3-us-west-2.amazonaws.com/historical_releases.html
# Place the file metadata.csv (possibly fix the path)
# metadata.csv size is 0.5GB hence it is not part of the git repositry
# MD5: 31.12.2020: ad5769ec1f38307501e0161db3ed014a
# require(tools)
# md5sum(METADATA)


###########################################################
## Download the last version of metadata
###########################################################

if (DOWNLOAD) {
  downloadURL <- "https://ai2-semanticscholar-cord-19.s3-us-west-2.amazonaws.com/historical_releases.html"
  
  latestReleaseDate <- read_html(downloadURL) %>% 
    toString() %>%
    str_extract("Latest release\\:\\s*\\d{4}\\-\\d{2}\\-\\d{2}") %>%
    str_extract("\\d{4}\\-\\d{2}\\-\\d{2}")

  DATE_FILE <- file.path(PATH_TO_DATA, paste0(latestReleaseDate, ".date"))
  
  if(!file.exists(DATE_FILE)) {
    message(sprintf("Downloading latest 'metadata.csv' for the date %s.", latestReleaseDate))
    # Download latest release data to
    # https://ai2-semanticscholar-cord-19.s3-us-west-2.amazonaws.com/YYYY-MM-dd/metadata.csv
    
    metadataURL <- sprintf("https://ai2-semanticscholar-cord-19.s3-us-west-2.amazonaws.com/%s/metadata.csv", latestReleaseDate)
    dir.create(DATA_FOLDER, showWarnings = FALSE)
    dir.create(PATH_TO_DATA, showWarnings = FALSE)
    if(file.exists(METADATA)) {
      message(sprintf("Existing file MD5: %s", md5sum(METADATA)))
    }
    download.file(metadataURL, METADATA)
    # clean up all .date files
    for(file in list.files(path = PATH_TO_DATA, pattern = "\\.date")) {
      file.remove(file.path(PATH_TO_DATA, file))
    }
    file.create(DATE_FILE)
    message(sprintf("Latest 'metadata.csv' (%s) downloaded. MD5: %s", latestReleaseDate, md5sum(METADATA)))
  } else {
    message(sprintf("Latest 'metadata.csv' up to date (%s).", latestReleaseDate))
  }
}

###########################################################
## Load metadata.csv
###########################################################

{
  message("Loading metadata.")
  tic()
  if(LOAD) {
    metadata <- fread(METADATA, colClasses = c("character"))
    metadata0 <- metadata
  }
  toc()   # much faster, takes < 8s
}

###########################################################
## General transformations
###########################################################

## METADATA: `Add row_id`
if(! ("row_id" %in% names(metadata))) {
  metadata <- metadata %>% mutate(row_id = row_number())
}


# METADATA: Add column `cord_uid_cnt` (number of apperances of cord_uid)
cordUidAppearanceCount <- metadata %>%
  .[, .(cord_uid_cnt=.N), by=cord_uid] %>%
  .[order(-cord_uid_cnt)]

if(! ("cord_uid_cnt" %in% names(metadata))) {
  # dtplyr joins seems to be quite fast. 
  # For further optimizations see: https://gist.github.com/kar9222/c2bf12eb9b4142dd97c5e151b8977bc1
  metadata <- metadata %>% 
    left_join(cordUidAppearanceCount, by="cord_uid")
}

## METADATA: Add column 'author_diff_cnt` (how many different `authors` strings at the same `cord_uid`)
differentAuthorsStringCnt <- metadata %>%
  . [,.(author_diff_cnt=length(unique(authors))), by=.(cord_uid, cord_uid_cnt)] %>%
  . [order(-author_diff_cnt, -cord_uid_cnt )]

if(! ("author_diff_cnt" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(differentAuthorsStringCnt %>% select(cord_uid, author_diff_cnt), by="cord_uid")
}

test.moreThan3Author <- metadata %>% 
  filter(author_diff_cnt > 2) %>% pull(cord_uid) %>% unique

message(sprintf("%d papers with more than 3 different author strings thrown out. Some should be inspected in detail.", test.moreThan3Author %>% length))

## METADATA DROP: filter out cases with more than 3 different author strings
metadata <- metadata %>% 
  filter(author_diff_cnt <= 2)


## METADATA: add strange_1 column for wrongly separated authors not from WHO
# All cases longer than 40, without `;` and not from WHO
# Only 16 such papers, all unique
maxLenLow <- 40
toLongAuthors40NotWHO <- metadata %>% 
  filter(source_x != "WHO", str_length(authors) > maxLenLow, !str_detect(authors, ";")) %>% 
  select(row_id, cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files) %>% 
  mutate(auth_len = str_length(authors)) %>% 
  arrange(auth_len)

## add strange_1 column
if(! ("strange_1" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(toLongAuthors40NotWHO %>% select(row_id) %>% mutate(strange_1 = 1), by="row_id")
}

# METADATA: add strange_2 column for long wrongly parsed authors from WHO
# Long `authors` lists from WHO
minLengthWHO <- 40
longWHOStrange <- metadata %>% 
  filter(source_x == "WHO", str_length(authors) > minLengthWHO, !str_detect(authors, ";")) %>% 
  select(row_id, cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files, title) %>% 
  mutate(auth_len = str_length(authors)) %>% 
  arrange(auth_len)

# add `strange_2` column
if(! ("strange_2" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(longWHOStrange %>% select(row_id) %>% mutate(strange_2 = 1), by="row_id")
}

## METADATA: dropping strange_1 and strange_2

test.strange1 <- metadata %>%
  filter(strange_1 == 1) %>%
  pull(cord_uid) %>%
  unique()

test.strange2 <- metadata %>%
  filter(strange_2 == 1) %>%
  pull(cord_uid) %>%
  unique()


message(sprintf("Dropping %d of 'strange_1' and %d of 'strange_2.", test.strange1 %>% length(), test.strange2 %>% length))
metadata %>%
  filter(strange_2 == 1) %>%
  pull(cord_uid) %>%
  unique %>%
  (function(strangeIds) {
    metadata %>% filter(cord_uid %in% strangeIds)
  }) %>%
  .[,.N, by=cord_uid] %>% 
  (function(data) {
    all <- data %>% nrow
    test.strange2.single.entry <- data %>% pull(cord_uid)
    onlyOne <- data[N < 2, .(.N)]$N
    sprintf("%d of %d of 'strange_2' (%.1f%%) is single entry", onlyOne, all, onlyOne/all*100)
  }) %>%
  message

# METADATA: drop `strange_1` and `strange_2`
metadata <- metadata %>% 
  filter(is.na(strange_1) & is.na(strange_2)) %>%
  select(-strange_1, -strange_2)

## METADATA: 039 -> "'" - fixing separation
apostrophePattern <- "039[\\;\\, ][ \\;]? ?"
test.apostrophe039 <- metadata %>% 
  filter(str_detect(authors, apostrophePattern)) %>%
  pull(cord_uid) %>%
  unique() 

message(sprintf("Fixing apostrophe character 039 code in %d papers.", test.apostrophe039 %>% length))
metadata <- metadata %>% 
  mutate(
    authors_0 = authors,
    authors=str_replace_all(authors, apostrophePattern, "'")
  ) %>%
  mutate(
    authors_1 = authors,
    authors=str_replace_all(authors, "\\;\\,", ",") # 2 cases, it seems to be correct like this
  )

###########################################################
## Cleaning up authors
###########################################################

{
  message("Extracting authors")
  tic()
  allAuthors <- extractAllAuthors(metadata)
  toc()
}

## Cleaning up wrong 'amp' papers. Mostly turkish papers. Not many.
ampExpression <- "( amp()[,;][,;]? ?[^\\,\\;]+)[\\,\\;]\\;? ?"
ampAuthors <- metadata %>% 
  filter(str_detect(authors, ampExpression)) 

if(! ("amp" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(ampAuthors %>% select(row_id) %>% mutate(amp = 1), by="row_id")
}

test.ampAuthors <- ampAuthors %>% 
  pull(cord_uid) %>% 
  unique()

message(sprintf("Dropping %s papers with wrong &amp metacharacters (unrecoverable)", test.ampAuthors %>% length()))
# METADATA: drop `amp`
metadata <- metadata %>% 
  filter(is.na(amp)) %>%
  select(-amp)


# METADATA: drop some other 'amp' related papers (unparsable)
amp2pattern <- "(amp,;)|(Iacute,;)|(Uuml,;)|(acute[,;])|(breve,)|(uml[,;])|([sScCZz]caron[,;])"
test.amp2 <- metadata %>% 
  filter(!str_detect(authors, amp2pattern)) %>%
  pull(cord_uid) %>%
  unique()

message(sprintf("Dropping %d papers with pattern \"(amp,;)|(Iacute,;)|(Uuml,;)|(acute[,;])|(breve,)|(uml[,;])\" in 'authors", test.amp2 %>% length))
metadata <- metadata %>% 
  filter(!str_detect(authors, amp2pattern))

# recalculate All authors
{
  message("Extracting authors")
  tic()
  allAuthors <- extractAllAuthors(metadata)  
  toc()
}

## Fix "Jr.", "Sr.", "2nd"
test.Jr <- allAuthors %>% 
  filter(str_detect(authors, "^Jr\\.,")) %>% 
  pull(cord_uid) %>%
  unique

test.Sr <- allAuthors %>% 
  filter(str_detect(authors, "^Sr\\.,")) %>% 
  pull(cord_uid) %>%
  unique

test.2nd <- allAuthors %>% 
  filter(str_detect(authors, "^2nd,")) %>% 
  pull(cord_uid) %>%
  unique

test.3rd <- allAuthors %>% 
  filter(str_detect(authors, "^3rd,")) %>% 
  pull(cord_uid) %>%
  unique

test.III <- allAuthors %>% 
  filter(str_detect(authors, "^III,")) %>% 
  pull(cord_uid) %>%
  unique

message(sprintf("Fixing 'authors' strings on %d/%d/%d/%d/%d papers in regard to 'Jr./Sr./2nd/3rd/III' wrong parsing", 
                test.Jr %>% length(),
                test.Sr %>% length(),
                test.2nd %>% length(),
                test.3rd %>% length(),
                test.III %>% length()
                ))
# METADATA: fix Jr., when separated into separate "author"
metadata <- metadata %>% 
  mutate(
    authors_2 = authors,
    authors = ifelse(cord_uid %in% test.Jr,
                     str_replace_all(authors, ";( Jr\\.)", "\\1"),
                     authors
    )
  ) %>%
  mutate(
    authors = ifelse(cord_uid %in% test.Sr,
                     str_replace_all(authors, ";( Sr\\.)", "\\1"),
                     authors
    )
  ) %>%
  mutate(
    authors = ifelse(cord_uid %in% test.2nd,
                     str_replace_all(authors, ";( 2nd)", "\\1"),
                     authors
    )
  ) %>%
  mutate(
    authors = ifelse(cord_uid %in% test.3rd,
                     str_replace_all(authors, ";( 3rd)", "\\1"),
                     authors
    )
  ) %>%
  mutate(
    authors = ifelse(cord_uid %in% test.III,
                     str_replace_all(authors, ";( III)", "\\1"),
                     authors
    )
  )
  

# recalculate All authors
{
  tic()
  allAuthors <- extractAllAuthors(metadata)  
  toc()
}

jrPattern <- "^(.*)[\\, ]Jr\\.?\\,(.*)\\,?$"
srPattern <- "^(.*)[\\, ]Sr\\.?\\,(.*)\\,?$"
p2ndPattern <- "^(.*)[\\, ]2nd\\.?\\,(.*)\\,?$"
p3rdPattern <- "^(.*)[\\, ]3nd\\.?\\,(.*)\\,?$"
pIIIPattern <- "^(.*)[\\, ]III\\.?\\,(.*)\\,?$"
test.authors.jr.sr.2nd <- allAuthors %>% 
  filter(str_detect(authors, jrPattern) | 
           str_detect(authors, srPattern) | 
           str_detect(authors, p2ndPattern) |
           str_detect(authors, p3rdPattern) |
           str_detect(authors, pIIIPattern)
         ) %>%
  pull(author_row)

authors.fix.Jr.Sr.2nd <- function(allAuthors) {
  allAuthors %>%  
    mutate(
      authors_3=authors,
      # authors=ifelse(
      #   author_row %in% test.authors.jr.sr.2nd,
      #   str_replace(authors, "^(.*)\\,$", "\\1") %>%
      #     str_replace(jrPattern, "\\1, \\2 Jr.") %>% 
      #     str_replace(srPattern, "\\1, \\2 Sr.") %>% 
      #     str_replace(p2ndPattern, "\\1, \\2 2nd") %>% 
      #     str_replace(p3rdPattern, "\\1, \\2 3nd") %>% 
      #     str_replace(pIIIPattern, "\\1, \\2 III") %>% 
      #     str_replace("\\,\\,?  ?", ", "),
      #   authors
      # )
    ) %>% (function(data) {
          tmpAuthors <- data$authors[data$author_row %in% test.authors.jr.sr.2nd]
          data$authors[data$author_row %in% test.authors.jr.sr.2nd] <- str_replace(tmpAuthors, "^(.*)\\,$", "\\1") %>%
                str_replace(jrPattern, "\\1, \\2 Jr.") %>%
                str_replace(srPattern, "\\1, \\2 Sr.") %>%
                str_replace(p2ndPattern, "\\1, \\2 2nd") %>%
                str_replace(p3rdPattern, "\\1, \\2 3nd") %>%
                str_replace(pIIIPattern, "\\1, \\2 III") %>%
                str_replace("\\,\\,?  ?", ", ");
          data
    }) 
}

message(sprintf("Fixing 'Jr./Sr./2nd/3rd/III' string on %d authors", test.authors.jr.sr.2nd %>% length()))

{
  tic()
  allAuthors <- allAuthors %>% 
    authors.fix.Jr.Sr.2nd()
  toc()
}

etPatternMetadata <- "; ?et,"
test.et <- metadata %>%
  filter(str_detect(authors, etPatternMetadata)) %>%
  pull(cord_uid) %>%
  unique()
  
etPattern <- "^ ?et,?$"
alPattern <- "^ ?al\\.?,?$" 
alEtPattern <- "^ ?al[\\.\\, ]*et,?$"
alEtOrPattern <- sprintf("(%s)|(%s)|(%s)", etPattern, alPattern, alEtPattern)
test.etAl <- allAuthors %>% 
  filter(str_detect(authors, alEtOrPattern)) %>% 
  pull(cord_uid) %>%
  unique()

authors.fix.etAl <- function(allAuthors) {
  allAuthors %>%
    filter(!str_detect(authors, alEtOrPattern))
}

message(sprintf("Fixing 'et.al' patterns on %d authors", test.etAl %>% length()))
allAuthors <- allAuthors %>%
  authors.fix.etAl()

## Removing author entries of form "quot,;"
authors.fix.quot <- function(allAuthors) {
  allAuthors %>% 
    filter(!str_detect(authors, "quot,$"))
}

allAuthors <- allAuthors %>%
  authors.fix.quot()

####### 
# Single letter authors

singleLetterPattern <- "^[:upper:]\\.[ ,]*$"
test.single.letter <- allAuthors %>%
  filter(str_detect(authors, singleLetterPattern)) %>%
  pull(cord_uid) %>%
  unique()

authors.fix.remove.single.letter <- function(allAuthors) {
  allAuthors %>% 
    filter(!str_detect(authors, singleLetterPattern))
}

# metadata %>% articleView(test.single.letter )

message(sprintf("Removing %d single letter authors.", 
        allAuthors %>%
          filter(str_detect(authors, singleLetterPattern)) %>% nrow
))
allAuthors <- allAuthors %>%
  authors.fix.remove.single.letter()


########################
## Comma at the end
## Current fix - remove comma

authors.fix.comma <- function(allAuthors) {
  commaPattern <- "^(.*)\\,$"
  inds <- str_which(allAuthors$authors, commaPattern)
  tmp <- allAuthors$authors[inds]
  allAuthors$authors[inds] <- str_replace(tmp, ",$", "")
  allAuthors
}

commaPattern <- "^(.*)\\,$"
# Other comma names
# allAuthors %>%
#   filter(str_detect(authors, commaPattern)) %>%
#   pull(authors) %>%
#   sortedFreqs() %>%
#   View

test.comma.pattern <- allAuthors %>%
  filter(str_detect(authors, commaPattern))

allAuthors <- allAuthors %>%
  authors.fix.comma() 

allAuthors %>% View

########################
## Authors starting with capital letter

# abbrevNameStartPattern <- "^[:upper:]\\..*"
# 
# allAuthors %>% 
#   filter(str_detect(authors, abbrevNameStartPattern)) %>% 
#   authorTitleLinksInExcel("tmp_data/abbrDotStart.xlsx") 


########################
# Find all non-asci characters
# https://stackoverflow.com/questions/53141997/what-is-this-crazy-german-character-combination-to-represent-an-umlaut
# https://stackoverflow.com/questions/33561962/umlaut-matching-in-r-regex
# https://withblue.ink/2019/03/11/why-you-need-to-normalize-unicode-strings.html
allAuthors %>% 
  filter(row_id == 20881) %>% 
  pull(authors) %>% 
  .[[1]] %>% 
  stri_trans_nfc() %>% View
  str_remove_all("[a-zA-Z \\.,\\-]")
  utf8ToInt()



nonASCII <- allAuthors %>% 
  mutate(
    nonASCIIChars = stri_trans_nfc(authors) %>% str_remove_all("[a-zA-Z \\.,\\-]")
  ) %>%
  filter(
    str_length(nonASCIIChars) != 0
  ) %>%
  arrange(nonASCIIChars)
  
nonASCII %>% select(authors, nonASCIIChars) %>% View
  
nonASCII %>% 
  pull(nonASCIIChars) %>%
  stri_trans_nfc() %>%
  unique %>%
  paste0(collapse = "") %>% 
  strsplit("") %>%
  .[[1]] %>% 
  (function(names){
    tibble(letter=names)
  }) %>% View
  
nonASCII[nonASCII %>% order()] %>% View

########################
## Extract first full 2-letter word as surname
str_remove_all("a", "a")

  
# TODO:
#   - al., - Verify
#   - 2nd, - Verify
#   - Sr., - Verify
#   - 3rd, III
#   - M.
#   - Inc
#   - amp, quot, Iacute, Uuml - Verify
#   - vejice
#   - Arxiv obrat

# testPattern <-"[sScCZz]caron[,;]"
# metadata %>%
#   filter(str_detect(authors, testPattern)) %>%
#   # head(100) %>%
#   select(cord_uid, authors, title, source_x) %>%
#    View
#   length()


