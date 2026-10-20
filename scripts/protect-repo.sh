#!/usr/bin/env bash
# Applies Mullion's GitHub repository settings and protections with the GitHub CLI.
# Safe to run again: every step overwrites the setting, and rulesets are updated by name.
#
#   brew install gh jq && gh auth login
#   scripts/protect-repo.sh                 # defaults to iamAdarshh/Mullion
#   scripts/protect-repo.sh owner/repo
#
# Needs admin rights on the repo. A step that fails prints a warning and the script carries on,
# so check the summary at the end.
set -uo pipefail

REPO="${1:-iamAdarshh/Mullion}"
REQUIRED_CHECK="build-and-test"   # job id in .github/workflows/ci.yml
failures=()

command -v gh >/dev/null || { echo "gh not found: brew install gh"; exit 1; }
command -v jq >/dev/null || { echo "jq not found: brew install jq"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not logged in: gh auth login"; exit 1; }

step() { printf '\n▸ %s\n' "$1"; }
ok() { echo "  ✓ done"; }
fail() { echo "  ✗ $1"; failures+=("$1"); }

# api METHOD PATH [JSON]: calls the REST API, with JSON on stdin when given.
api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | gh api --method "$method" "$path" --input - >/dev/null
  else
    gh api --method "$method" "$path" >/dev/null
  fi
}

# ── 1. Repository settings ────────────────────────────────────────────────────────────────
step "About box: description, website and topics"
gh repo edit "$REPO" \
  --description "Free, open-source window manager for macOS. Snap windows into halves, thirds, quarters and sixths with the keyboard or by dragging to a screen edge. Native Swift menu bar app, public APIs only, no telemetry. Zones and workspaces coming next." \
  --homepage "https://github.com/$REPO/releases" \
  --add-topic macos,window-manager,swift,appkit,menubar-app,window-snapping,tiling,productivity,accessibility-api,magnet-alternative,fancyzones \
  >/dev/null && ok || fail "About box"

step "Repository settings: squash merges only, delete merged branches, Discussions on, wiki off"
api PATCH "repos/$REPO" '{
  "has_wiki": false,
  "has_discussions": true,
  "allow_squash_merge": true,
  "allow_merge_commit": false,
  "allow_rebase_merge": false,
  "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY",
  "delete_branch_on_merge": true,
  "allow_update_branch": true
}' && ok || fail "repository settings"

# ── 2. Security features (free for public repos) ──────────────────────────────────────────
step "Secret scanning and push protection"
api PATCH "repos/$REPO" '{
  "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}' && ok || fail "secret scanning"

step "Dependabot alerts"
api PUT "repos/$REPO/vulnerability-alerts" && ok || fail "Dependabot alerts"

step "Dependabot security updates"
api PUT "repos/$REPO/automated-security-fixes" && ok || fail "Dependabot security updates"

step "Private vulnerability reporting (SECURITY.md points here)"
api PUT "repos/$REPO/private-vulnerability-reporting" && ok || fail "private vulnerability reporting"

step "CodeQL code scanning, default setup (Swift runs on macOS runners)"
api PATCH "repos/$REPO/code-scanning/default-setup" '{ "state": "configured", "query_suite": "default" }' \
  && ok || fail "CodeQL default setup (turn it on in Settings → Advanced Security if this keeps failing)"

# ── 3. GitHub Actions ─────────────────────────────────────────────────────────────────────
step "Actions: only GitHub-owned actions may run"
api PUT "repos/$REPO/actions/permissions" '{ "enabled": true, "allowed_actions": "selected" }' \
  && api PUT "repos/$REPO/actions/permissions/selected-actions" \
       '{ "github_owned_allowed": true, "verified_allowed": false, "patterns_allowed": [] }' \
  && ok || fail "allowed actions"

step "Actions: read-only token by default, can't approve PRs"
api PUT "repos/$REPO/actions/permissions/workflow" \
  '{ "default_workflow_permissions": "read", "can_approve_pull_request_reviews": false }' \
  && ok || fail "default workflow permissions"

step "Actions: fork PRs from any outside contributor need your approval to run"
api PUT "repos/$REPO/actions/permissions/fork-pr-contributor-approval" \
  '{ "approval_policy": "all_external_contributors" }' \
  && ok || fail "fork PR approval (set it in Settings → Actions → General if this fails)"

# ── 4. Release environment ────────────────────────────────────────────────────────────────
step "Environment 'release': you approve every run, and only v* tags can deploy"
my_id="$(gh api user --jq .id)"
api PUT "repos/$REPO/environments/release" "{
  \"reviewers\": [{ \"type\": \"User\", \"id\": $my_id }],
  \"prevent_self_review\": false,
  \"deployment_branch_policy\": { \"protected_branches\": false, \"custom_branch_policies\": true }
}" || fail "release environment"
existing_policy="$(gh api "repos/$REPO/environments/release/deployment-branch-policies" \
  --jq '.branch_policies[] | select(.name == "v*" and .type == "tag") | .id' 2>/dev/null)"
if [ -z "$existing_policy" ]; then
  api POST "repos/$REPO/environments/release/deployment-branch-policies" '{ "name": "v*", "type": "tag" }' \
    && ok || fail "release environment tag policy"
else
  ok
fi

# ── 5. Rulesets ───────────────────────────────────────────────────────────────────────────
# upsert_ruleset NAME JSON: creates the ruleset, or replaces the one with the same name.
upsert_ruleset() {
  local name="$1" body="$2" id
  id="$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>/dev/null | head -1)"
  if [ -n "$id" ]; then
    api PUT "repos/$REPO/rulesets/$id" "$body"
  else
    api POST "repos/$REPO/rulesets" "$body"
  fi
}

step "Ruleset 'Protect main': PRs only, CI must pass, no force pushes or deletion"
upsert_ruleset "Protect main" "{
  \"name\": \"Protect main\",
  \"target\": \"branch\",
  \"enforcement\": \"active\",
  \"conditions\": { \"ref_name\": { \"include\": [\"~DEFAULT_BRANCH\"], \"exclude\": [] } },
  \"bypass_actors\": [],
  \"rules\": [
    { \"type\": \"deletion\" },
    { \"type\": \"non_fast_forward\" },
    { \"type\": \"required_linear_history\" },
    { \"type\": \"pull_request\", \"parameters\": {
        \"required_approving_review_count\": 0,
        \"dismiss_stale_reviews_on_push\": false,
        \"require_code_owner_review\": false,
        \"require_last_push_approval\": false,
        \"required_review_thread_resolution\": true,
        \"allowed_merge_methods\": [\"squash\"]
    } },
    { \"type\": \"required_status_checks\", \"parameters\": {
        \"strict_required_status_checks_policy\": true,
        \"required_status_checks\": [{ \"context\": \"$REQUIRED_CHECK\" }]
    } }
  ]
}" && ok || fail "ruleset Protect main"

# Repository role 5 is Admin: only you can create, move or delete release tags.
step "Ruleset 'Protect release tags': only admins create, move or delete v* tags"
upsert_ruleset "Protect release tags" '{
  "name": "Protect release tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } },
  "bypass_actors": [{ "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }],
  "rules": [ { "type": "creation" }, { "type": "update" }, { "type": "deletion" } ]
}' && ok || fail "ruleset Protect release tags"

# ── Summary ───────────────────────────────────────────────────────────────────────────────
echo
if [ ${#failures[@]} -eq 0 ]; then
  echo "All settings applied to $REPO."
else
  echo "Applied, except for ${#failures[@]} step(s) to set by hand in the repo's Settings:"
  printf '  - %s\n' "${failures[@]}"
fi
echo
echo "Rulesets on $REPO now (delete any duplicate you made by hand in Settings → Rules → Rulesets):"
gh api "repos/$REPO/rulesets" --jq '.[] | "  - \(.name) (\(.target), \(.enforcement))"' 2>/dev/null
echo
echo "Not scriptable, check yourself:"
echo "  - Your account: two-factor authentication (passkey or security key), SSH signing key"
echo "  - Settings → General → Social preview: upload a 1280×640 image"
