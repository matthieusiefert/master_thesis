# ============================================================
#  SGA Aglycone Diversity — across genotypes and tissues
#  Input : Database_SGA_YL_YR_FLW.xlsx
#  Requires : readxl, tidyverse, ggplot2, patchwork, ggdendro
# ============================================================

library(readxl)
library(tidyverse)
library(ggplot2)
library(patchwork)
library(ggdendro)

# ── 0. Setup ─────────────────────────────────────────────────
setwd("C:/Internship/R/Aglycones")

df <- read_excel("Database_SGA_YL_YR_FLW.xlsx", sheet = 1)

# ── 1. Clean columns ─────────────────────────────────────────
df <- df %>%
  mutate(Aglycone = str_trim(Aglycone))

# ── 2. Parse peak area columns → genotype + tissue ───────────
peak_cols <- grep("Peak area per g FW", names(df), value = TRUE)
peak_cols <- peak_cols[!grepl("QC", peak_cols)]

col_meta <- tibble(col = peak_cols) %>%
  mutate(
    Genotype = str_extract(col, "(?<=GAQ_02_)[A-Za-z0-9]+(?=_)"),
    Tissue   = str_extract(col, "YL|YR|FLW")
  )

# Shorten genotype labels
geno_labels <- c(
  FRA   = "FRA", ILE21 = "ILE", ITH1  = "ITH",
  MON10 = "MON", SIE13 = "SIE", UNG1  = "UNG",
  ZAN02 = "ZAN"
)

col_meta <- col_meta %>%
  mutate(Genotype_short = geno_labels[Genotype]) %>%
  filter(!is.na(Genotype_short))   # drop any unrecognised columns

# ── 3. Color palettes ─────────────────────────────────────────
geno_colors <- c(
  FRA = "#FFD700", ILE = "#1E90FF", ITH = "#FFA500",
  MON = "#BBBB44", SIE = "#FF4500", UNG = "#32CD32",
  ZAN = "#00CCCC"
)

tissue_colors <- c(
  FLW = "#984EA3", YL = "#4DAF4A", YR = "#E41A1C"
)

# Aglycone palette — organised by biosynthetic family
aglycone_colors <- c(
  # Solasodine family (blues)
  "S"     = "#0C447C", "SD"    = "#185FA5",
  "S-ace" = "#378ADD", "CS"    = "#85B7EB",
  # Tomatidin family (greens)
  "SH"    = "#1D6E3A", "SHD"   = "#2A9D5C",
  "DHSH"  = "#52C17A",
  # Hydroxy-solasodine 1 family (oranges)
  "HS1"   = "#B85C00", "HS1H"  = "#E07B20",
  "HS1D"  = "#F5A55A",
  # Hydroxy-solasodine 2 family (reds)
  "HS2"   = "#8B0000", "HS2H"  = "#C0392B",
  "HS2D"  = "#E07070",
  # Di-hydroxy (purple)
  "DHS"   = "#6A0572"
)

# Custom grouped legend — spacer rows between families
legend_labels <- c(
  "— Solasodine —", "S", "SD", "S-ace", "CS",
  "— Tomatidin —",  "SH", "SHD", "DHSH",
  "— Hydroxy-S1 —", "HS1", "HS1H", "HS1D",
  "— Hydroxy-S2 —", "HS2", "HS2H", "HS2D",
  "— Di-hydroxy —", "DHS"
)
legend_colors <- setNames(
  c("white", aglycone_colors["S"],    aglycone_colors["SD"],
    aglycone_colors["S-ace"],          aglycone_colors["CS"],
    "white", aglycone_colors["SH"],   aglycone_colors["SHD"],
    aglycone_colors["DHSH"],
    "white", aglycone_colors["HS1"],  aglycone_colors["HS1H"],
    aglycone_colors["HS1D"],
    "white", aglycone_colors["HS2"],  aglycone_colors["HS2H"],
    aglycone_colors["HS2D"],
    "white", aglycone_colors["DHS"]),
  legend_labels
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

# ── 4. Build long_df (exclude NA aglycones) ──────────────────
long_df <- df %>%
  select(all_of(c("Aglycone", peak_cols))) %>%
  pivot_longer(cols      = all_of(peak_cols),
               names_to  = "col",
               values_to = "area") %>%
  left_join(col_meta, by = "col") %>%
  filter(area > 0,
         !is.na(Aglycone),
         !is.na(Genotype_short)) %>%
  mutate(
    Genotype = factor(Genotype_short, levels = names(geno_colors)),
    Tissue   = factor(Tissue,         levels = c("YL", "YR", "FLW")),
    Aglycone = factor(Aglycone,       levels = names(aglycone_colors))
  )

# ════════════════════════════════════════════════════════════
#  PANEL A — Donut: overall aglycone composition
# ════════════════════════════════════════════════════════════
agl_overall <- long_df %>%
  group_by(Aglycone) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  mutate(pct = total_area / sum(total_area) * 100)

# Build a grouped legend data frame for the donut
legend_df <- tibble(
  Aglycone = factor(legend_labels, levels = legend_labels),
  fill_col = legend_colors,
  is_header = str_starts(legend_labels, "—")
)

pA <- ggplot(agl_overall, aes(x = 2, y = pct, fill = Aglycone)) +
  geom_col(width = 1, color = "white", linewidth = 0.5) +
  coord_polar(theta = "y", start = 0, clip = "off") +
  xlim(0.4, 2.5) +
  scale_fill_manual(
    values = aglycone_colors,
    breaks = names(aglycone_colors),
    guide  = guide_legend(
      title    = NULL, ncol = 1,
      keywidth = 0.7, keyheight = 0.65,
      override.aes = list(color = NA)
    )
  ) +
  labs(title = "A — Overall aglycone composition") +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    legend.text     = element_text(size = 8.5, color = "grey25",
                                   face = "italic"),
    legend.position = "right",
    legend.spacing.y = unit(0.1, "cm")
  )

# ════════════════════════════════════════════════════════════
#  PANEL B — Stacked barplot: aglycone composition per tissue
# ════════════════════════════════════════════════════════════
agl_tissue <- long_df %>%
  group_by(Genotype, Tissue, Aglycone) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  group_by(Tissue, Aglycone) %>%
  summarise(mean_pct = mean(pct), .groups = "drop") %>%
  mutate(Tissue = factor(Tissue, levels = c("YL", "YR", "FLW")))

pB <- ggplot(agl_tissue, aes(x = Tissue, y = mean_pct, fill = Aglycone)) +
  geom_col(width = 0.6, color = "white", linewidth = 0.25) +
  scale_fill_manual(values = aglycone_colors, guide = "none") +
  scale_x_discrete(labels = c(YL = "Young\nleaf",
                              YR = "Young\nroot",
                              FLW = "Flower")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "B — By tissue",
       x = NULL, y = "Mean relative abundance (%)") +
  base_theme

# ════════════════════════════════════════════════════════════
#  PANEL C — Stacked barplot: aglycone composition per genotype
# ════════════════════════════════════════════════════════════
agl_geno <- long_df %>%
  group_by(Genotype, Aglycone) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup()

pC <- ggplot(agl_geno, aes(x = Genotype, y = pct, fill = Aglycone)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.25) +
  scale_fill_manual(values = aglycone_colors, guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.03)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = "C — By genotype",
       x = NULL, y = "Relative abundance (%)") +
  base_theme +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9))

# ════════════════════════════════════════════════════════════
#  PANEL D — Heatmap + dendrogram: genotype × aglycone
#  All values shown; colour scale log-transformed for readability
# ════════════════════════════════════════════════════════════
top_aglycones <- long_df %>%
  group_by(Aglycone) %>%
  summarise(total = sum(area), .groups = "drop") %>%
  arrange(desc(total)) %>%
  slice_head(n = 10) %>%
  pull(Aglycone) %>%
  as.character()

heat_wide <- long_df %>%
  filter(!is.na(Aglycone),
         as.character(Aglycone) %in% top_aglycones) %>%
  group_by(Genotype, Aglycone) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  tidyr::complete(Genotype, Aglycone = top_aglycones,
                  fill = list(pct = 0)) %>%
  pivot_wider(id_cols     = Genotype,
              names_from  = Aglycone,
              values_from = pct,
              values_fill = 0)

heat_mat <- heat_wide %>% select(-Genotype) %>% as.matrix()
rownames(heat_mat) <- heat_wide$Genotype

dend_geno  <- hclust(dist(heat_mat), method = "ward.D2")
geno_order <- dend_geno$labels[dend_geno$order]
dend_segs  <- dendro_data(as.dendrogram(dend_geno), type = "rectangle")

pD_dend <- ggplot() +
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
  pivot_longer(-Genotype, names_to = "Aglycone", values_to = "pct") %>%
  mutate(
    Genotype = factor(Genotype, levels = geno_order),
    Aglycone = factor(Aglycone, levels = rev(top_aglycones)),
    # log1p transform for colour scale readability
    pct_log  = log1p(pct)
  )

pD_heat <- ggplot(heat_df, aes(x = Genotype, y = Aglycone, fill = pct_log)) +
  geom_tile(color = "white", linewidth = 0.5) +
  # Show all values, size adapted to magnitude
  geom_text(aes(label = round(pct, 1),
                size  = pmin(pct, 10)),   # cap size scaling
            color = "white", fontface = "bold", show.legend = FALSE) +
  scale_size_continuous(range = c(1.8, 3.2)) +
  scale_fill_gradientn(
    colors = c("#E6F1FB", "#85B7EB", "#185FA5", "#0C447C"),
    name   = "% abundance\n(log scale)",
    labels = function(x) round(expm1(x), 1),
    guide  = guide_colorbar(barwidth       = 7,
                            barheight      = 0.6,
                            title.position = "top",
                            title.hjust    = 0.5)
  ) +
  labs(y = NULL, x = NULL) +
  base_theme +
  theme(
    axis.text.x     = element_blank(),
    axis.text.y     = element_text(face = "italic", size = 9),
    legend.position = "bottom",
    panel.grid      = element_blank()
  )

pD <- pD_dend / pD_heat +
  plot_layout(heights = c(1, 4)) +
  plot_annotation(
    title = "D — Aglycone profile per genotype (top 10)",
    theme = theme(plot.title = element_text(face = "bold", size = 11))
  )

# ════════════════════════════════════════════════════════════
#  PANEL E — PCA with tissue ellipses
# ════════════════════════════════════════════════════════════
pca_wide <- long_df %>%
  filter(!is.na(Aglycone)) %>%
  group_by(Genotype, Tissue, Aglycone) %>%
  summarise(total_area = sum(area), .groups = "drop") %>%
  group_by(Genotype, Tissue) %>%
  mutate(pct = total_area / sum(total_area) * 100) %>%
  ungroup() %>%
  unite("sample_id", Genotype, Tissue, sep = "_") %>%
  pivot_wider(id_cols     = sample_id,
              names_from  = Aglycone,
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
  rownames_to_column("Aglycone") %>%
  mutate(contrib = sqrt(PC1^2 + PC2^2)) %>%
  slice_max(contrib, n = 6) %>%
  mutate(num = row_number())

arrow_scale <- 0.75 * max(abs(c(pca_df$PC1, pca_df$PC2))) /
  max(sqrt(pca_res$rotation[,1]^2 + pca_res$rotation[,2]^2))

loadings_df <- loadings_df %>%
  mutate(PC1s = PC1 * arrow_scale, PC2s = PC2 * arrow_scale)

# Tissue centroids for ellipse labels
tissue_centers <- pca_df %>%
  group_by(Tissue) %>%
  summarise(PC1 = mean(PC1), PC2 = mean(PC2), .groups = "drop")

pE_plot <- ggplot(pca_df,
                  aes(x = PC1, y = PC2,
                      color = Genotype, shape = Tissue)) +
  geom_hline(yintercept = 0, color = "grey80", linewidth = 0.3) +
  geom_vline(xintercept = 0, color = "grey80", linewidth = 0.3) +
  # Tissue shaded ellipses
  stat_ellipse(aes(group = Tissue, fill = Tissue),
               geom  = "polygon",
               alpha = 0.12, level = 0.80, type = "norm",
               color = NA, inherit.aes = TRUE, show.legend = FALSE) +
  # Loading arrows
  geom_segment(data = loadings_df,
               aes(x = 0, y = 0, xend = PC1s, yend = PC2s),
               arrow = arrow(length = unit(0.18, "cm"), type = "closed"),
               color = "grey65", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = loadings_df,
            aes(x = PC1s * 1.07, y = PC2s * 1.07, label = num),
            size = 3.2, fontface = "bold", color = "grey35",
            inherit.aes = FALSE) +
  geom_point(size = 4, alpha = 0.95) +
  geom_text(aes(label = Genotype),
            nudge_y = 0.18, size = 2.8, fontface = "bold",
            show.legend = FALSE) +
  # Tissue ellipse label at centroid
  geom_text(data = tissue_centers,
            aes(x = PC1, y = PC2, label = Tissue, color = NULL),
            size = 3.5, fontface = "bold.italic",
            color = "grey30", inherit.aes = FALSE) +
  scale_fill_manual(values = tissue_colors,
                    name   = "Tissue (ellipse)",
                    labels = c(YL = "Young leaf",
                               YR = "Young root",
                               FLW = "Flower")) +
  scale_color_manual(values = geno_colors, name = "Genotype") +
  scale_shape_manual(values = c(YL = 16, YR = 17, FLW = 15),
                     name   = "Tissue",
                     labels = c(YL = "Young leaf",
                                YR = "Young root",
                                FLW = "Flower")) +
  guides(fill = guide_legend(override.aes = list(alpha = 0.35))) +
  labs(title = "E — PCA by aglycone profile (genotype × tissue)",
       x = paste0("PC1 (", var_exp[1], "% variance)"),
       y = paste0("PC2 (", var_exp[2], "% variance)")) +
  base_theme +
  theme(legend.position = "right")

# Numbered aglycone legend
legend_tbl <- loadings_df %>%
  arrange(num) %>%
  mutate(label = paste0(num, ".  ", Aglycone))

pE_legend <- ggplot() +
  annotate("text",
           x = 0.05, y = rev(seq_len(nrow(legend_tbl))),
           label = legend_tbl$label,
           hjust = 0, size = 3.1,
           family = "mono", color = "grey25") +
  xlim(0, 1.5) +
  ylim(0.3, nrow(legend_tbl) + 0.8) +
  labs(title = "Aglycones") +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.title      = element_text(size = 9, face = "bold",
                                   color = "grey30", hjust = 0,
                                   margin = margin(b = 8))
  )

pE <- pE_plot + pE_legend +
  plot_layout(widths = c(3, 1))

# ════════════════════════════════════════════════════════════
#  ASSEMBLE
# ════════════════════════════════════════════════════════════
fig <- (pA | pB | pC) / (pD | pE) +
  plot_layout(heights = c(1, 1.4)) +
  plot_annotation(
    title   = "Aglycone structural diversity across genotypes and tissues",
    caption = paste0(
      "Figure. Aglycone scaffold diversity across seven genotypes ",
      "(FRA, ILE, ITH, MON, SIE, UNG, ZAN) and three tissues ",
      "(YL = young leaf, YR = young root, FLW = flower).\n",
      "(A) Overall aglycone composition (all genotypes and tissues pooled); ",
      "colours grouped by biosynthetic family. ",
      "(B) Mean aglycone composition by tissue. ",
      "(C) Aglycone composition by genotype (all tissues pooled).\n",
      "(D) Heatmap of top 10 aglycones per genotype; colour scale log-transformed ",
      "to reveal low-abundance variants; dendrogram: Euclidean, Ward linkage.\n",
      "(E) PCA of genotype × tissue combinations; shaded ellipses (80% CI) group ",
      "tissue types; numbered arrows = top 6 discriminating aglycones (see legend)."
    ),
    theme = theme(
      plot.title   = element_text(face = "bold", size = 13),
      plot.caption = element_text(color = "grey40", size = 8,
                                  hjust = 0, lineheight = 1.4)
    )
  )

# ── Save ─────────────────────────────────────────────────────
ggsave("Figure_SGA_aglycone_diversity.pdf",
       plot = fig, width = 18, height = 14,
       units = "in", device = cairo_pdf)

ggsave("Figure_SGA_aglycone_diversity.png",
       plot = fig, width = 18, height = 14,
       units = "in", dpi = 300)

message("✓ Figure saved as Figure_SGA_aglycone_diversity.pdf / .png")