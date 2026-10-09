# ------------------------------------------------------------------------------
# 03_unsupervised_learning.R
# Syllabus: Unit III (Unsupervised methods: cluster analysis, association rules).
# ------------------------------------------------------------------------------
source("R/00_config.R")
suppressPackageStartupMessages(library(cluster))
set.seed(CONFIG$seed)

df <- read_csv(CONFIG$processed_path, show_col_types = FALSE)
X  <- df |> select(all_of(CONFIG$appliance_vars)) |> scale()

# ---- Choosing k: within-cluster sum of squares and silhouette width ----------
ks  <- 2:8
sub <- sample(nrow(X), 4000)
d_sub <- dist(X[sub, ])
sel <- tibble(k = ks) |>
  rowwise() |>
  mutate(WSS = kmeans(X, centers = k, nstart = 10, iter.max = 100)$tot.withinss,
         Silhouette = mean(silhouette(kmeans(X[sub, ], centers = k, nstart = 10, iter.max = 100)$cluster, d_sub)[, 3])) |>
  ungroup()
save_table(sel, "kmeans_selection")

p_sel <- sel |> pivot_longer(c(WSS, Silhouette), names_to = "Criterion", values_to = "Value") |>
  ggplot(aes(k, Value)) +
  geom_line(colour = PALETTE["primary"]) + geom_point(colour = PALETTE["primary"], size = 2) +
  facet_wrap(~ Criterion, scales = "free_y") +
  scale_x_continuous(breaks = ks) +
  labs(title = "Selecting the Number of Household Segments",
       subtitle = "Elbow criterion (WSS) and mean silhouette width", x = "Number of clusters (k)", y = NULL) +
  theme_report()
save_plot(p_sel, "09_kmeans_selection", width = 9, height = 4)

K <- sel$k[which.max(sel$Silhouette)]
cat("Selected k =", K, "(maximum silhouette width)\n")
km <- kmeans(X, centers = K, nstart = 25, iter.max = 100)
df$Cluster <- factor(km$cluster)

# ---- Cluster profiles --------------------------------------------------------
profile <- df |> group_by(Cluster) |>
  summarise(Households = n(),
            across(all_of(CONFIG$appliance_vars), mean),
            MeanHours = mean(MonthlyHours), PeakShare = mean(PeakDemand), .groups = "drop") |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))
save_table(profile, "cluster_profiles")
print(profile)

# ---- Principal component projection of clusters -------------------------------
pc <- prcomp(X)
pcs <- as_tibble(pc$x[, 1:2]) |> mutate(Cluster = df$Cluster)
var_exp <- round(100 * summary(pc)$importance[2, 1:2], 1)
p_pc <- ggplot(slice_sample(pcs, n = 6000), aes(PC1, PC2, colour = Cluster)) +
  geom_point(alpha = 0.5, size = 1) +
  labs(title = "Household Segments in Principal Component Space",
       x = paste0("PC1 (", var_exp[1], "% of variance)"), y = paste0("PC2 (", var_exp[2], "% of variance)")) +
  theme_report()
save_plot(p_pc, "10_cluster_pca")

p_prof <- profile |>
  select(Cluster, all_of(CONFIG$appliance_vars)) |>
  pivot_longer(-Cluster, names_to = "Appliance", values_to = "Mean") |>
  ggplot(aes(Appliance, Cluster, fill = Mean)) +
  geom_tile(colour = "white") + geom_text(aes(label = round(Mean, 1)), colour = "white", size = 3.5) +
  scale_fill_gradient(low = PALETTE["neutral"], high = PALETTE["primary"], name = "Mean level") +
  labs(title = "Mean Appliance Usage Level by Segment", x = NULL, y = "Segment") + theme_report()
save_plot(p_prof, "11_cluster_profile_heatmap")

# ---- Association rules (Apriori-style, single antecedent) ---------------------
# Appliance usage is discretised into High/Low items using the median; rules of the
# form {appliance level} -> {PeakDemand} are scored by support, confidence and lift.
items <- df |>
  transmute(across(all_of(CONFIG$appliance_vars),
                   ~ ifelse(.x > median(.x), "High", "Low"))) |>
  mutate(across(everything(), as.character))
for (v in CONFIG$appliance_vars) items[[v]] <- paste0(v, "=", items[[v]])
items$Peak <- ifelse(df$PeakDemand == 1, "Peak=Yes", "Peak=No")

n <- nrow(items); base_peak <- mean(df$PeakDemand)
rules <- bind_rows(lapply(CONFIG$appliance_vars, function(v) {
  items |> group_by(Antecedent = .data[[v]]) |>
    summarise(Support = n() / n, Confidence = mean(Peak == "Peak=Yes"), .groups = "drop")
})) |>
  mutate(Consequent = "Peak=Yes", Lift = Confidence / base_peak) |>
  arrange(desc(Lift))

# Two-item antecedents for the strongest combinations
pairs <- combn(CONFIG$appliance_vars, 2, simplify = FALSE)
rules2 <- bind_rows(lapply(pairs, function(p) {
  items |> group_by(a = .data[[p[1]]], b = .data[[p[2]]]) |>
    summarise(Support = n() / n, Confidence = mean(Peak == "Peak=Yes"), .groups = "drop") |>
    mutate(Antecedent = paste(a, "&", b), Consequent = "Peak=Yes", Lift = Confidence / base_peak) |>
    select(Antecedent, Support, Confidence, Consequent, Lift)
})) |>
  filter(Support >= 0.05) |> bind_rows(rules) |> arrange(desc(Lift)) |>
  mutate(across(c(Support, Confidence, Lift), ~ round(.x, 3)))
save_table(rules2, "association_rules")
print(head(rules2, 10))

p_rules <- rules2 |> slice_head(n = 10) |>
  ggplot(aes(reorder(Antecedent, Lift), Lift)) +
  geom_col(fill = PALETTE["primary"], width = 0.7) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = PALETTE["accent"]) +
  geom_text(aes(label = paste0(round(Confidence * 100), "%")), hjust = -0.15, size = 3.2) +
  coord_flip(ylim = c(0, max(rules2$Lift) * 1.15)) +
  labs(title = "Association Rules Leading to Peak Demand",
       subtitle = "Bar length is lift; label is rule confidence; dashed line marks lift of 1",
       x = NULL, y = "Lift") + theme_report()
save_plot(p_rules, "12_association_rules", width = 9, height = 5)

write_csv(df |> select(Cluster), file.path(CONFIG$tab_dir, "cluster_assignments.csv"))
