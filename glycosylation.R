# ============================================================
#  SGA Glycosylation — Comparison across genotypes × tissues
#  Input : Database_SGA_YL_YR_FLW.xlsx
#  Requires : readxl, tidyverse, ggplot2, patchwork, ggdendro
# ============================================================

library(readxl)
library(tidyverse)
library(ggplot2)
library(patchwork)
library(ggdendro)

# ── 0. Setup ─────────────────────────────────────────────────
setwd("C:/Internship/R/Glycosylation explication")

df <- read_excel("Database_SGA_YL_YR_FLW.xlsx", sheet = 1)

# ── 1. Clean Glycosylation column ────────────────────────────
# Strip whitespace/newlines, replace "?" with NA
df <- df %>%
  mutate(
    Glycosylation = str_trim(Glycosylation),
    Glycosylation = if_else(Glycosylation == "?", NA_character_, Glycosylation),
    n_sugars = if_else(
      is.na(Glycosylation), 0L,
      str_count(Glycosylation, "-") + 1L
    )
  )

# ── 2. Parse peak area columns → genotype + tissue + replicate
peak_cols <- grep("Peak area per g FW", names(df), value = TRUE)
peak_cols <- peak_cols[!grepl("QC", peak_cols)]

# Build metadata table: col → genotype, tissue, replicate
col_meta <- tibble(col = peak_cols) %>%
  mutate(
    # Extract genotype: between GAQ_02_ and the next _digit or _YL/_YR/_FLW
    Genotype = str_extract(col, "(?<=GAQ_02_)[A-Za-z0-9]+(?=_)"),
    # Extract tissue: YL, YR, or FLW
    Tissue   = str_extract(col, "YL|YR|FLW"),
    # Extract replicate number
    Replicate = str_extract(col, "(?<=YL|YR|FLW)\\d+")
  )

# Simplify genotype labels
geno_labels <- c(
  FRA   = "FRA",
  ILE21 = "ILE",
  ITH1  = "ITH",
  MON10 = "MON",
  SIE13 = "SIE",
  UNG1  = "UNG",
  ZAN02 = "ZAN"
)

col_meta <- col_meta %>%
  mutate(Genotype_short = geno_labels[Genotype])

# ── 3. Color palettes ─────────────────────────────────────────
geno_colors <- c(
  FRA = "#FFD700",
  ITH = "#FFA500",
  SIE = "#FF4500",
  ILE = "#1E90FF",
  ZAN = "#00CCCC",
  MON = "#BBBB44",
  UNG = "#32CD32"
)

tissue_colors <- c(
  FLW = "#984EA3",
  YL  = "#4DAF4A",
  YR  = "#E41A1C"
)

sugar_colors <- c(
  Hex  = "#185FA5",
  dHex = "#1D9E75",
  Pent = "#EF9F27",
  GlcA = "#D4537E"
)

degree_colors <- c(
  "0" = "#E6F1FB", "1" = "#B5D4F4", "2" = "#85B7EB",
  "3" = "#378ADD", "4" = "#185FA5"
)

base_theme <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
    axis.text        = element_text(color = "grey30"),
    axis.title       = element_text(color = "grey30", size = 10),
    plot.background  = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    plot.title       = element_text(face = "bold", size = 11)
  )

# ── 4. Build long_df ──────────────────────────────────────────
# One row per compound × sample; join metadata
long_df <- df %>%
  select(all_of(c("Glycosylation", "n_sugars", peak_cols))) %>%
  pivot_longer(cols      = all_of(peak_cols),
               names_to  = "col",
               values_to = "area") %>%
  left_join(col_meta, by = "col") %>%
  filter(area > 0, !is.na(Glycosylation)) %>%
  mutate(
    Genotype = factor(Genotype_short, levels = names(geno_colors)),
    Tissue   = factor(Tissue,         levels = c("YL", "YR", "FLW"))
  )

# ── 5. Top 12 patterns (excluding ace, across all samples) ───
top_patterns <- long_df %>%
  filter(!str_detect(Glycosylation, "ace")) %>%
  group_by(Glycosylation) %>%
  summarise(total = sum(area), .groups = "drop") %>%
  arrange(desc(total)) %>%
  slice_head(n = 12) %>%
  pull(Glycosylation)

# Top 7 for tissue panel (drop the 5 low-abundance patterns)
top_patterns_tissue <- top_patterns[1:7]

# ── 6. Sample totals (for % calculations) ────────────────────
sample_totals <- long_df %>%
  group_by(Genotype, Tissue, col) %>%
  summarise(sample_total = sum(area), .groups = "drop")

# ── 7. Genotype × tissue means (averaging over replicates) ───
geno_tissue_totals <- long_df %>%
  group_by(Genotype, Tissue) %>%
  summarise(geno_tissue_total = sum(area), .groups = "drop")

# ════════════════════════════════════════════════════════════
#  PANEL A — Sugar type composition: genotype × tissue (faceted)
# ════════════════════════════════════════════════════════════
sugar_long <- long_df %>%
  mutate(tokens = str_split(Glycosylation, "-")) %>%
  unnest(tokens) %>%
  mutate(tokens = str_trim(tokens)) %>%
  filter(tokens %in% names(sugar_colors)) %>%
  group_by(Genotype, Tissue, tokens) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  rename(Sugar = tokens) %>%
  mutate(Sugar = factor(Sugar, levels = names(sugar_colors)))

pA <- ggplot(sugar_long, aes(x = Genotype, y = pct, fill = Sugar)) +
  geom_col(width = 0.75, color = "white", linewidth = 0.25) +
  facet_wrap(~ Tissue, nrow = 1,
             labeller = labeller(Tissue = c(YL = "Young leaf",
                                            YR = "Young root",
                                            FLW = "Flower"))) +
  scale_fill_manual(values = sugar_colors, name = "Sugar type") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "A — Sugar type composition per genotype and tissue",
       x = NULL, y = "Relative abundance (%)") +
  base_theme +
  theme(
    axis.text.x     = element_text(angle = 45, hjust = 1, size = 9),
    legend.position = "right",
    strip.text      = element_text(face = "bold", size = 10)
  )

# ════════════════════════════════════════════════════════════
#  PANEL B — Glycosylation degree: genotype × tissue (faceted)
# ════════════════════════════════════════════════════════════
degree_long <- long_df %>%
  filter(n_sugars <= 4) %>%
  group_by(Genotype, Tissue, n_sugars) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  mutate(n_sugars = factor(n_sugars, levels = 0:4))

pB <- ggplot(degree_long, aes(x = Genotype, y = pct, fill = n_sugars)) +
  geom_col(width = 0.75, color = "white", linewidth = 0.25) +
  facet_wrap(~ Tissue, nrow = 1,
             labeller = labeller(Tissue = c(YL = "Young leaf",
                                            YR = "Young root",
                                            FLW = "Flower"))) +
  scale_fill_manual(values = degree_colors,
                    name   = "No. of sugars",
                    labels = c("0 (aglycone)", "1", "2", "3", "4")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "B — Glycosylation degree per genotype and tissue",
       x = NULL, y = "Relative abundance (%)") +
  base_theme +
  theme(
    axis.text.x     = element_text(angle = 45, hjust = 1, size = 9),
    legend.position = "right",
    strip.text      = element_text(face = "bold", size = 10)
  )

# ════════════════════════════════════════════════════════════
#  PANEL C — Heatmap + dendrogram: genotype × pattern
#  Averaged across tissues and replicates
# ════════════════════════════════════════════════════════════
heat_wide <- long_df %>%
  filter(!is.na(Glycosylation), Glycosylation %in% top_patterns) %>%
  group_by(Genotype, Glycosylation) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  left_join(
    long_df %>% group_by(Genotype) %>%
      summarise(total = sum(area), .groups = "drop"),
    by = "Genotype"
  ) %>%
  mutate(pct = total_area / total * 100) %>%
  tidyr::complete(Genotype, Glycosylation, fill = list(pct = 0)) %>%
  pivot_wider(id_cols     = Genotype,
              names_from  = Glycosylation,
              values_from = pct,
              values_fill = 0)

heat_mat <- heat_wide %>% select(-Genotype) %>% as.matrix()
rownames(heat_mat) <- heat_wide$Genotype

dend_geno  <- hclust(dist(heat_mat), method = "ward.D2")
geno_order <- dend_geno$labels[dend_geno$order]
dend_data  <- as.dendrogram(dend_geno)
dend_segs  <- dendro_data(dend_data, type = "rectangle")

pC_dend <- ggplot() +
  geom_segment(data = segment(dend_segs),
               aes(x = x, y = y, xend = xend, yend = yend),
               color = "grey40", linewidth = 0.5) +
  scale_x_continuous(breaks = seq_along(geno_order),
                     labels = geno_order,
                     expand = expansion(add = 0.5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    axis.text.x     = element_text(size = 9, color = "grey30",
                                   face = "bold", margin = margin(t = 2))
  )

heat_df <- heat_wide %>%
  pivot_longer(-Genotype, names_to = "Glycosylation", values_to = "pct") %>%
  mutate(
    Genotype      = factor(Genotype,      levels = geno_order),
    Glycosylation = factor(Glycosylation, levels = rev(top_patterns_tissue))
  )

pC_heat <- ggplot(heat_df, aes(x = Genotype, y = Glycosylation, fill = pct)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = if_else(pct >= 2, round(pct, 1), NA_real_)),
            size = 2.6, color = "white", fontface = "bold") +
  scale_fill_gradient(low  = "#E6F1FB", high = "#0C447C",
                      name = "% abundance",
                      guide = guide_colorbar(barwidth       = 8,
                                             barheight      = 0.6,
                                             title.position = "top",
                                             title.hjust    = 0.5)) +
  labs(y = NULL, x = NULL) +
  base_theme +
  theme(
    axis.text.x     = element_blank(),
    axis.text.y     = element_text(family = "mono", size = 9),
    legend.position = "bottom",
    panel.grid      = element_blank()
  )

pC <- pC_dend / pC_heat +
  plot_layout(heights = c(1, 4)) +
  plot_annotation(
    title = "C — Glycosylation pattern abundance per genotype (all tissues)",
    theme = theme(plot.title = element_text(face = "bold", size = 11))
  )

# ════════════════════════════════════════════════════════════
#  PANEL D — PCA: genotypes by glycosylation profile
#  Colored by tissue group (faceted or combined)
# ════════════════════════════════════════════════════════════
# Build matrix: one row = genotype × tissue combination
pca_wide <- long_df %>%
  filter(!str_detect(Glycosylation, "ace")) %>%
  group_by(Genotype, Tissue, Glycosylation) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  unite("sample_id", Genotype, Tissue, sep = "_") %>%
  pivot_wider(id_cols     = sample_id,
              names_from  = Glycosylation,
              values_from = pct,
              values_fill = 0)

pca_mat <- pca_wide %>% select(-sample_id) %>% as.matrix()
rownames(pca_mat) <- pca_wide$sample_id

pca_res <- prcomp(pca_mat, scale. = TRUE)
pca_df  <- as.data.frame(pca_res$x) %>%
  rownames_to_column("sample_id") %>%
  separate(sample_id, into = c("Genotype", "Tissue"), sep = "_") %>%
  mutate(
    Genotype = factor(Genotype, levels = names(geno_colors)),
    Tissue   = factor(Tissue,   levels = c("YL", "YR", "FLW"))
  )

var_exp <- round(summary(pca_res)$importance[2, 1:2] * 100, 1)

loadings_df <- as.data.frame(pca_res$rotation[, 1:2]) %>%
  rownames_to_column("Pattern") %>%
  mutate(contrib = sqrt(PC1^2 + PC2^2)) %>%
  slice_max(contrib, n = 8) %>%
  mutate(num = row_number())

arrow_scale <- 0.75 * max(abs(c(pca_df$PC1, pca_df$PC2))) /
  max(sqrt(pca_res$rotation[,1]^2 + pca_res$rotation[,2]^2))

loadings_df <- loadings_df %>%
  mutate(PC1s = PC1 * arrow_scale, PC2s = PC2 * arrow_scale)

pD_plot <- ggplot(pca_df,
                  aes(x = PC1, y = PC2,
                      color = Genotype, shape = Tissue,
                      label = Genotype)) +
  geom_hline(yintercept = 0, color = "grey80", linewidth = 0.3) +
  geom_vline(xintercept = 0, color = "grey80", linewidth = 0.3) +
  geom_segment(data = loadings_df,
               aes(x = 0, y = 0, xend = PC1s, yend = PC2s),
               arrow = arrow(length = unit(0.18, "cm"), type = "closed"),
               color = "grey65", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = loadings_df,
            aes(x = PC1s * 1.07, y = PC2s * 1.07, label = num),
            size = 3.2, fontface = "bold", color = "grey35",
            inherit.aes = FALSE) +
  geom_point(size = 4, alpha = 0.9) +
  scale_color_manual(values = geno_colors, name = "Genotype") +
  scale_shape_manual(values = c(YL = 16, YR = 17, FLW = 15),
                     name   = "Tissue",
                     labels = c(YL = "Young leaf",
                                YR = "Young root",
                                FLW = "Flower")) +
  labs(title = "D — PCA of genotype × tissue by glycosylation profile",
       x = paste0("PC1 (", var_exp[1], "% variance)"),
       y = paste0("PC2 (", var_exp[2], "% variance)")) +
  base_theme +
  theme(legend.position = "right")

legend_tbl <- loadings_df %>%
  arrange(num) %>%
  mutate(label = paste0(num, ".  ", Pattern))

pD_legend <- ggplot() +
  annotate("text",
           x = 0.05, y = rev(seq_len(nrow(legend_tbl))),
           label  = legend_tbl$label,
           hjust  = 0, size = 3.0,
           family = "mono", color = "grey25") +
  xlim(0, 1.8) +
  ylim(0.3, nrow(legend_tbl) + 0.8) +
  labs(title = "Patterns") +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.title      = element_text(size = 9, face = "bold",
                                   color = "grey30", hjust = 0,
                                   margin = margin(b = 8))
  )

pD <- pD_plot + pD_legend +
  plot_layout(widths = c(2.5, 1.5))

# ── Panel E : Top 7 glycosylation patterns by tissue (± SE) ──
# ── Panel T-C : Top patterns per tissue (grouped bars + SE) ──
pattern_tissue <- long_df %>%
  filter(!is.na(Glycosylation), Glycosylation %in% top_patterns_tissue) %>%
  group_by(Genotype, Tissue, Glycosylation) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  # complete: some genotype × tissue × pattern combos may be absent
  tidyr::complete(Genotype, Tissue,
                  Glycosylation = top_patterns_tissue,
                  fill = list(total_area = 0)) %>%
  group_by(Genotype, Tissue) %>%
  mutate(
    denom = sum(total_area),
    pct   = if_else(denom > 0, total_area / denom * 100, 0)
  ) %>%
  ungroup() %>%
  group_by(Tissue, Glycosylation) %>%
  summarise(
    mean_pct = mean(pct),
    se_pct   = sd(pct) / sqrt(n()),
    .groups  = "drop"
  ) %>%
  mutate(
    Tissue        = factor(Tissue,        levels = c("YL", "YR", "FLW")),
    Glycosylation = factor(Glycosylation, levels = rev(top_patterns_tissue))
  )

pTC <- ggplot(pattern_tissue,
              aes(x = mean_pct, y = Glycosylation, fill = Tissue)) +
  geom_col(width = 0.65, position = position_dodge(width = 0.7),
           color = "white", linewidth = 0.2) +
  geom_errorbar(aes(xmin = mean_pct - se_pct,
                    xmax = mean_pct + se_pct),
                position = position_dodge(width = 0.7),
                width = 0.25, linewidth = 0.4, color = "grey40") +
  scale_fill_manual(values = tissue_colors,
                    name   = "Tissue",
                    labels = c(YL = "Young leaf",
                               YR = "Young root",
                               FLW = "Flower")) +
  labs(title = "C — Top 12 glycosylation patterns by tissue",
       x     = "Mean relative abundance (%)",
       y     = NULL) +
  base_theme +
  theme(
    axis.text.y     = element_text(family = "mono", size = 9),
    legend.position = "right"
  )

# ════════════════════════════════════════════════════════════
#  ASSEMBLE
# ════════════════════════════════════════════════════════════
fig <- (pA / pB) / (pC | pD) +
  plot_annotation(
    title   = "SGA glycosylation diversity across genotypes and tissues (n = 408)",
    caption = paste0(
      "Figure. Comparison of SGA glycosylation profiles across eight genotypes (FRA, ILE, ITH, MON, SIE, UNG, ZAN) ",
      "and three tissues (YL = young leaf, YR = young root, FLW = flower).\n",
      "(A) Abundance-weighted sugar type composition. ",
      "(B) Abundance-weighted glycosylation degree distribution.\n",
      "(C) Heatmap of the 12 most abundant glycosylation patterns (averaged across tissues); ",
      "dendrogram based on Euclidean distance with Ward linkage.\n",
      "(D) PCA of genotype × tissue combinations; shape encodes tissue type; ",
      "numbered arrows = top 8 discriminating patterns (see legend).\n",
      "As biological replicates were available, values represent means across replicates per genotype × tissue."
    ),
    theme = theme(
      plot.title   = element_text(face = "bold", size = 13),
      plot.caption = element_text(color = "grey40", size = 8,
                                  hjust = 0, lineheight = 1.4)
    )
  )

# ── Save ─────────────────────────────────────────────────────
ggsave("Figure_SGA_glycosylation_genotypes_tissues.pdf",
       plot = fig, width = 18, height = 16, units = "in", device = cairo_pdf)

ggsave("Figure_SGA_glycosylation_genotypes_tissues.png",
       plot = fig, width = 18, height = 16, units = "in", dpi = 300)

message("✓ Figure saved.")

# ── Save panel E (tissue patterns) as standalone figure ──────
fig_tissue_patterns <- pTC +
  plot_annotation(
    title   = "Glycosylation pattern abundance by tissue — all genotypes pooled",
    caption = paste0(
      "Figure. Mean relative abundance (± SE across genotypes) of the 7 most abundant ",
      "glycosylation patterns by tissue (YL = young leaf, YR = young root, FLW = flower).\n",
      "Error bars represent standard error across genotypes. ",
      "As biological replicates were available, values represent means per genotype × tissue."
    ),
    theme = theme(
      plot.title   = element_text(face = "bold", size = 13),
      plot.caption = element_text(color = "grey40", size = 8,
                                  hjust = 0, lineheight = 1.4)
    )
  )

ggsave("Figure_SGA_glycosylation_tissue_patterns.pdf",
       plot = fig_tissue_patterns, width = 10, height = 7,
       units = "in", device = cairo_pdf)

ggsave("Figure_SGA_glycosylation_tissue_patterns.png",
       plot = fig_tissue_patterns, width = 10, height = 7,
       units = "in", dpi = 300)

message("✓ Tissue patterns figure saved.")

# ════════════════════════════════════════════════════════════
#  FIGURE TISSUE — Differences between tissues
#  All genotypes pooled; mean ± SE across genotype replicates
#  Three panels: sugar type | glycosylation degree | top patterns
# ════════════════════════════════════════════════════════════

# Helper: compute mean + SE across genotypes for a given grouping
# Each genotype is one biological unit → mean over genotypes

# ── Panel T-A : Sugar type composition per tissue ────────────
sugar_tissue <- long_df %>%
  mutate(tokens = str_split(Glycosylation, "-")) %>%
  unnest(tokens) %>%
  mutate(tokens = str_trim(tokens)) %>%
  filter(tokens %in% names(sugar_colors)) %>%
  # % per genotype × tissue first
  group_by(Genotype, Tissue, tokens) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  rename(Sugar = tokens) %>%
  # then mean ± SE across genotypes per tissue
  group_by(Tissue, Sugar) %>%
  summarise(
    mean_pct = mean(pct),
    se_pct   = sd(pct) / sqrt(n()),
    .groups  = "drop"
  ) %>%
  mutate(
    Sugar  = factor(Sugar,  levels = names(sugar_colors)),
    Tissue = factor(Tissue, levels = c("YL", "YR", "FLW"))
  )

pTA <- ggplot(sugar_tissue, aes(x = Tissue, y = mean_pct, fill = Sugar)) +
  geom_col(width = 0.6, color = "white", linewidth = 0.3,
           position = "stack") +
  scale_fill_manual(values = sugar_colors, name = "Sugar type") +
  scale_x_discrete(labels = c(YL = "Young leaf",
                              YR = "Young root",
                              FLW = "Flower")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "A — Sugar type composition by tissue",
       x = NULL, y = "Mean relative abundance (%)") +
  base_theme +
  theme(legend.position = "right")

# ── Panel T-B : Glycosylation degree per tissue ───────────────
degree_tissue <- long_df %>%
  filter(n_sugars <= 4) %>%
  group_by(Genotype, Tissue, n_sugars) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  group_by(Tissue, n_sugars) %>%
  summarise(
    mean_pct = mean(pct),
    se_pct   = sd(pct) / sqrt(n()),
    .groups  = "drop"
  ) %>%
  mutate(
    n_sugars = factor(n_sugars, levels = 0:4),
    Tissue   = factor(Tissue, levels = c("YL", "YR", "FLW"))
  )

pTB <- ggplot(degree_tissue, aes(x = Tissue, y = mean_pct, fill = n_sugars)) +
  geom_col(width = 0.6, color = "white", linewidth = 0.3,
           position = "stack") +
  scale_fill_manual(values = degree_colors,
                    name   = "No. of sugars",
                    labels = c("0 (aglycone)", "1", "2", "3", "4")) +
  scale_x_discrete(labels = c(YL = "Young leaf",
                              YR = "Young root",
                              FLW = "Flower")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "B — Glycosylation degree by tissue",
       x = NULL, y = "Mean relative abundance (%)") +
  base_theme +
  theme(legend.position = "right")


# ── Assemble tissue figure ────────────────────────────────────
fig_tissue <- (pTA | pTB) / pTC +
  plot_layout(heights = c(1, 1.8)) +
  plot_annotation(
    title   = "Glycosylation differences across tissues — all genotypes pooled",
    caption = paste0(
      "Figure. Tissue-level comparison of SGA glycosylation profiles ",
      "across three tissues (YL = young leaf, YR = young root, FLW = flower), ",
      "averaged across all eight genotypes.\n",
      "(A) Mean abundance-weighted sugar type composition per tissue. ",
      "(B) Mean abundance-weighted glycosylation degree per tissue.\n",
      "(C) Mean relative abundance (± SE across genotypes) of the 12 most ",
      "frequent glycosylation patterns per tissue."
    ),
    theme = theme(
      plot.title   = element_text(face = "bold", size = 13),
      plot.caption = element_text(color = "grey40", size = 8,
                                  hjust = 0, lineheight = 1.4)
    )
  )

# ── Save tissue figure ────────────────────────────────────────
ggsave("Figure_SGA_glycosylation_tissues.pdf",
       plot = fig_tissue, width = 14, height = 12,
       units = "in", device = cairo_pdf)

ggsave("Figure_SGA_glycosylation_tissues.png",
       plot = fig_tissue, width = 14, height = 12,
       units = "in", dpi = 300)

message("✓ Tissue figure saved.")