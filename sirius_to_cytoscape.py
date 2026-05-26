"""
SIRIUS → Cytoscape node table enrichment script
================================================
Merges SIRIUS 6 output files with an MZmine IIMN quant table
for import into Cytoscape as an enriched GNPS FBMN node table.

Join key: mappingFeatureId (SIRIUS) == row ID (MZmine/GNPS quant CSV)

Input files (edit paths below):
    - MZmine IIMN quant CSV           (e.g. *_iimn_gnps_quant.csv)
    - formula_identifications.tsv     (SIRIUS)
    - structure_identifications.tsv   (SIRIUS / CSI:FingerID)
    - canopus_formula_summary.tsv     (SIRIUS / CANOPUS, formula-level)
    - canopus_structure_summary.tsv   (SIRIUS / CANOPUS, structure-level)

Output:
    - node_table_SIRIUS_enriched.tsv  → import into Cytoscape via
      File → Import → Table from File, key column = "row ID"

Usage:
    python sirius_to_cytoscape.py

Requirements:
    pip install pandas
"""

import pandas as pd

# ─── 1. FILE PATHS ────────────────────────────────────────────────────────────
# Edit these to match your actual file locations

QUANT_CSV              = "ALL_normalized.csv"
FORMULA_TSV            = "formula_identifications.tsv"
STRUCTURE_TSV          = "structure_identifications.tsv"
CANOPUS_FORMULA_TSV    = "canopus_formula_summary.tsv"
CANOPUS_STRUCTURE_TSV  = "canopus_structure_summary.tsv"

OUTPUT_TSV             = "ALL_SIRIUS_enriched.tsv"

# ─── 2. LOAD FILES ────────────────────────────────────────────────────────────

print("Loading files...")

quant             = pd.read_csv(QUANT_CSV)
formula           = pd.read_csv(FORMULA_TSV,           sep="\t")
structure         = pd.read_csv(STRUCTURE_TSV,         sep="\t")
canopus_formula   = pd.read_csv(CANOPUS_FORMULA_TSV,   sep="\t")
canopus_structure = pd.read_csv(CANOPUS_STRUCTURE_TSV, sep="\t")

print(f"  Quant rows:              {len(quant)}")
print(f"  Formula identifications: {len(formula)}")
print(f"  Structure identifications: {len(structure)}")
print(f"  CANOPUS formula:         {len(canopus_formula)}")
print(f"  CANOPUS structure:       {len(canopus_structure)}")

# ─── 3. KEEP BEST RANK PER FEATURE ───────────────────────────────────────────
# formulaRank == 1      → best SIRIUS formula hit
# structurePerIdRank == 1 → best CSI:FingerID structure hit
# CANOPUS formula: also formulaRank == 1
# CANOPUS structure: matched to the same formulaRank as the best structure hit

formula_r1         = formula[formula["formulaRank"] == 1].copy()
structure_r1       = structure[structure["structurePerIdRank"] == 1].copy()
canopus_formula_r1 = canopus_formula[canopus_formula["formulaRank"] == 1].copy()

# For CANOPUS structure, keep the row whose formulaRank matches the best structure hit
struct_formula_ranks = (
    structure_r1[["mappingFeatureId", "formulaRank"]]
    .rename(columns={"formulaRank": "formulaRank_struct"})
)
canopus_structure_best = canopus_structure.merge(
    struct_formula_ranks,
    left_on=["mappingFeatureId", "formulaRank"],
    right_on=["mappingFeatureId", "formulaRank_struct"],
    how="inner"
)

# ─── 4. SELECT COLUMNS ────────────────────────────────────────────────────────

formula_cols = [
    "mappingFeatureId",
    "molecularFormula", "adduct",
    "ZodiacScore", "SiriusScoreNormalized",
    "ionMass", "retentionTimeInMinutes",
    "overallFeatureQuality",
]

structure_cols = [
    "mappingFeatureId",
    "name", "smiles", "InChIkey2D", "InChI",
    "ConfidenceScoreExact", "ConfidenceScoreApproximate",
    "CSI:FingerIDScore",
    "xlogp", "pubchemids",
]

canopus_cols = [
    "mappingFeatureId",
    "NPC#pathway",            "NPC#pathway Probability",
    "NPC#superclass",         "NPC#superclass Probability",
    "NPC#class",              "NPC#class Probability",
    "ClassyFire#superclass",
    "ClassyFire#class",
    "ClassyFire#subclass",
    "ClassyFire#most specific class",
]

# Rename CANOPUS columns to distinguish formula-level vs structure-level
canopus_formula_renamed = canopus_formula_r1[canopus_cols].copy()
canopus_formula_renamed.columns = (
    ["mappingFeatureId"]
    + ["CANOPUS_formula_" + c for c in canopus_cols[1:]]
)

canopus_structure_renamed = canopus_structure_best[canopus_cols].copy()
canopus_structure_renamed.columns = (
    ["mappingFeatureId"]
    + ["CANOPUS_structure_" + c for c in canopus_cols[1:]]
)

# ─── 5. MERGE ONTO QUANT TABLE ────────────────────────────────────────────────
# Start from the full quant table so every GNPS node is preserved (left join).
# Unannotated features get NaN in SIRIUS columns.

quant_cols = [
    "row ID", "row m/z", "row retention time",
    "annotation network number", "best ion",
    "correlation group ID", "partners", "neutral M mass",
]

node_table = quant[quant_cols].copy()
node_table = node_table.rename(columns={"row ID": "mappingFeatureId"})

node_table = node_table.merge(formula_r1[formula_cols],          on="mappingFeatureId", how="left")
node_table = node_table.merge(structure_r1[structure_cols],      on="mappingFeatureId", how="left")
node_table = node_table.merge(canopus_formula_renamed,           on="mappingFeatureId", how="left")
node_table = node_table.merge(canopus_structure_renamed,         on="mappingFeatureId", how="left")

node_table = node_table.rename(columns={"mappingFeatureId": "row ID"})

# ─── 6. HELPER COLUMNS FOR CYTOSCAPE VISUALISATION ───────────────────────────

# Annotation tier — useful for mapping node colour in Cytoscape Style panel
def annotation_tier(row):
    if pd.notna(row.get("name")):
        return "CSI:FingerID structure"
    elif pd.notna(row.get("molecularFormula")):
        return "Formula only"
    return "Unannotated"

node_table["SIRIUS_annotation_tier"] = node_table.apply(annotation_tier, axis=1)

# Best available annotation for node label
node_table["SIRIUS_best_annotation"] = node_table.apply(
    lambda r: r["name"] if pd.notna(r.get("name")) else
              r["molecularFormula"] if pd.notna(r.get("molecularFormula")) else "",
    axis=1
)

# Short display label for readable network labels:
#   priority → short name (split at first comma/parenthesis, max 30 chars)
#           → molecular formula
#           → NPC class
#           → m/z fallback
def make_label(row):
    name = str(row.get("name") or "")
    short = name.split(",")[0].split("(")[0].strip()
    if 0 < len(short) <= 30:
        return short
    if pd.notna(row.get("molecularFormula")):
        return str(row["molecularFormula"])
    if pd.notna(row.get("CANOPUS_formula_NPC#class")):
        return str(row["CANOPUS_formula_NPC#class"])
    return f"m/z {row['row m/z']:.4f}"

node_table["label_display"] = node_table.apply(make_label, axis=1)

# ─── 7. SUMMARY ───────────────────────────────────────────────────────────────

print("\nAnnotation summary:")
print(node_table["SIRIUS_annotation_tier"].value_counts().to_string())

print("\nCANOPUS NPC pathway distribution:")
print(node_table["CANOPUS_formula_NPC#pathway"].value_counts().to_string())

print(f"\nFinal node table: {node_table.shape[0]} nodes × {node_table.shape[1]} columns")

# ─── 8. SAVE ──────────────────────────────────────────────────────────────────

node_table.to_csv(OUTPUT_TSV, sep="\t", index=False)
print(f"\nSaved → {OUTPUT_TSV}")
print("""
─── Cytoscape import instructions ──────────────────────────────────────────────
1. Open your GNPS FBMN .graphml in Cytoscape
2. File → Import → Table from File → select node_table_SIRIUS_enriched.tsv
3. Import Data as: Node Table
4. Key Column for Network: shared name  (maps to 'row ID')
5. Style panel suggestions:
     Node colour  → SIRIUS_annotation_tier
     Node label   → label_display
     Label size   → 8–9 pt
─────────────────────────────────────────────────────────────────────────────────
""")
