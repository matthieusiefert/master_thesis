import pandas as pd
import re
import sys
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# 1. FW TABLE
# ─────────────────────────────────────────────────────────────────────────────
FW_DATA = {
    # ── Young Leaf (YL) ──────────────────────────────────────────────────────
    ("SIE13", 1, "YL"): 0.121, ("SIE13", 2, "YL"): 0.121, ("SIE13", 3, "YL"): 0.107,
    ("SIE13", 4, "YL"): 0.123, ("SIE13", 5, "YL"): 0.110,
    ("MON10", 1, "YL"): 0.117, ("MON10", 2, "YL"): 0.120, ("MON10", 3, "YL"): 0.110,
    ("MON10", 4, "YL"): 0.110, ("MON10", 5, "YL"): 0.115,
    ("UNG1",  1, "YL"): 0.113, ("UNG1",  2, "YL"): 0.126, ("UNG1",  3, "YL"): 0.110,
    ("UNG1",  4, "YL"): 0.116, ("UNG1",  5, "YL"): 0.121,
    ("ILE21", 1, "YL"): 0.124, ("ILE21", 2, "YL"): 0.117, ("ILE21", 3, "YL"): 0.112,
    ("ILE21", 4, "YL"): 0.109, ("ILE21", 5, "YL"): 0.124,
    ("ITH1",  1, "YL"): 0.117, ("ITH1",  2, "YL"): 0.103,
    ("ZAN02", 1, "YL"): 0.126, ("ZAN02", 2, "YL"): 0.126, ("ZAN02", 3, "YL"): 0.121,
    ("ZAN02", 4, "YL"): 0.121, ("ZAN02", 5, "YL"): 0.126,
    ("FRA",   1, "YL"): 0.118, ("FRA",   2, "YL"): 0.115, ("FRA",   3, "YL"): 0.111,
    ("FRA",   4, "YL"): 0.117, ("FRA",   5, "YL"): 0.112,
    ("EBB16", 1, "YL"): 0.115, ("EBB16", 2, "YL"): 0.118, ("EBB16", 3, "YL"): 0.103,

    # ── Young Root (YR) ──────────────────────────────────────────────────────
    ("SIE13", 2, "YR"): 0.117, ("SIE13", 3, "YR"): 0.120, ("SIE13", 4, "YR"): 0.087,
    ("SIE13", 5, "YR"): 0.075,
    ("MON10", 2, "YR"): 0.100, ("MON10", 3, "YR"): 0.102, ("MON10", 4, "YR"): 0.135,
    ("MON10", 5, "YR"): 0.081,
    ("UNG1",  2, "YR"): 0.129, ("UNG1",  3, "YR"): 0.120, ("UNG1",  4, "YR"): 0.129,
    ("UNG1",  5, "YR"): 0.123,
    ("ILE21", 2, "YR"): 0.075, ("ILE21", 3, "YR"): 0.108, ("ILE21", 4, "YR"): 0.079,
    ("ILE21", 5, "YR"): 0.073,
    ("ITH1",  1, "YR"): 0.112, ("ITH1",  2, "YR"): 0.103,
    ("ZAN02", 1, "YR"): 0.120, ("ZAN02", 2, "YR"): 0.115, ("ZAN02", 3, "YR"): 0.119,
    ("ZAN02", 4, "YR"): 0.094, ("ZAN02", 5, "YR"): 0.133,
    ("FRA",   1, "YR"): 0.107, ("FRA",   2, "YR"): 0.119, ("FRA",   3, "YR"): 0.090,
    ("FRA",   4, "YR"): 0.094, ("FRA",   5, "YR"): 0.093,
    ("EBB16", 1, "YR"): 0.132, ("EBB16", 2, "YR"): 0.104, ("EBB16", 3, "YR"): 0.109,

    # ── Flower (FLW) ─────────────────────────────────────────────────────────
    ("SIE13", 1, "FLW"): 0.097, ("SIE13", 2, "FLW"): 0.124, ("SIE13", 3, "FLW"): 0.115,
    ("SIE13", 4, "FLW"): 0.093, ("SIE13", 5, "FLW"): 0.097,
    ("MON10", 1, "FLW"): 0.111, ("MON10", 2, "FLW"): 0.131, ("MON10", 3, "FLW"): 0.107,
    ("MON10", 4, "FLW"): 0.106, ("MON10", 5, "FLW"): 0.114,
    ("UNG1",  1, "FLW"): 0.115, ("UNG1",  2, "FLW"): 0.124, ("UNG1",  3, "FLW"): 0.109,
    ("UNG1",  4, "FLW"): 0.082, ("UNG1",  5, "FLW"): 0.079,
    ("ILE21", 1, "FLW"): 0.102, ("ILE21", 2, "FLW"): 0.077, ("ILE21", 3, "FLW"): 0.081,
    ("ILE21", 4, "FLW"): 0.082, ("ILE21", 5, "FLW"): 0.091,
    ("ITH1",  1, "FLW"): 0.077, ("ITH1",  2, "FLW"): 0.076,
    ("ZAN02", 1, "FLW"): 0.110, ("ZAN02", 2, "FLW"): 0.104, ("ZAN02", 3, "FLW"): 0.088,
    ("ZAN02", 4, "FLW"): 0.102, ("ZAN02", 5, "FLW"): 0.102,
    ("FRA",   1, "FLW"): 0.085, ("FRA",   2, "FLW"): 0.085, ("FRA",   3, "FLW"): 0.070,
    ("FRA",   4, "FLW"): 0.065, ("FRA",   5, "FLW"): 0.066,
    ("SEI3",  1, "FLW"): 0.089, ("SEI3",  2, "FLW"): 0.070, ("SEI3",  3, "FLW"): 0.078,
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. CSV
# ─────────────────────────────────────────────────────────────────────────────
csv_path = Path("ALL_iimn_gnps_quant.csv")
if not csv_path.exists():
    csv_path = Path("/mnt/user-data/uploads/ALL_iimn_gnps_quant.csv")

df = pd.read_csv(csv_path)

peak_cols = [c for c in df.columns if "Peak area" in c]
meta_cols = [c for c in df.columns if "Peak area" not in c and not c.startswith("Unnamed")]

print(f"Lignes (features)  : {len(df)}")
print(f"Colonnes Peak area : {len(peak_cols)}")

# ─────────────────────────────────────────────────────────────────────────────
# 3. PARSING
# ─────────────────────────────────────────────────────────────────────────────
def parse_sample(col_name: str):
    """Return (genotype, replicate_int, tissue_code) or (None, None, None)."""
    name = col_name.replace(".mzML Peak area", "").strip()

    # Format A : GENOTYPE_REP_TISSUE
    m = re.match(r"GAQ_\d+_([A-Za-z0-9]+)_(\d+)_([A-Z]+)_", name)
    if m:
        return m.group(1).upper(), int(m.group(2)), m.group(3).upper()

    # Format B : GENOTYPE_TISSUEn
    m = re.match(r"GAQ_\d+_([A-Za-z0-9]+)_([A-Z]+)(\d+)_", name)
    if m:
        return m.group(1).upper(), int(m.group(3)), m.group(2).upper()

    print(f"  ⚠ Impossible de parser : {col_name}", file=sys.stderr)
    return None, None, None

# ─────────────────────────────────────────────────────────────────────────────
# 4. MAPPING COLONNE → FW
# ─────────────────────────────────────────────────────────────────────────────
col_to_fw   = {}
col_to_meta = {}
missing_fw  = []

for col in peak_cols:
    geno, rep, tissue = parse_sample(col)
    col_to_meta[col] = (geno, rep, tissue)
    if geno is None:
        col_to_fw[col] = float("nan")
        continue
    fw = FW_DATA.get((geno, rep, tissue), float("nan"))
    col_to_fw[col] = fw
    if pd.isna(fw):
        missing_fw.append(f"{geno}_{rep}_{tissue}")

if missing_fw:
    print(f"\n⚠ FW missing for : {', '.join(missing_fw)}")
    print("  → NaN columns.\n")

# ─────────────────────────────────────────────────────────────────────────────
# 5. NORMALISATION  :  Peak area / FW (g)
# ─────────────────────────────────────────────────────────────────────────────
norm_dict = {}
for col in peak_cols:
    fw = col_to_fw[col]
    new_col = col.replace("Peak area", "Peak area per g FW")
    norm_dict[new_col] = float("nan") if (pd.isna(fw) or fw == 0) else df[col] / fw

df_norm = pd.concat([df[meta_cols], pd.DataFrame(norm_dict, index=df.index)], axis=1)

print("Normalisation over.")
print(f"  Features normalised : {len(df)}")
print(f"  Samples treated : {len(peak_cols)}")

# ─────────────────────────────────────────────────────────────────────────────
# 6. TABLE
# ─────────────────────────────────────────────────────────────────────────────
fw_table = pd.DataFrame([
    {"column": col, "genotype": col_to_meta[col][0],
     "replicate": col_to_meta[col][1], "tissue": col_to_meta[col][2],
     "FW_g": col_to_fw[col]}
    for col in peak_cols
])

# ─────────────────────────────────────────────────────────────────────────────
# 7. SAVE
# ─────────────────────────────────────────────────────────────────────────────
out_dir = Path(".")

df_norm.to_csv(out_dir / "ALL_normalized.csv", index=False)
fw_table.to_csv(out_dir / "fw_table_ALL.csv", index=False)

print(f"\n✅ Saved files :")
print(f"   ALL_normalized.csv")
print(f"   fw_table_ALL.csv")

print("\n--- Résumé FW par tissu ---")
print(fw_table.groupby("tissue")["FW_g"].agg(["count", "mean", "min", "max"]).round(3).to_string())
