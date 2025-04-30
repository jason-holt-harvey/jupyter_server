#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
VENV_DIR="$PROJECT_DIR/venv"

# NEW: Parse CLI arguments for automation flags
AUTO_MODE=""
for arg in "$@"; do
  case $arg in
    --auto-all)
      AUTO_MODE="all"
      ;;
    --auto-none)
      AUTO_MODE="none"
      ;;
    --auto=*)
      AUTO_MODE="${arg#*=}"
      ;;
    --prompt)
      AUTO_MODE="prompt"
      ;;
  esac
done

install_optional() {
    local group=$1
    local req_file="$PROJECT_DIR/requirements-${group}.txt"
    echo "Installing optional group: $group"
    if [ -f "$req_file" ]; then
        pip install -r "$req_file"
    else
        echo "Warning: $req_file not found, skipping."
    fi
}


setup_environment() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
    else
        echo "Virtual environment already exists at $VENV_DIR"
    fi

    source "$VENV_DIR/bin/activate"


    echo "Installing core requirements (base)..."
    pip install --upgrade pip
    pip install -r "$PROJECT_DIR/requirements-base.txt"

    echo "🧩 Optional installs mode: $AUTO_MODE"


    if [[ $AUTO_MODE == "all" ]]; then
        install_optional "gpu"
        install_optional "rag"
        install_optional "agents"
        install_optional "llm-training"

    elif [[ $AUTO_MODE == "none" ]]; then
        echo "Skipping all optional installs."

    elif [[ $AUTO_MODE == "prompt" || -z $AUTO_MODE ]]; then
        read -p "Install GPU libraries (yes/no): " install_gpu
        [[ "$install_gpu" == "yes" ]] && install_optional "gpu"

        read -p "Install RAG libraries (yes/no): " install_rag
        [[ "$install_rag" == "yes" ]] && install_optional "rag"

        read -p "Install Agentic Workflow libraries (yes/no): " install_agents
        [[ "$install_agents" == "yes" ]] && install_optional "agents"

        read -p "Install LLM training specialist libraries (yes/no): " install_llm
        [[ "$install_llm" == "yes" ]] && install_optional "llm-training"

    else
        IFS=',' read -ra OPT_GROUPS <<< "$AUTO_MODE"
        for group in "${OPT_GROUPS[@]}"; do
            install_optional "$group"
        done
    fi
}
# Main entry point
case "$1" in
    setup)
        setup_environment "$@"
        ;;
    *)
        echo "Usage: $0 setup [--auto-all|--auto-none|--auto=gpu,rag|--prompt]"

        exit 1
        ;;
esac