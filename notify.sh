#!/bin/bash
# Claude Code Notification Hook
# Reads stdin JSON from Notification/Stop events and sends dynamic macOS notification
# Suppresses notification when the active terminal tab is running Claude Code
# Supports custom messages via config file

CONFIG="$HOME/.claude/hooks/claude-code-notifier/notify.conf"
INPUT=$(cat)

# Check if terminal is in focus — if so, check whether the active tab is the Claude session
ACTIVE_APP=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
case "$ACTIVE_APP" in
  iTerm2)
    VISIBLE_TTY=$(osascript -e 'tell application "iTerm2"
      tell current session of current tab of current window
        get its tty
      end tell
    end tell' 2>/dev/null)
    if [ -n "$VISIBLE_TTY" ]; then
      CLAUDE_PID=$(ps -ax -o pid,comm 2>/dev/null | grep -w claude | head -1 | awk '{print $1}')
      if [ -n "$CLAUDE_PID" ]; then
        CUR_PID=$CLAUDE_PID
        while [ -n "$CUR_PID" ] && [ "$CUR_PID" != "0" ] && [ "$CUR_PID" != "1" ]; do
          CUR_TTY=$(ps -o tty= -p "$CUR_PID" 2>/dev/null | tr -d ' ')
          if [ "/dev/$CUR_TTY" = "$VISIBLE_TTY" ]; then
            exit 0
          fi
          CUR_PID=$(ps -o ppid= -p "$CUR_PID" 2>/dev/null | tr -d ' ')
        done
      fi
    fi
    ;;
  Terminal|WezTerm|Alacritty|kitty|tmux)
    exit 0
    ;;
esac

# Default messages (English)
L_PERMISSION="Waiting for your approval"
L_IDLE="Waiting for your response"
L_AUTH="Authentication successful"
L_ELICITATION="Waiting for your selection"
L_STOP="Task completed"
L_DEFAULT="Needs your attention"
NOTIFY_SOUND="Glass"

# Load user config (overrides defaults above)
if [ -f "$CONFIG" ]; then
  source "$CONFIG"
fi

# Parse stdin JSON
HOOK_EVENT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook_event_name','unknown').lower())" 2>/dev/null)
TYPE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('notification_type','unknown').lower())" 2>/dev/null)
MESSAGE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))" 2>/dev/null)

# Determine notification message
# Priority: L_* from notify.conf > message from stdin JSON > L_DEFAULT
if [ "$HOOK_EVENT" = "stop" ]; then
  MSG="$L_STOP"
else
  case "$TYPE" in
    permission_prompt)  MSG="$L_PERMISSION" ;;
    idle_prompt)        MSG="$L_IDLE" ;;
    auth_success)       MSG="$L_AUTH" ;;
    elicitation_dialog) MSG="$L_ELICITATION" ;;
    *)
      if [ -n "$MESSAGE" ]; then
        MSG="$MESSAGE"
      else
        MSG="$L_DEFAULT"
      fi
      ;;
  esac
fi

"$HOME/.claude/hooks/claude-code-notifier/Claude Code.app/Contents/MacOS/Claude Code" "Claude Code" "$MSG" "$NOTIFY_SOUND"
