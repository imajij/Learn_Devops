# Prints one line per Bandit finding. Quoted values (e.g. suspected passwords) are redacted.
.results[]
| "  \(.test_id) severity=\(.issue_severity) confidence=\(.issue_confidence) \(.filename):\(.line_number)  "
  + (.issue_text | gsub("'[^']{8,}'"; "<redacted>"))
