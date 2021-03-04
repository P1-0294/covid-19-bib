packages <- c(
  "readr", 
  "dplyr", 
  "tidyr", 
  "tictoc", 
  "stringr", 
  "openxlsx", 
  "rvest", 
  "purrr", 
  "data.table"
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

# Download the last version of metadata

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

## Import all data
# {
#   tic()
#   if(LOAD) {
#     metadata0 <- read_csv(METADATA, col_types = cols(
#       .default = col_character()
#     ))
#   }
#   metadata <- metadata0
#   toc() # it takes 7-15s
# }

# data.table approach (much faster group by-s)
{
  tic()
  if(LOAD) {
    metadata <- fread(METADATA, colClasses = c("character"))
  }
  toc()   # much faster, takes < 8s
}

# metadata %>% View

########################################################################
## METADATA: Enumerate lines
########################################################################

## METADATA: `Add row_id`
if(! ("row_id" %in% names(metadata))) {
  metadata <- metadata %>% mutate(row_id = row_number())
}

source("transformations.r")

# replaceAmp <- partial(replacePattern, rules=ampMapping)

# First 100 lines, for inspection
# metadata %>%
#   head(n=100) %>%
#   View


####################################################################
## Duplicated IDs
## There are cases with several lines with duplicate `cord_uid`
####################################################################

# Number of all entries
allCount <- metadata %>% nrow

# Number of duplicate ids
duplicatedLog <- metadata %>% pull(cord_uid) %>% duplicated()
numDuplicates <- sum(duplicatedLog)

# Share of duplicate ids (about 4%)
cat(sprintf("Share of duplicated `cord_uid` lines: %d/%d lines (%.2f%%)", numDuplicates, allCount, numDuplicates/allCount * 100))

# All lines are distinct! So we have papers with changes
metadataDistinct <- metadata %>% distinct()
distinctLinesCount <- metadataDistinct %>% nrow

cat(sprintf("Share of distinct lines: %d/%d lines (%.2f%%)", distinctLinesCount, allCount, distinctLinesCount/allCount * 100))

# Size of cord_uid groups

# cordUidAppearanceCount <- 
#   metadata[, 
#            .(cord_uid_cnt=.N), by=cord_uid][
#              order(-cord_uid_cnt)
#            ]

cordUidAppearanceCount <- metadata %>%
  .[, .(cord_uid_cnt=.N), by=cord_uid] %>%
  .[order(-cord_uid_cnt)]

# METADATA: Add column `cord_uid_cnt` (number of apperances of cord_uid)
if(! ("cord_uid_cnt" %in% names(metadata))) {
  # dtplyr joins seems to be quite fast. 
  # For further optimizations see: https://gist.github.com/kar9222/c2bf12eb9b4142dd97c5e151b8977bc1
  metadata <- metadata %>% 
    left_join(cordUidAppearanceCount, by="cord_uid")
}


# metadata %>% View

  
# Frequencies of `cord_uid_cnt`
cordUidFreq <- cordUidAppearanceCount %>% 
  pull(cord_uid_cnt) %>% 
  table() %>%
  as.data.frame() %>%
  rename(cnt=1) %>%
  mutate(
    cnt = cnt %>% as.character() %>% as.integer()
  ) %>%
  arrange(desc(cnt))

# cordUidFreq %>% View

manyCordId <- cordUidAppearanceCount %>% filter(cord_uid_cnt > 6)

# manyCordId %>% View
# metadata %>% inner_join(manyCordId) %>% arrange(desc(cnt), cord_uid) %>% View

# How many such with several cord_uid and different `authors` string?


differentAuthorsStringCnt <- metadata %>%
  . [,.(author_diff_cnt=length(unique(authors))), by=.(cord_uid, cord_uid_cnt)] %>%
  . [order(-author_diff_cnt, -cord_uid_cnt )]

# differentAuthorsStringCnt %>% View

## METADATA: Add column 'author_diff_cnt` (how many different `authors` strings at the same `cord_uid`)
if(! ("author_diff_cnt" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(differentAuthorsStringCnt %>% select(cord_uid, author_diff_cnt), by="cord_uid")
}

# Inspect different author strings for groups with 2 cord_uid entries 
# metadata %>%
#   select(cord_uid, cord_uid_cnt, authors, author_diff_cnt) %>%
#   arrange(cord_uid) %>%
#   filter(author_diff_cnt == 2) %>% View

## Case inspection
# WRONG SEPARATION: Russo, Giuliano; Levi, Maria Luiza; S ... -> Russo, Giuliano Levi Maria Luiza S (0msu415f)
# NAMING CONVENTION: Moise, L.  -> Moise, Leonard;   (0kuenvdu)
# NON-ASCII CHARACTERS: Ochal, Michal;   -> Ochal, Michał  (0rcuxj1v)
# CHINESE NAME DASH: Luan, R. S.; -> Luan, Rong-Sheng; (0ne3icwz) - CAREFUL: dashed surnames Gregorio-Chaviano, Orlando;
# DOT: Navarro, Ronald A; -> Navarro, Ronald A.; (0ta31nyc), Maltezou, H C -> Maltezou, H. C.
# E-CHAOS: Moreira e Lima -> Lima, Rodrigo Moreira e
# DE-CHAOS: de Lara, Felipe Souza Thyrso -> Lara, Felipe Thyrso de Souza (0tkzjt1y)
# DE-CHAOS-2: Janot de Matos, Gustavo Faissol -> Matos, Gustavo Faissol Janot de (0vp7xx7q)
# DE-CHAOS-3: Gallardo Garrido, Alejandra del Pilar -> Garrido, Alejandra Del Pilar Gallardo
# NA-PARTIAL - some of authors entries are given, some are NA (0tmn3z4w)
# COMPL-DIFF - completely different authors (0v2labnn)
# ANONYMOUS - existence of literal "Anonymous,"

# Inspect cord_uid-s with more than 2 different `authors` strings
moreThen2AuthorStrings <- metadata %>% 
  filter(author_diff_cnt > 2) %>% 
  arrange(desc(author_diff_cnt), cord_uid)

cat(sprintf("%d cases for %d `cord_uid`s with more than 2 different `authors` strings", 
            moreThen2AuthorStrings %>% nrow, 
            moreThen2AuthorStrings %>% pull(cord_uid) %>% unique() %>% length()))

parity.tab <- moreThen2AuthorStrings %>% 
  select(cord_uid) %>% 
  distinct() %>%
  mutate(parity = row_number() %% 2)

moreThen2AuthorStrings %>%
  left_join(parity.tab, by="cord_uid") %>%
  write.xlsx(file.path(TMP_DATA_FOLDER, "moreThan2.xlsx"))

# Dirty trick in Excel (using parity column, formula: =AND(LEN($A2)>0; MOD($Y2; 2)=0)  )
# https://www.extendoffice.com/documents/excel/2661-excel-alternate-row-color-based-on-group.html

# Observations
# MIXED: Multiple different papers with same title, too little metadata (no abstract) merged together
# MIXED_1: Several contributions to one paper, same title (Reply), different authors
# MIXED_X: mixed, missing journal
# SCATTER: Data scattered and different (different journal name, naming authors, presence of abstract)
# AMISS: authors missing in some entires
#################
# SUGGESTION: For now omit those

## METADATA
metadata <- metadata %>% filter(author_diff_cnt <= 2)

# metadata %>% nrow

####################################################################
## Too long author names 
####################################################################

## Very long author lists
maxLen <- 200

metadata %>% 
  filter(cord_uid_cnt == 1, str_length(authors) > maxLen, !str_detect(authors, ";")) %>% 
  select(cord_uid, cord_uid_cnt, authors, source_x) %>% 
  nrow %>%
  cat(sprintf("\n%d cases at maxLen = %d: unique `cord_uid` entries where `authors` are not separated by `;` - wrong parsing", ., maxLen))
# All come from source_x = WHO (240)


# All longer than maxLen characters with no separation with `;`

metadata %>% 
  filter(str_length(authors) > maxLen, !str_detect(authors, ";")) %>% 
  select(cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files) %>% 
  # View
  nrow %>%
  cat(sprintf("\n%d cases, where `authors` are not sparated by `;` and longer than %d", ., maxLen))
# All but one come from WHO (262), There is only one from PMC 
# All of them do not have .json parse files !!!

# Lowering "To long author string" for non WHO data
maxLenLow <- 40
toLong40 <- metadata %>% 
  filter(source_x != "WHO", str_length(authors) > maxLenLow, str_length(authors) <= maxLen, !str_detect(authors, ";")) %>% 
  select(row_id, cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files) %>% 
  mutate(auth_len = str_length(authors)) %>% 
  arrange(auth_len)

# toLong40 %>% View

# All cases longer than 40, without `;` and not from WHO
# Only 16 such papers, all unique

toLongAuthors40NotWHO <- metadata %>% 
  filter(source_x != "WHO", str_length(authors) > maxLenLow, !str_detect(authors, ";")) %>% 
  select(row_id, cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files) %>% 
  mutate(auth_len = str_length(authors)) %>% 
  arrange(auth_len)

# toLongAuthors40NotWHO %>% View

# Anomalies (19 papers)
# Medline; WHO - if source_x is "Medline; Who" then the authors seem to be wrongly parsed
# One case of wrongly parsed authors in Arxiv (boydfb5i)
# One case of strange author name with desription (zztp61pj)
# The rest are institution names
# SUGGESTION: For now, drop such papers (mark them as strange_1)

## METADATA: add strange_1 column
if(! ("strange_1" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(toLongAuthors40NotWHO %>% select(row_id) %>% mutate(strange_1 = 1), by="row_id")
}

# Long `authors` lists from WHO
minLengthWHO <- 40
longWHOStrange <- metadata %>% 
  filter(source_x == "WHO", str_length(authors) > minLengthWHO, !str_detect(authors, ";")) %>% 
  select(row_id, cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files, title) %>% 
  mutate(auth_len = str_length(authors)) %>% 
  arrange(auth_len)
  
cat(sprintf("%d cases of WHO papers with `authors` longer than %d and no `;` separator", longWHOStrange %>% nrow, minLengthWHO))
# longWHOStrange %>% View

# Inspect in Excel
longWHOStrange %>% 
  write.xlsx(file.path(TMP_DATA_FOLDER, "/who.xlsx"))

# No parsed .json files
# In general authors are really poorly parsed. Strange format (first with comma, others with spaces: ")
# Many institutions, some parsed improperly
# Some in Chinese or Arabic letters
# By inspecting original web pages, some cases are unparsable (just comma seperated list of names and surnames)
# SUGGESTION: mark them strange_2

# METADATA: add `strange_2` column
if(! ("strange_2" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(longWHOStrange %>% select(row_id) %>% mutate(strange_2 = 1), by="row_id")
}

# WHO paper analysis
# All entries by WHO (126k+)
allWho <- metadata %>% 
  filter(source_x == "WHO") %>% 
  distinctArticleCount()

# All entries by WHO with correctly separated authors by `;` or names shorter than 40(120+)
whoMaxLen <- 40
okWhoShare <- metadata %>% 
  filter(source_x == "WHO", str_detect(authors, ";") | str_length(authors) <= whoMaxLen) %>% 
  select(cord_uid, cord_uid_cnt, authors, source_x, pdf_json_files, pmc_json_files, title) %>% 
  distinctArticleCount()

# "Bad" paper share  (5% WHO articles are wrongly parsed)
cat(sprintf("%d/%d (%.2f%%) of WHO papers seem to have correctly parsed multiple authors", 
            okWhoShare, allWho, okWhoShare/allWho * 100))

strange1Cnt <- metadata %>%
  filter(strange_1 == 1) %>%
  nrow()

strange2Cnt <- metadata %>%
  filter(strange_2 == 1) %>%
  nrow()


cat(sprintf("Dropping %d of 'strange_1' and %d of 'strange_2.", strange1Cnt, strange2Cnt))
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
    onlyOne <- data[N < 2, .(.N)]$N
    sprintf("%d of %d of 'strange_2' (%.1f%%) is single entry", onlyOne, all, onlyOne/all*100)
  }) %>%
  cat

# METADATA: drop `strange_1` and `strange_2`
metadata <- metadata %>% 
  filter(is.na(strange_1) & is.na(strange_2)) %>%
  select(-strange_1, -strange_2)

# metadata %>% nrow()

#############################################################################
### Some other inspections
#############################################################################
# Are there any cases of same cord_uuid and different source_x? YES many
# sameCoordUuidDiffSources <- metadata %>% 
#   select(cord_uid, source_x) %>%
#   group_by(cord_uid) %>%
#   summarise(cnt=n_distinct(source_x)) %>%
#   filter(cnt > 1) %>%
#   arrange(desc(cnt))
# 
# sameCoordUuidDiffSources %>% View
sameCoordUuidDiffSources <- metadata %>%
  .[,.(cnt=length(unique(source_x))), by=cord_uid] %>%
  .[cnt > 1] %>%
  .[order(-cnt)]

# Examples with 3 different sources.
sameCoordUuidDiffSources3 <- sameCoordUuidDiffSources %>% 
  filter(cnt >= 3) %>% 
  pull(cord_uid) %>% 
  unique

# metadata %>% filter(
#   cord_uid %in% sameCoordUuidDiffSources3
# ) %>% arrange(cord_uid) %>% View

# Example
# metadata %>% filter(cord_uid == "v88f9e7m") %>% View

# Example of b8bl5vq5 - 3 different sources 
# metadata %>% filter(cord_uid == "b8bl5vq5") %>% View

# Are there any cases with distinct cord_uid and s2_id? YES
# diffCordUidS2Id <- metadata %>% 
#   select(cord_uid, s2_id) %>%
#   group_by(cord_uid) %>%
#   summarise(cnt=n_distinct(s2_id)) %>% 
#   filter(cnt > 1) %>%
#   arrange(desc(cnt))

diffCordUidS2Id <- metadata %>%
  .[, .(cnt=length(unique(s2_id))), by=cord_uid] %>%
  .[cnt > 1] %>%
  .[order(-cnt)]

diffCordUidS2Id %>% 
  nrow

# metadata %>% 
#   filter(cord_uid %in% (diffCordUidS2Id %>% pull(cord_uid) %>% unique())) %>% 
#   arrange(cord_uid) %>%
#   View

# Observations
# - different journal names: `European journal of epidemiology` vs `Eur J Epidemiol` (028avudf, 0eklamzu)
# - wrongly grouped (02ua1qyj)
# - different who_covidence_id for no apparent reason (06ollvvq)
# - different sources (0zj4gm0b, 0fbmelx0)
# - different author strings (31qsxdbs)

# metadata %>% articleView("02ua1qyj")

# Inspect different `authors` strings
# tmp.all <- metadata %>%
#   filter(cord_uid %in% (diffCordUidS2Id %>% pull(cord_uid) %>% unique())) %>%
#   select(cord_uid, authors, title, source_x) %>%
#   arrange(cord_uid)
# 
# tmp.diff <- tmp.all %>% 
#   group_by(cord_uid) %>%
#   summarise(cnt=n_distinct(authors)) 
# 
# tmp.all %>% 
#   left_join(tmp.diff, by="cord_uid") %>% 
#   filter(cnt > 1) %>%
#   arrange(desc(cnt), cord_uid) %>%
#   View


####################################################################
## Cleaning authors
####################################################################

# PLAN: 
# - break lines to separate authors
# - normalize names
# - join authors in canonical strings and compare

# Extract authors by lines. User sparator ';'  

####################################################################
## Normalizing names
####################################################################

# metadata0 %>% filter(str_detect(authors, "'")) %>% select(authors, url) %>% View

## 039 -> ' check
metadata %>% 
  select(authors, title) %>%
  filter(str_detect(authors, "039")) %>% 
  mutate(
    authors_new=str_replace_all(authors, "039[\\;\\, ][ \\;]? ?", "'")
  ) %>% 
  mutate(
    authors_new=str_replace_all(authors_new, "\\,\\;", ";"),
    x=1
  ) %>% nrow

## METADATA: 039 -> "'" - fixing separation
metadata <- metadata %>% 
  mutate(
    authors_0 = authors,
    authors=str_replace_all(authors, "039[\\;\\, ][ \\;]? ?", "'")
  ) %>%
  mutate(
    authors_1 = authors,
    authors=str_replace_all(authors, "\\;\\,", ",") # 2 cases, it seems to be correct like this
  )


metadata %>% filter(str_detect(authors, "\\,\\;")) %>% nrow # Will be handled/analyzed later, separated later
metadata %>% filter(str_detect(authors, "\\;\\,")) %>% nrow

# separating by `;` and trimming, removing exact duplicates (due to cord_uid groups)

# extractAllAuthors <- function(metadata) {
#   metadata %>% 
#     select(row_id, cord_uid, source_x, authors, title) %>% 
#     # separate_rows(authors, sep=";") %>%  # too slow
#     .[, .(authors =  unlist(strsplit(authors, ";", fixed = TRUE))), 
#       by = .(row_id, cord_uid, source_x, title)] %>%
#     mutate(
#       authors=str_trim(authors)
#     ) %>%
#     distinct() %>%
#     mutate(
#       author_row=row_number()
#     )
# }

{
  tic()
  allAuthors <- extractAllAuthors(metadata)
  toc()
}

allAuthors %>% nrow

######################################################################
## Analysis of the most frequent
######################################################################

allAuthors %>%
  pull(authors) %>%
  sortedFreqs() %>%
  View

######################################################################
## Authors with commas at the end
######################################################################

commaPattern <- "^(.*)\\,$"

commaAuthors <- allAuthors %>% 
  filter(str_detect(authors, commaPattern)) 

commaAuthorsPaperCordUids <- commaAuthors %>% 
  pull(cord_uid) %>% 
  unique()  

cat(sprintf("%d papers (cord_uid) with comma tail error", commaAuthorsPaperCordUids %>% length))

commaAuthors %>%
  pull(cord_uid) %>%
  sortedFreqs() %>%
  View

commaAuthors %>% 
  pull(authors) %>%
  sortedFreqs() %>%
  View

# metadata %>% filter(str_detect(authors, "Boston,;")) %>% View
# metadata %>% filter(str_detect(authors, "Shweta,;")) %>% View
# metadata %>% filter(str_detect(authors, "Carlos,")) %>% View

ampExpression <- "( amp()[,;][,;]? ?[^\\,\\;]+)[\\,\\;]\\;? ?"
metadata %>% filter(str_detect(authors, ampExpression)) %>% 
   pull(authors) %>%
  str_extract_all(ampExpression) %>%
  unlist() %>% 
  sortedFreqs() %>% View
  # (function(x) {for(i in x[[1]]) print(i)})

ampAuthors <- metadata %>% filter(str_detect(authors, ampExpression)) 

ampAuthors %>% 
  write.xlsx(file.path(TMP_DATA_FOLDER, "amp.xlsx"))

# "amp" ones are mostly indeterministically parsable
# SUGGESTION - remove them

if(! ("amp" %in% names(metadata))) {
  metadata <- metadata %>% 
    left_join(ampAuthors %>% select(row_id) %>% mutate(amp = 1), by="row_id")
}
  
# METADATA: drop `amp`
metadata <- metadata %>% 
  filter(is.na(amp)) %>%
  select(-amp)

# recalculate All authors
allAuthors <- extractAllAuthors(metadata)

# Other comma names
allAuthors %>% 
  filter(str_detect(authors, commaPattern)) %>%
  pull(authors) %>%
  sortedFreqs() %>%
  View

etPatternMetadata <- "; ?et,"
metadata %>%
  filter(str_detect(authors, etPatternMetadata)) %>%
  View

etPattern <- "^et,$"
allAuthors %>% 
  filter(!str_detect(authors, etPattern)) %>% View
## Anomalies
# - "Jr.", - replace ";\\s?Jr\\.
# "et", "al."
# - Single letter, eg. "M."

allAuthors %>% filter(str_detect(authors, "^Jr.,")) %>% View
JrCordUids <- allAuthors %>% 
  filter(str_detect(authors, "^Jr.,")) %>% 
  pull(cord_uid) %>%
  unique

# metadata %>% filter(cord_uid %in% JrCordUids) %>%
#   arrange(cord_uid) %>%
#   select(row_id, cord_uid, authors, title, source_x) %>%
#   mutate(
#     authors_2 = authors,
#     authors = ifelse(cord_uid %in% JrCordUids,
#                      str_replace_all(authors, ";( Jr\\.)", "\\1"),
#                      authors
#     )
#   ) %>% View

# METADATA: fix Jr.,
metadata <- metadata %>% 
  mutate(
    authors_2 = authors,
    authors = ifelse(cord_uid %in% JrCordUids,
                     str_replace_all(authors, ";( Jr\\.)", "\\1"),
                     authors
    )
  )


jrPattern <- "^(.*)[\\, ]Jr\\.?\\,(.*)\\,?$"
jrPatternUids <- allAuthors %>% 
  filter(str_detect(authors, jrPattern)) %>%
  pull(cord)

allAuthorsFixJr <- function(allAuthors) {
  allAuthors %>% filter(str_detect(authors, jrPattern)) %>% 
    mutate(
      authors_3=authors,
      authors=str_replace(authors, "^(.*)\\,$", "\\1") %>%
        str_replace(jrPattern, "\\1, \\2 Jr.") %>% 
        str_replace("\\,\\,?  ?", ", ")
    ) 
}

allAuthors %>% View
allAuthors %>% filter(str_detect(authors, jrPattern)) %>% 
  mutate(
    authors_3=authors,
    authors=str_replace(authors, "^(.*)\\,$", "\\1") %>%
      str_replace(jrPattern, "\\1, \\2 Jr.") %>% 
      str_replace("\\,\\,?  ?", ", ")
  ) %>%
  View

# METADATA: fix Jr.,
metadata <- metadata %>% 
  mutate(
    authors_3=authors,
    authors = ifelse(cord_uid %in% JrCordUids,
                     str_replace_all(authors, ";( Jr\\.)", "\\1"),
                     authors
    )
  )

# metadata %>% articleView("55xkpt43")
# Jr., C.M.C. Inácio -> Inacio, C.M.C Jr."

allAuthors %>% filter(str_detect(authors, "^Jr.,")) %>% View

abbrevNamePattern <- "^[:upper:]\\. ?\\,?$"
test.abbrevName <- allAuthors %>% 
  filter(str_detect(authors, abbrevNamePattern)) %>%
  pull(cord_uid) %>%
  unique()

test.abbrevName %>% articleView(metadata, ., T)

metadata %>% filter(str_detect(authors, "acute")) %>% View
## Comma authors containing numbers, but not 19
commaAuthors %>%
  mutate(
    authors_1 = str_replace(authors, commaPattern, "\\1")
  ) %>%
  filter(str_detect(authors_1, "\\d") & !str_detect(authors_1, "19")) %>%
  pull(authors_1) %>%
  sortedFreqs() %>%
  View

authorsCommaWithNumbersPaperIds <- commaAuthors %>%
  mutate(
    authors_1 = str_replace(authors, commaPattern, "\\1")
  ) %>%
  filter(str_detect(authors_1, "\\d") & !str_detect(authors_1, "19")) %>%
  pull(cord_uid) %>% unique

metadata %>%
  filter(cord_uid %in% authorsCommaWithNumbersPaperIds) %>%
  write.xlsx(file.path(TMP_DATA_FOLDER, "comma-numbers.xlsx"))

## 039 appears often - due to apostrof 


## Authors with comma containing 19
commaAuthors %>%
  mutate(
    authors_1 = str_replace(authors, commaPattern, "\\1")
  ) %>%
  filter(str_detect(authors_1, "19")) %>%
  pull(authors_1) %>%
  sortedFreqs() %>%
  View

institutionCommaNames <- commaAuthors %>%
  mutate(
    authors_1 = str_replace(authors, commaPattern, "\\1")
  ) %>%
  filter(str_detect(authors_1, "19")) %>%
  pull(cord_uid) %>% unique
  
metadata %>%
  filter(cord_uid %in% institutionCommaNames) %>%
  write.xlsx(file.path(TMP_DATA_FOLDER, "comma-institutions.xlsx"))

## All such cases with institution names among authors come from MedRxiv

## SUGGESTIONS




# Strange Physics paper "ijxg870i" with 1201 cases

# commaAuthors %>% 
#   filter(cord_uid != "ijxg870i") %>%
#   View

commaAuthorsPapers <- metadata %>% 
  filter(cord_uid %in% commaAuthorsPaperCordUids)

commaAuthorsPapers %>% 
  arrange(cord_uid) %>%
  write.xlsx(file.path(TMP_DATA_FOLDER, "comma_trail.xlsx"))

## ANALYSIS
# If source is ArXiv, remove trailing comma, process the paper later by putting name abreviation to the end
# In many of those papers some of the authors is wrongly parsed, usually at the end, with name being separated to different author.
# Eg -> N.Heuzé-Vourc’h -> Heuzé, Vourc h; N.,
# SUGGESTION:
# - Remove comma for ArXiv papers, 
# - Drop other Authors (these papers will have one author missing - there are less than 70 such papers )

authorsArXivCommaUids <- commaAuthors %>% 
  filter(source_x == "ArXiv") %>% 
  pull(author_row) 

authorsCommaDro



allAuthors0 <- allAuthors %>%
  mutate(
    authors_0 = ifelse(author_row %in% authorsArXivCommaUids,
                       str_replace(authors, commaPattern, "\\3, \\1"),
                       authors
                       )
  )

allAuthors1 <- allAuthors0 %>%
  filter()

# Handling wrong ArXiv order of Surname, Name (abbrev)

# Strange wrongly parsed cases with comma at the end
commaPattern2 <- "^(([:upper:]\\.)+)(.*)\\,$"
c(
  "R.X.Adhikari,",
  "Z.Zaya.ski,"
) %>% str_replace(commaPattern2, "\\3, \\1")

allAuthors0 %>% filter(author_row %in% authorsArXivCommaUids) %>% View
nrow %>% 
  cat(sprintf("%d cases with abbreviated name at begining and trailing comma", .))

# Cases with no comma at the end
nonCommaPattern <- "^(([:upper:]\\.)+)(.*)[^\\,]$"
allAuthors %>% filter(str_detect(authors, nonCommaPattern)) %>% View


# Handling dots in name
allAuthorsDotted <- allAuthors %>% filter(str_detect(authors, "\\.")) 

allAuthorsDotted %>% View

# Dotted abbrev. name replacement
dotPattern <- "([ \\.][:upper:])\\.\\s*"
dotReplacement <- "\\1 "
dotReplace <- function(column) str_replace_all(column, dotPattern, dotReplacement) %>% str_trim()
c(
  "Surname, Name M.",
  "Surname, M. Name",
  "Surname, J.M.",
  " M.") %>% dotReplace() %>% dotReplace()

namePattern <- "(\\,.*)([:upper:])[:lower:]+(.*)" 
nameReplace <- function(column) { str_replace_all(column, namePattern, "\\1\\2\\3") }
c(
  "Surname, M Name N Secondname"
) %>% nameReplace() %>% nameReplace()

authorsReplaced2 <- allAuthors %>%
  mutate(
    authors_0 = ifelse(source_x == 'ArXiV', 
                       str_replace(authors, commaPattern, "\\3, \\1"),
                       authors)
  ) %>%
  mutate(
    authors_1 = dotReplace(authors_0),
  ) %>%
  mutate(
    authors_1 = dotReplace(authors_1),
  ) %>%
  mutate(
    authors_2 = nameReplace(authors_1),
  ) %>%
  mutate(
    authors_2 = nameReplace(authors_2),
  )
  
# allAuthorsDotted %>% 
#   mutate(
#     authors_no_dot=dotReplace(authors)
#   ) %>% View


authorsReplaced2 %>% 
  arrange(authors_2) %>%
  head(1000) %>%
  View 

authorsReplaced2 %>%
  filter(authors_2 %>% str_detect("^[:upper:]\\.")) %>%
  arrange(authors_2) %>%
  View
# Parsing authors failed from some point
authorsReplaced2 %>% filter(row_id==347749) %>% View

metadata %>% filter(cord_uid=="m0jei9av") %>% pull(authors)
metadata %>% filter(cord_uid=="ijxg870i") %>% pull(authors)

metadata %>% filter(source_x == 'ArXiv') %>% View



################# authors with 'van' in surname ####################
####################################################################

## Authors with 'van' in their surname
vanAuthors <- allAuthors %>% filter(str_detect(authors, "(^van)|( van$)|( van )")) %>% mutate(c=1)

vanAuthors %>% View

vanAuthors %>% filter(str_detect(authors, " van ")) %>% View
vanAuthors %>% filter(str_detect(authors, "van$")) %>% View

# TODO
####################################################################
####################################################################



####################################################################
##################### Duplicated authors on papers #################
####################################################################

# Do this after normalization!!!

allAuthorsCount <- allAuthors %>% nrow 
uniqueAuthorsCount <- allAuthors %>% distinct() %>% nrow
# Duplicated authors on the same paper
allAuthorsCount - uniqueAuthorsCount 

duplicatedAuthors <- allAuthors %>% filter(duplicated(.))
# Duplicated authors, alternative query
duplicatedAuthors %>% nrow
duplicatedAuthors %>% View

# On how which paper candidates?
duplicatedAuthors %>% 
  group_by(cord_uid) %>% 
  summarise(cnt=n()) %>% 
  arrange(desc(cnt)) %>% View



duplicatedAuthors %>% 
  group_by(cord_uid, source_x, title) %>% 
  summarise(cnt=n()) %>% 
  arrange(desc(cnt)) %>% View

duplicatedAuthorsCordUids <- duplicatedAuthors %>% 
  pull(cord_uid) %>% 
  unique()

metadata %>%
  filter(cord_uid %in% duplicatedAuthorsCordUids) %>%  
  write.xlsx(file.path(TMP_DATA_FOLDER, "duplicated_authors.xlsx"))


# Most duplicates ij3ncdb6
metadata %>% articleView("ij3ncdb6")

# Example of non conference 90ivoiog
# metadata %>% filter(cord_uid == "90ivoiog") %>% pull(authors) 

allAuthors %>% 
  filter(source_x == "WHO") %>% 
  group_by(cord_uid) %>% 
  summarise(cnt=n()) %>% 
  arrange(desc(cnt)) %>%
  
  # Strange paper "pd1g119c"
  allAuthors %>% filter(cord_uid == "pd1g119c") %>% nrow
allAuthors %>% filter(cord_uid == "pd1g119c") %>% filter(duplicated(.)) %>% nrow
allAuthors %>% 
  filter(cord_uid == "pd1g119c") %>% 
  filter(duplicated(.)) %>% 
  arrange(authors) %>% View

metadata %>% filter(cord_uid == "pd1g119c") %>% pull(authors)




