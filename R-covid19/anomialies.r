require(readr)
require(dplyr)
require(tidyr)
require(tictoc)
require(stringr)
require(tidyr)

# Download metadata.csv from 
# https://ai2-semanticscholar-cord-19.s3-us-west-2.amazonaws.com/historical_releases.html
# Place the file metadata.csv (possibly fix the path)
# metadata.csv size is 0.5GB hence it is not part of the git repositry

PATH_TO_DATA="../../data/2020-12-12"
METADATA=paste0(PATH_TO_DATA, "/", "metadata.csv")

## Import all data
{
  tic()
  metadata <- read_csv(METADATA, col_types = cols(
    .default = col_character()
  ))
  toc() # it takes 7-15s
}

# First 100 lines, for inspection
metadata %>% 
  head(n=100) %>%
  View


##################### Duplicated IDs###$###############################
####################################################################

# Number of all entries
allCount <- metadata %>% nrow
allCount

# Number of duplicate ids
duplicatedLog <- metadata %>% pull(cord_uid) %>% duplicated()
numDuplicates <- sum(duplicatedLog)

# Share of duplicate ids - All ids are duplicated
(dupIds %>% length())/allCount

# All lines are distinct! So we have papers with changes
metadataDistinct <- metadata %>% distinct()
metadataDistinct %>% nrow

# Size of cord_uid groups
freq <- metadata %>%
  select(cord_uid) %>%
  group_by(cord_uid) %>%
  summarise(cnt=n()) %>%
  arrange(desc(cnt)) %>%
  pull(cnt) %>% 
  table() %>%
  as.data.frame() %>%
  rename(cnt=1) %>%
  mutate(
    cnt = cnt %>% as.character() %>% as.integer()
  ) %>%
  arrange(desc(cnt))

freq %>% View

# Are there any cases of same cord_uuid and different source_x? YES many
sameCoordUuidDiffSources <- metadata %>% 
  select(cord_uid, source_x) %>%
  group_by(cord_uid) %>%
  summarise(cnt=n_distinct(source_x)) %>%
  filter(cnt > 1) %>%
  arrange(desc(cnt))

# Examples with 3 different sources.
sameCoordUuidDiffSources3 <- sameCoordUuidDiffSources %>% 
  filter(cnt >= 3) %>% 
  pull(cord_uid) %>% 
  unique

metadata %>% filter(
  cord_uid %in% sameCoordUuidDiffSources3
) %>% arrange(cord_uid) %>% View

# Example
metadata %>% filter(cord_uid == "v88f9e7m") %>% View

# Example of b8bl5vq5 - 3 different sources 
metadata %>% filter(cord_uid == "b8bl5vq5") %>% View

# Are there any cases with distinct cord_uid and s2_id? YES
diffCordUidS2Id <- metadata %>% 
  select(cord_uid, s2_id) %>%
  group_by(cord_uid) %>%
  summarise(cnt=n_distinct(s2_id)) %>% 
  filter(cnt > 1) %>%
  arrange(desc(cnt))

diffCordUidS2Id %>% View

# 50 differences kgpo6psq - this is not a paper, title "Reply"???
metadata %>% filter(cord_uid == "kgpo6psq") %>% View

# TODO ...

################ Cleaning authors ##################################
####################################################################

# Extract authors by lines. User sparator ';'  
allAuthors <-  metadata %>% 
  select(cord_uid, source_x, authors, title) %>% 
  separate_rows(authors, sep=";") %>% 
  mutate(
    authors=str_trim(authors)
  ) 


##################### Duplicated authors on papers #################
####################################################################

allAuthorsCount <- allAuthors %>% nrow 
uniqueAuthorsCount <- allAuthors %>% distinct() %>% nrow
# Duplicated authors on the same paper
allAuthorsCount - uniqueAuthorsCount 

duplicatedAuthors <- allAuthors %>% filter(duplicated(.))
# Duplicated authors, alternative query
duplicatedAuthors %>% nrow

duplicatedAuthors %>% 
  group_by(cord_uid, source_x, title) %>% 
  summarise(cnt=n()) %>% 
  arrange(desc(cnt)) %>% View


# Most duplicates ij3ncdb6
metadata %>% filter(cord_uid == "ij3ncdb6") %>% pull(authors) 

# Example of non conference 90ivoiog
metadata %>% filter(cord_uid == "90ivoiog") %>% pull(authors) 

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

##################### Too long author names ########################
####################################################################

## Very long names
maxLen <- 50
tooLong <- allAuthors %>% filter(str_length(authors) > maxLen) 

tooLong %>% View

table(tooLong$source_x) %>% 
  as.data.frame() %>% 
  arrange(desc(Freq)) %>% View
  
# Some names are journals, conferences
# Some long names lists are wrongly parsed

# TODO ...

##################### Trying to normalize author names##############
####################################################################
## Preview
allAuthors %>% head(100) %>% View

# Handling dots in name
allAuthorsDotted <- allAuthors %>% filter(str_detect(authors, "\\."))

allAuthorsDotted %>% View

# Dotted abbrev. name replacement
dotPattern <- "([:upper:])\\.\\s*"
dotReplacement <- "\\1 "
dotReplace <- function(column) str_replace_all(column, dotPattern, dotReplacement) %>% str_trim()
c(
  "Name, Surname M.",
  "Name, M. Surname",
  "Name, J.M.") %>% dotReplace()

allAuthorsDotted %>% 
  mutate(
    authors_no_dot=dotReplace(authors)
  ) %>% View


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



