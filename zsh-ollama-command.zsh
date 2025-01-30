#!/bin/zsh

# Default hotkey: Ctrl+O
(( ! ${+ZSH_OLLAMA_COMMANDS_HOTKEY} )) && typeset -g ZSH_OLLAMA_COMMANDS_HOTKEY='^o'
# Default Ollama model
(( ! ${+ZSH_OLLAMA_MODEL} )) && typeset -g ZSH_OLLAMA_MODEL='llama3'
# Default number of command suggestions
(( ! ${+ZSH_OLLAMA_COMMANDS} )) && typeset -g ZSH_OLLAMA_COMMANDS='5'
# Default Ollama server URL
(( ! ${+ZSH_OLLAMA_URL} )) && typeset -g ZSH_OLLAMA_URL='http://localhost:11434'

validate_required() {
  # Check if required tools are installed
  for cmd in jq fzf curl; do
    if ! command -v $cmd &>/dev/null; then
      echo "🚨 zsh-ollama-command failed: '$cmd' is not installed!"
      echo "Please install it with: brew install $cmd"
      return 1
    fi
  done

  # Check if Ollama server is running
  if ! pgrep -f ollama &>/dev/null; then
    echo "🚨 Ollama server is NOT running!"
    echo "Start it with: brew services start ollama"
    return 1
  fi

  # Check if the specified model is available
  if ! curl -s "${ZSH_OLLAMA_URL}/api/tags" | grep -q "$ZSH_OLLAMA_MODEL"; then
    echo "🚨 Model '$ZSH_OLLAMA_MODEL' not found on Ollama server!"
    echo "Try: ollama pull $ZSH_OLLAMA_MODEL"
    return 1
  fi
}

fzf_ollama_commands() {
  setopt extendedglob
  validate_required || return 1

  ZSH_OLLAMA_COMMANDS_USER_QUERY=$BUFFER
  zle end-of-line
  zle reset-prompt
  print
  print -u1 "👻 Please wait..."

  ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT="Seeking ZSH terminal commands for MacOS 15.2 for the following task: $ZSH_OLLAMA_COMMANDS_USER_QUERY. Reply with possible commands, each on its own line. Response only contains raw commands to execute, no any additional description. No additional text should be present. If the task need more than one command then chain or pipe them. Provide AT MOST $ZSH_OLLAMA_COMMANDS command suggestions."

  ZSH_OLLAMA_COMMANDS_REQUEST_BODY=$(cat <<EOF
{
  "model": "$ZSH_OLLAMA_MODEL",
  "messages": [
    {
      "role": "user",
      "content": "$ZSH_OLLAMA_COMMANDS_MESSAGE_CONTENT"
    }
  ],
  "stream": false
}
EOF
  )

  ZSH_OLLAMA_COMMANDS_RESPONSE=$(curl --silent --fail "${ZSH_OLLAMA_URL}/api/chat" \
    -H "Content-Type: application/json" \
    -d "$ZSH_OLLAMA_COMMANDS_REQUEST_BODY")

  # If curl failed, display the raw response
  if [[ $? -ne 0 || -z "$ZSH_OLLAMA_COMMANDS_RESPONSE" ]]; then
    echo "🚨 API request failed. Showing raw response:"
    echo "$ZSH_OLLAMA_COMMANDS_RESPONSE"
    return 1
  fi

  # Extracting commands using patterns
  COMMANDS=$(echo "$ZSH_OLLAMA_COMMANDS_RESPONSE" | sed -E 's/```[a-z]+//g' | sed -E 's/```//g' | sed 's/^\s*//g' | grep -E '^\w+ .+')

  # If no valid commands were extracted, show raw response
  if [[ -z "$COMMANDS" ]]; then
    echo "🚨 No valid commands found. Raw response:"
    echo "$ZSH_OLLAMA_COMMANDS_RESPONSE"
    return 1
  fi

  # Remove duplicate empty lines or non-command lines
  COMMANDS=$(echo "$COMMANDS" | awk 'NF')

  # Display selection menu with fzf
  ZSH_OLLAMA_COMMANDS_SELECTED=$(echo "$COMMANDS" | fzf --prompt="Select a command: ")

  if [[ -n "$ZSH_OLLAMA_COMMANDS_SELECTED" ]]; then
    BUFFER=$ZSH_OLLAMA_COMMANDS_SELECTED
    zle end-of-line
    zle reset-prompt
  fi
}

validate_required

autoload fzf_ollama_commands
zle -N fzf_ollama_commands
bindkey $ZSH_OLLAMA_COMMANDS_HOTKEY fzf_ollama_commands
