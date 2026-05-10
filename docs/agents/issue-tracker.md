# Issue tracker: Linear

Issues and PRDs for this repo live in Linear. Use `linear-cli` for all operations.

This machine has the `linear` binary available; `npx @schpet/linear-cli ...` is also acceptable when the binary is not installed.

## Conventions

- **Create an issue**: write the description to a temp file, then run `linear issue create --title "Title" --description-file <temp-file>`.
- **Read an issue**: `linear issue view <issue-id> --json`.
- **List issues**: `linear issue query --json` with appropriate filters such as `--label`, `--state`, `--project`, or `--search`.
- **Comment on an issue**: write the comment to a temp file, then run `linear issue comment add <issue-id> --body-file <temp-file>`.
- **Apply labels**: `linear issue update <issue-id> --label "label-name"`. Repeat `--label` for multiple labels.
- **Update status**: `linear issue update <issue-id> --state "In Progress"` or the appropriate Linear state.
- **Assign to self**: `linear issue update <issue-id> --assignee self`.
- **Link a PR**: `linear issue link <issue-id> <pr-url>`.

## Language

Linear uses Chinese as its working language for this repo. Write issue titles, descriptions, and comments in Chinese.

## Issue references

When referencing another Linear issue, paste the full URL:

`https://linear.app/{workspace}/issue/L-1567`

Prefer full URLs over bare issue IDs so Linear renders reliable reference cards.

## When a skill says "publish to the issue tracker"

Create a Linear issue.

## When a skill says "fetch the relevant ticket"

Run `linear issue view <issue-id> --json`.
