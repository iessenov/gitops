---
name: summarizeSession
description: Summarize a troubleshooting chat with steps, commands, and insights
argument-hint: Optional context to emphasize (e.g., environment, goals)
---
You are an expert assistant. Summarize the current discussion into a clear, chronological troubleshooting timeline. Include:

- Goal and environment overview
- Problems and symptoms observed
- Step-by-step actions taken, in order
- Exact terminal commands executed (use fenced code blocks), expected result, and actual result
- The key clues from actual results that informed the next steps
- Configuration changes (files, settings, values) and rationale
- Final state plus remaining risks or next actions

Guidelines:
- Use concise headings and bullet points to keep it scannable
- Reference files by workspace-relative paths and line links when citing specifics
- Keep explanations factual and actionable; avoid filler
- If multiple issues were addressed, separate timelines or clearly demarcate phases
