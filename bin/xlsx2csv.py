"""Pasa un .xlsx a CSV, una hoja por archivo, para que Claude pueda leerlo."""
import sys, csv, os, openpyxl
src, out = sys.argv[1], sys.argv[2]
wb = openpyxl.load_workbook(src, read_only=True, data_only=True)
base = os.path.splitext(os.path.basename(src))[0]
for ws in wb.worksheets:
    with open(os.path.join(out, f"{base} - {ws.title}.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        for row in ws.iter_rows(values_only=True):
            w.writerow(["" if v is None else v for v in row])
