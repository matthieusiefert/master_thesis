# Steroidal Glycoalkaloid (SGA) Metabolomics Analysis Pipeline

This repository contains an integrated suite of Python and R scripts designed for the processing, annotation enrichment, statistical analysis, and geospatial visualization of liquid chromatography–mass spectrometry (LC-MS) metabolomics data. The pipeline is optimized for exploring the structural diversity of **Steroidal Glycoalkaloids (SGAs)** and **Steroidal Saponins** across multiple plant genotypes and tissues (Young Leaves, Young Roots, and Flowers).

---

## Pipeline Overview

The project is structurally divided into two major functional sections:
1. **Data Preprocessing & Annotation Enrichment (Python)**: Handles peak area normalization by fresh weight, extracts and ranks multi-layered structural annotations (SIRIUS, CSI:FingerID, CANOPUS), queries public chemical APIs (PubChem), and generates formatted, user-friendly Excel databases.
2. **Statistical Analysis & Visualizations (R)**: Maps the geographical origins of the collected populations and renders publication-ready composite figures detailing aglycone distribution and glycosylation patterns.

---

## Script-by-Script Breakdown

### 1. Preprocessing & Chemical Annotation (Python)

* **`normalize_by_FW_ALL.py`**
  * **Purpose**: Normalizes raw LC-MS peak areas (e.g., exported from MZmine) against the unique **F**resh **W**eight (FW, in grams) of each biological sample across three tissue types (YL = Young Leaf, YR = Young Root, FLW = Flower).
  * **Outputs**: `ALL_normalized.csv` and a metadata summary table `fw_table_ALL.csv`.

* **`sirius_to_cytoscape.py`**
  * **Purpose**: Merges the fresh-weight-normalized quantification data with structural outputs from **SIRIUS**, **CSI:FingerID**, and **CANOPUS**. It filters the datasets to retain only the top-ranked annotation tier (Rank 1) for each MS/MS feature, mapping network labels to short chemical names, molecular formulas, or classification pathways.
  * **Output**: `ALL_SIRIUS_enriched.tsv` (Cytoscape-ready node attribute table).

* **`fetch_smiles_from_inchikey.py`**
  * **Purpose**: Parses the enriched node table for unique `InChIKey2D` identifiers and systematically queries the **PubChem PUG REST API** to retrieve missing Canonical and Isomeric SMILES strings. It includes built-in rate-limiting delays to prevent HTTP 429 errors.
  * **Output**: `node_table_SIRIUS_enriched_smiles.tsv`.

* **`merge_quant_annotations.py`**
  * **Purpose**: Performs an inner join between raw MS1 quantification tables and corresponding structural annotations. It cross-references peak alignments using a customizable Retention Time (RT) tolerance window (`RT_TOL = 0.10` min) to robustly separate true positional isomers from chromatographic artifacts.
  * **Output**: `merged_quant_annotations.xlsx`.

* **`database_style.py`**
  * **Purpose**: Converts the raw flat file (`SGA_table_positive_final.csv`) into a polished, highly readable Excel workbook using `openpyxl`. It color-codes structural metadata headers (Navy theme), auto-fits columns, freezes top panes, and implements **conditional formatting** (Red-Yellow-Green gradients for Sirius confidence scores; data bars for peak intensities).
  * **Output**: `SGA Steroidal Saponins` curated spreadsheet.

---

### 2. Structural Diversity & Geospatial Mapping (R)

These scripts utilize `ggplot2` alongside the `patchwork` engine to stitch complex, multi-panel figures together for publication.

* **`map.R`**
  * **Purpose**: Generates a high-precision geographic map highlighting the exact coordinates of the source populations/genotypes (e.g., ILE21, MON10, ITH1, ZAN02, SIE13, FRA, UNG1). It blends specialized geospatial layers (`sf`, `rnaturalearth`) to create a detailed regional map complete with north arrows and scale bars, alongside a global overview inset window.

* **`aglycones.R`**
  * **Purpose**: Tracks structural mutations and concentrations across aglycone families (e.g., Solasodine, Tomatidine, Hydroxy-solasodines, DHS). Computes and combines interactive *Donut charts*, stacked bar plots, Ward-linkage hierarchical clustering heatmaps (log-transformed to reveal low-abundance variants), and Principal Component Analyses (PCA).
  * **Output**: `Figure_SGA_aglycone_diversity.pdf`.

* **`glycosylation.R`**
  * **Purpose**: Investigates sugar moiety decoration dynamics. The script counts glycosidic linkages (`n_sugars`) and computes the abundance-weighted distribution of distinct sugar types (Hexoses, Deoxyhexoses, Pentoses, Glucuronic Acid) to identify tissue-specific glycosylation profiles.
  * **Output**: `Figure_SGA_glycosylation_tissues.pdf`.

---

## Prerequisites & Dependencies

### Python Environment (3.x)
Ensure your environment has the following processing and networking libraries installed:
```bash
pip install pandas openpyxl requests tqdm

install.packages(c("readxl", "tidyverse", "ggplot2", "patchwork", "ggdendro", 
                   "sf", "rnaturalearth", "rnaturalearthdata", "ggspatial", "cowplot", "ggrepel"))

## Expected Input Data Formats
LC-MS Peak Tables: Standard .csv or .tsv files populated with row m/z, row retention time, and distinct sample column names following the string format: GAQ_02_[Genotype]_[Tissue]_[Replicate].

SGA Structural Database: The statistical visualization scripts (aglycones.R and glycosylation.R) expect a curated spreadsheet named Database_SGA_YL_YR_FLW.xlsx placed inside your active working directory, containing cleaned columns labeled Aglycone and Glycosylation.
