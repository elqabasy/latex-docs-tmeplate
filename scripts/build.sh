#!/usr/bin/env bash
set -euo pipefail

SOURCE="${1:-}"
OUTDIR="${2:-dist}"
ENGINE="${3:-xelatex}" # pdflatex|xelatex|lualatex

mkdir -p "$OUTDIR"

abspath() {
  # macOS may not have `realpath`; `readlink -f` may not exist everywhere either.
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
    return
  fi
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$1" 2>/dev/null && return
  fi
  # Fallback: best-effort (relative paths will remain relative)
  echo "$1"
}

OUTDIR_ABS="$(abspath "$OUTDIR")"

sources=()
if [[ -n "$SOURCE" ]]; then
  if [[ ! -f "$SOURCE" ]]; then
    echo "Source file not found: $SOURCE" >&2
    exit 2
  fi
  sources+=("$SOURCE")
else
  # Default mode: build all *entrypoint* .tex files under src/ recursively.
  # We treat a file as an entrypoint when it contains \documentclass.
  while IFS= read -r -d '' file; do
    if grep -Eq '^[[:space:]]*\\documentclass' "$file"; then
      sources+=("$file")
    fi
  done < <(find src -type f -name '*.tex' -print0)

  if [[ ${#sources[@]} -eq 0 ]]; then
    echo "No entrypoint .tex files found under src/ (expected files containing \\documentclass)." >&2
    exit 2
  fi
fi

if command -v latexmk >/dev/null 2>&1; then
  for src in "${sources[@]}"; do
    src_dir="$(dirname "$src")"
    src_file="$(basename "$src")"
    case "$ENGINE" in
      pdflatex) (cd "$src_dir" && latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error -outdir="$OUTDIR_ABS" "$src_file") ;;
      xelatex)  (cd "$src_dir" && latexmk -xelatex -interaction=nonstopmode -halt-on-error -file-line-error -outdir="$OUTDIR_ABS" "$src_file") ;;
      lualatex) (cd "$src_dir" && latexmk -lualatex -interaction=nonstopmode -halt-on-error -file-line-error -outdir="$OUTDIR_ABS" "$src_file") ;;
      *)
        echo "Unknown engine: $ENGINE (expected pdflatex|xelatex|lualatex)" >&2
        exit 2
        ;;
    esac
    echo "Built $OUTDIR/$(basename "${src%.tex}.pdf")"
  done
else
  case "$ENGINE" in
    pdflatex) cmd=pdflatex ;;
    xelatex)  cmd=xelatex ;;
    lualatex) cmd=lualatex ;;
    *)
      echo "Unknown engine: $ENGINE (expected pdflatex|xelatex|lualatex)" >&2
      exit 2
      ;;
  esac

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd not found. Install TeX Live/MiKTeX or latexmk." >&2
    exit 127
  fi

  for src in "${sources[@]}"; do
    src_dir="$(dirname "$src")"
    src_file="$(basename "$src")"
    tmp="$OUTDIR_ABS/.latex"
    rm -rf "$tmp"
    mkdir -p "$tmp"

    for pass in 1 2; do
      (cd "$src_dir" && "$cmd" -interaction=nonstopmode -halt-on-error -file-line-error -output-directory="$tmp" "$src_file")
    done

    pdf="$(basename "${src%.tex}.pdf")"
    test -f "$tmp/$pdf"
    cp -f "$tmp/$pdf" "$OUTDIR/$pdf"
    rm -rf "$tmp"
    echo "Built $OUTDIR/$pdf"
  done
fi
