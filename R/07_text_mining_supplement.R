# ------------------------------------------------------------------------------
# 07_text_mining_supplement.R
# Syllabus: Unit IV (Text mining with R: tidy text format, unnest_tokens);
#           Unit V (Analyzing word and document frequency: tf-idf, Zipf's law,
#           bind_tf_idf).
# The only free-text field in the dataset is the electricity provider name. This
# supplementary module applies the tidy text workflow to that field to profile
# provider vocabulary across demand segments. The dataset has no review or comment
# text, so sentiment analysis (Unit V) is not applicable and is deliberately omitted.
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages(library(tidytext))

df <- read_csv(CONFIG$processed_path, show_col_types = FALSE)
stop_extra <- tibble(word = c("ltd", "pvt", "co", "corp", "limited", "company", "india"))

tokens <- df |>
  mutate(Segment = ifelse(PeakDemand == 1, "Peak demand", "Non-peak demand")) |>
  select(Segment, Company) |>
  unnest_tokens(word, Company) |>
  anti_join(stop_words, by = "word") |>
  anti_join(stop_extra, by = "word") |>
  filter(!grepl("^[0-9]+$", word))

word_counts <- tokens |> count(Segment, word, sort = TRUE)
tfidf <- word_counts |> bind_tf_idf(word, Segment, n) |> arrange(desc(tf_idf))
save_table(tfidf, "provider_term_tfidf")

top_terms <- word_counts |> group_by(Segment) |> slice_max(n, n = 10, with_ties = FALSE) |> ungroup()
p_terms <- ggplot(top_terms, aes(reorder_within(word, n, Segment), n, fill = Segment)) +
  geom_col(show.legend = FALSE, width = 0.7) +
  scale_x_reordered() + coord_flip() + facet_wrap(~ Segment, scales = "free_y") +
  scale_fill_manual(values = c("Peak demand" = unname(PALETTE["accent"]), "Non-peak demand" = unname(PALETTE["primary"]))) +
  scale_y_continuous(labels = comma) +
  labs(title = "Most Frequent Terms in Provider Names by Demand Segment",
       x = NULL, y = "Term frequency") + theme_report()
save_plot(p_terms, "24_provider_terms", width = 9, height = 5)

# Zipf's law: rank versus frequency on logarithmic axes
zipf <- tokens |> count(word, sort = TRUE) |> mutate(rank = row_number(), freq = n / sum(n))
p_zipf <- ggplot(zipf, aes(rank, freq)) +
  geom_line(colour = PALETTE["primary"]) + geom_point(colour = PALETTE["primary"]) +
  scale_x_log10() + scale_y_log10() +
  labs(title = "Rank-Frequency Distribution of Provider Name Terms",
       subtitle = "Zipf-style plot on logarithmic axes", x = "Rank", y = "Relative frequency") + theme_report()
save_plot(p_zipf, "25_zipf_provider_terms")
print(head(tfidf, 8))
