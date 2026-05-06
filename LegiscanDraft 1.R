### Mamie Cincotta code

### Knowledge Mining



#Packages 

library(tidyverse)
library(pdftools)
library(quanteda)
library(quanteda.textstats)
library(quanteda.textplots)
library(quanteda.textmodels)
library(topicmodels)
library(scales)
library(tictoc)
library(tidytext)
library(topicmodels)

setwd("C:\\Users\\mamie\\Documents\\EPPS 6323 Knowledge Mining\\Legiscan")



pathdata <- "C:\\Users\\mamie\\Documents\\EPPS 6323 Knowledge Mining\\Legiscan"

SEED <- 6323
pdf_files <- list.files(pathdata, pattern = "\\.pdf$", full.names = TRUE, 
                        ignore.case = TRUE)
cat("Found", length(pdf_files), "PDF files\n")


read_pdf_safe <- function(filepath) {
  tryCatch({
    pages <- pdftools::pdf_text(filepath)
    text <- paste(pages, collapse = "\n")
    return(text)
  }, error = function(e) {
    warning("Failed to read: ", basename(filepath), " — ", e$message)
    return(NA_character_)
  })
}




PSq <- tibble(
  doc_id = basename(pdf_files),
  text   = suppressMessages(
    suppressWarnings(
      map_chr(pdf_files, read_pdf_safe)
    )
  )
)


n_failed <- sum(is.na(PSq$text))
if (n_failed > 0) {
  cat("WARNING:", n_failed, "file(s) failed to read:\n")
  print(PSq$doc_id[is.na(PSq$text)])
  PSq <- filter(PSq, !is.na(text))
}



### Once you have the data, work with it


corpPSq <- corpus(PSq, text_field = "text")





### Track terms in relation to state & partisanship

states <- c(state.name, "District of Columbia")

extractstate <- function(text) {
  for (st in states) {
    pattern <- paste0("\\b", st, "\\b")
    if (str_detect(text, regex(pattern, ignore_case = TRUE))) {
      return(st)
    }
  }
  return(NA_character_)
}



PSq$state <- sapply(PSq$text, extractstate)


corpPSq <- corpus(PSq, text_field = "text")
docvars(corpPSq, "state") <- PSq$state

table(docvars(corpPSq, "state"))

state_info <- data.frame(
  state = c("Alaska","Kansas","Minnesota","Missouri","Nebraska","New Mexico","Ohio","Oklahoma","Utah","Washington"),
  senate_dem = c(0,0,1,0,0,1,0,0,0,1),
  house_dem = c(0,0,0,0,0,1,0,0,0,1),
  split = c(0,0,1,0,0,0,0,0,0,0))

docvars_df <- data.frame(state = docvars(corpPSq, "state"))

docvars_df <- left_join(docvars_df, state_info, by = "state")

docvars(corpPSq, "senate_dem") <- docvars_df$senate_dem
docvars(corpPSq, "house_dem") <- docvars_df$house_dem
docvars(corpPSq, "split") <- docvars_df$split



tokens <- tokens(corpPSq, remove_punct = TRUE, remove_numbers = TRUE) %>%
  tokens_remove(stopwords("english")) %>%
  tokens_remove(c("page", "figure", "table", "appendix", "chapter",
                  "https", "www", "pdf", "gov", "shall"))  # Remove boilerplate




# Create DFM
dfmatPSq <- dfm(tokens)

cat("DFM dimensions:", dim(dfmatPSq), "\n")
cat("Documents:", ndoc(dfmatPSq), "| Features:", nfeat(dfmatPSq), "\n")


topfeat <- topfeatures(dfmatPSq, 30)
data.frame(feature = names(topfeat), freq = topfeat) %>%
  ggplot(aes(x = reorder(feature, freq), y = freq)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(title = "Top 30 Features across ",
       x = NULL, y = "Frequency") +
  theme_bw(base_size = 18) +
  theme(text=element_text(family="Palatino"))


dfmatPSq <- dfm(corpPSq)
dfmatPSq <- dfm_remove(dfmatPSq, pattern = stopwords("en"))

## Trying to do keyness analysis 



keyness <- textstat_keyness(dfmatPSq, target = docvars(dfmatPSq, "senate_dem") == 1)
keyness <- keyness %>% filter(nchar(feature) > 3)
head(keyness)


top_key <- keyness %>%
  mutate(direction = ifelse(n_target > n_reference, "Dem", "Non-Dem"),
         signed_chi2 = ifelse(direction == "Dem", chi2, -chi2)) %>%
  slice_max(order_by = abs(signed_chi2), n = 20)

ggplot(top_key, aes(x = reorder(feature, signed_chi2), y = signed_chi2, fill = direction)) +
  geom_col() +
  coord_flip() +
  labs(title = "Key Terms by Senate Control",
       x = NULL,
       y = "Signed Chi-squared") +
  scale_fill_manual(values = c("Dem" = "blue", "Non-Dem" = "red")) +
  theme_bw(base_size = 16)



# repeat with house

keynessh <- textstat_keyness(dfmatPSq, target = docvars(dfmatPSq, "house_dem") == 1)
keynessh <- keynessh %>% filter(nchar(feature) > 3)
head(keynessh)


top_keyh <- keynessh %>%
  mutate(direction = ifelse(n_target > n_reference, "Dem", "Non-Dem"),
         signed_chi2 = ifelse(direction == "Dem", chi2, -chi2)) %>%
  slice_max(order_by = abs(signed_chi2), n = 20)

ggplot(top_keyh, aes(x = reorder(feature, signed_chi2), y = signed_chi2, fill = direction)) +
  geom_col() +
  coord_flip() +
  labs(title = "Key Terms by House Control",
       x = NULL,
       y = "Signed Chi-squared") +
  scale_fill_manual(values = c("Dem" = "blue", "Non-Dem" = "red")) +
  theme_bw(base_size = 16)

## Bigram analysis

tokensPSq <- tokens(corpPSq,
                    remove_punct = TRUE,
                    remove_numbers = TRUE) %>%
  tokens_remove(stopwords("english")) %>%
  tokens_remove(c("page", "figure", "table", "appendix", "chapter",
                  "https", "www", "pdf", "gov", "shall")) %>%
  tokens_ngrams(n = 2)


dfmatPSqbi <- dfm(tokensPSq)

keynessbi <- textstat_keyness(
  dfmatPSqbi,
  target = docvars(dfmatPSqbi, "senate_dem") == 1
)

top_keybi <- keynessbi %>%
  mutate(direction = ifelse(n_target > n_reference, "Dem", "Non-Dem"),
         signed_chi2 = ifelse(direction == "Dem", chi2, -chi2)) %>%
  slice_max(order_by = abs(signed_chi2), n = 20)

ggplot(top_keybi, aes(x = reorder(feature, signed_chi2), y = signed_chi2, fill = direction)) +
  geom_col() +
  coord_flip() +
  labs(title = "Key Terms by Senate Control",
       x = NULL,
       y = "Signed Chi-squared") +
  scale_fill_manual(values = c("Dem" = "blue", "Non-Dem" = "red")) +
  theme_bw(base_size = 16)

## bigrams by house
keynessbih <- textstat_keyness(
  dfmatPSqbi,
  target = docvars(dfmatPSqbi, "house_dem") == 1
)

top_keybih <- keynessbih %>%
  mutate(direction = ifelse(n_target > n_reference, "Dem", "Non-Dem"),
         signed_chi2 = ifelse(direction == "Dem", chi2, -chi2)) %>%
  slice_max(order_by = abs(signed_chi2), n = 20)

ggplot(top_keybih, aes(x = reorder(feature, signed_chi2), y = signed_chi2, fill = direction)) +
  geom_col() +
  coord_flip() +
  labs(title = "Key Terms by Senate Control",
       x = NULL,
       y = "Signed Chi-squared") +
  scale_fill_manual(values = c("Dem" = "blue", "Non-Dem" = "red")) +
  theme_bw(base_size = 16)



### Trying to do dictionary analysis

policy_dict <- dictionary(list(
  voter_id = c("voter id", "identification", "photo id", "id require", "proof identity"),
  registration = c("registration", "register", "same day registration", "automatic registration", "voter roll"),
  absentee_mail = c("absentee", "mail ballot", "vote by mail", "mail-in", "postal voting"),
  administration = c("poll worker", "polling place", "election administration", "ballot processing", "tabulation"),
  emergency = c("emergency", "disaster", "pandemic", "covid", "natural disaster", "contingency")
))

dfmpolicy <- dfm_lookup(dfmatPSq, dictionary = policy_dict)

colSums(dfmpolicy)



dfmpolicystate <- convert(dfmpolicy, to = "data.frame")
dfmpolicystate$state <- docvars(corpPSq, "state")
 





dfmpolicystate %>%
  group_by(state) %>%
  summarise(across(voter_id:emergency, sum)) %>%
  pivot_longer(-state, names_to = "policy", values_to = "count") %>%
  ggplot(aes(x = state, y = count, fill = policy)) +
  geom_col(position = "stack") +
  coord_flip() + 
  labs(
    title = "Policy Type Across States",
    x = "State",
    y = "Count"
  ) 





dfmpolicydf <- convert(dfmpolicy, to = "data.frame")

policy_cols <- c("voter_id","registration","absentee_mail","administration","emergency")

dfmpolicydf$mainpolicy <- policy_cols[
  max.col(dfmpolicydf[, policy_cols], ties.method = "first")
]


dfmpolicydf$state <- docvars(corpPSq, "state")

counts <- dfmpolicydf %>%
  filter(!is.na(state)) %>%
  group_by(state, mainpolicy) %>%
  summarise(n = n(), .groups = "drop")

ggplot(counts, aes(x = state, y = n, fill = mainpolicy)) +
  geom_col() +
  coord_flip() +
  labs(title = "Dominant Policy Across States",
       x = "State",
       y = "Number of Documents",
       fill = "Policy Area") +
  theme_bw()


## Find dominant policy across partisanships

senate_summary <- dfm_group(dfmpolicy, groups = docvars(dfmpolicy, "senate_dem")) %>%
  convert(to = "data.frame") %>%
  mutate(group = rownames(.))


senate_long <- senate_summary %>%
  select(-doc_id) %>%
  pivot_longer(-group, names_to = "policy", values_to = "count")


ggplot(senate_long, aes(x = group, y = count, fill = policy)) +
  geom_col() +
  labs(x = "Senate Democratic Control (1 = No, 2 = Yes)",
       y = "Count",
       title = "Policy Language by Senate Composition")

### Trying to do topic modelling




dfmat_trim <- dfmatPSq %>%
  dfm_trim(min_termfreq = 5, min_docfreq = 3) %>% 
  dfm_weight(scheme = "count") 


dtm <- convert(dfmat_trim, to = "topicmodels")

k <- 3 #Because only 3 of the dictonary categories ended up being relevant

lda_model <- LDA(dtm, k = k, control = list(seed = SEED))

terms(lda_model, 10)


topic_probs <- posterior(lda_model)$topics

topic_df <- as.data.frame(topic_probs)
topic_df$doc_id <- docnames(dfmat_trim)
topic_df$state <- docvars(corpPSq, "state")


topic_df$dominant_topic <- apply(topic_df[, 1:k], 1, which.max)




topic_counts <- topic_df %>%
  filter(!is.na(state)) %>%
  group_by(state, dominant_topic) %>%
  summarise(n = n(), .groups = "drop")

ggplot(topic_counts, aes(x = state, y = n, fill = factor(dominant_topic))) +
  geom_col() +
  coord_flip() +
  labs(fill = "Topic",
       title = "Dominant LDA Topics by State")



topic_props <- topic_df %>%
  filter(!is.na(state)) %>%
  group_by(state) %>%
  summarise(across(1:k, mean)) %>%
  pivot_longer(-state, names_to = "topic", values_to = "prop")

ggplot(topic_props, aes(x = state, y = prop, fill = topic)) +
  geom_col() +
  coord_flip()



