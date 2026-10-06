#!/bin/bash
# Simple display mode toggle for Parsec vs normal Retina
# Usage: ssdisplay parsec | ssdisplay normal | ssdisplay (status)

DISPLAY_ID="37D8832A-2D66-02CA-B9F7-8F30A301B230"

need_dp() {
  if ! command -v displayplacer >/dev/null 2>&1; then
    echo "❌ displayplacer is not installed. Install with:  brew install displayplacer"
    exit 1
  fi
}

print_status() {
  need_dp
  # pull FIRST block's fields (built-in display for your case)
  local id res scaling
  id=$(displayplacer list | awk '/^Persistent screen id:/ {print $4; exit}')
  res=$(displayplacer list | awk '/^Resolution:/ {print $2; exit}')
  scaling=$(displayplacer list | awk '/^Scaling:/ {print $2; exit}')
  # fallback if parsing failed
  : "${id:=unknown}"
  : "${res:=unknown}"
  : "${scaling:=unknown}"

  echo "──────────────────────────────"
  echo "Current Display Status:"
  echo "  ID: $id"
  echo "  Resolution: $res"
  echo "  Scaling: $scaling"
  echo "──────────────────────────────"
  echo "Available Presets:"
  echo "  • parsec : 1920×1200  (non-HiDPI, true pixel, good for Parsec)"
  echo "  • normal : 1470×956   (Retina, crisp local view)"
  echo "──────────────────────────────"
}

to_parsec() {
  need_dp
  echo "🔧  Switching to Parsec-friendly 1920×1200 non-HiDPI mode..."
  displayplacer "id:$DISPLAY_ID res:1920x1200 hz:60 color_depth:8 scaling:off"
  print_status
}

to_normal() {
  need_dp
  echo "🎨  Restoring Retina 1470×956 mode..."
  displayplacer "id:$DISPLAY_ID res:1470x956 hz:60 color_depth:8 scaling:on"
  print_status
}

case "$1" in
  parsec) to_parsec ;;
  normal) to_normal ;;
  ""|status) print_status ;;
  *) echo "Usage: ssdisplay {parsec|normal}"; print_status; exit 1 ;;
esac
