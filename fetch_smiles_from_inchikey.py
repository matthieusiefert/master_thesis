import time
import requests
import pandas as pd
from tqdm import tqdm

# ─── 1. FILE PATHS ────────────────────────────────────────────────────────────

INPUT_TSV  = "node_table_SIRIUS_enriched.tsv"
OUTPUT_TSV = "node_table_SIRIUS_enriched_smiles.tsv"

# PubChem rate limit: max 5 requests/second
# Set a conservative delay to avoid HTTP 429 errors
REQUEST_DELAY_SECONDS = 0.25

# ─── 2. LOAD TABLE ────────────────────────────────────────────────────────────

print("Loading node table...")
node_table = pd.read_csv(INPUT_TSV, sep="\t")
print(f"  {len(node_table)} nodes loaded")

# ─── 3. COLLECT UNIQUE INCHIKEYS TO QUERY ────────────────────────────────────

needs_smiles = node_table[
    node_table["InChIkey2D"].notna() &
    (node_table["smiles"].isna() | (node_table["smiles"] == ""))
]["InChIkey2D"].unique()

print(f"  {len(needs_smiles)} unique InChIKey2D values to query on PubChem")

# ─── 4. QUERY PUBCHEM ─────────────────────────────────────────────────────────

BASE_URL = "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/inchikey/{key}/property/CanonicalSMILES,IsomericSMILES/JSON"

smiles_cache = {}   # InChIKey2D → canonical SMILES

for key in tqdm(needs_smiles, desc="Querying PubChem"):
    url = BASE_URL.format(key=key)
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            data = response.json()
            props = data["PropertyTable"]["Properties"][0]
            # Prefer isomeric SMILES (retains stereo), fall back to canonical
            smiles_cache[key] = props.get("IsomericSMILES") or props.get("CanonicalSMILES")
        elif response.status_code == 404:
            smiles_cache[key] = None   # not found in PubChem
        else:
            print(f"\n  Warning: HTTP {response.status_code} for key {key}")
            smiles_cache[key] = None
    except Exception as e:
        print(f"\n  Error for key {key}: {e}")
        smiles_cache[key] = None

    time.sleep(REQUEST_DELAY_SECONDS)

# ─── 5. FILL SMILES COLUMN ────────────────────────────────────────────────────

def fill_smiles(row):
    # If SMILES already present, keep it
    if pd.notna(row.get("smiles")) and str(row["smiles"]).strip():
        return row["smiles"]
    # Otherwise look up from cache
    key = row.get("InChIkey2D")
    if pd.notna(key):
        return smiles_cache.get(key)
    return None

node_table["smiles"] = node_table.apply(fill_smiles, axis=1)

# ─── 6. SUMMARY ───────────────────────────────────────────────────────────────

total_with_smiles   = node_table["smiles"].notna().sum()
retrieved           = sum(1 for v in smiles_cache.values() if v is not None)
not_found           = sum(1 for v in smiles_cache.values() if v is None)

print(f"\nResults:")
print(f"  SMILES retrieved from PubChem:  {retrieved}")
print(f"  Not found in PubChem:           {not_found}")
print(f"  Total nodes with SMILES:        {total_with_smiles} / {len(node_table)}")

# ─── 7. SAVE ──────────────────────────────────────────────────────────────────

node_table.to_csv(OUTPUT_TSV, sep="\t", index=False)
print(f"\nSaved → {OUTPUT_TSV}")