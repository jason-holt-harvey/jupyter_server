#!/bin/bash
set -e

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
VENV_DIR="$PROJECT_DIR/venv"
PID_FILE="$PROJECT_DIR/jupyter_server.pid"
LOG_FILE="$PROJECT_DIR/jupyter_server.log"

# Parse CLI arguments for automation flags
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

# Function to install optional dependency groups
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

# Setup Environment
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

# Start Jupyter Server
start_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "Jupyter server already running (PID $PID)."
            exit 0
        else
            echo "Stale PID file found. Removing..."
            rm "$PID_FILE"
        fi
    fi

    echo "Starting Jupyter Notebook server..."
    source "$VENV_DIR/bin/activate"
    nohup jupyter notebook --no-browser > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "✅ Jupyter server started. PID $(cat "$PID_FILE")"
}

# Stop Jupyter Server
stop_server() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No PID file found. Server may not be running."
        exit 1
    fi

    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "Stopping Jupyter server (PID $PID)..."
        kill $PID
        rm "$PID_FILE"
        echo "✅ Server stopped."
    else
        echo "Process $PID not found. Removing stale PID file."
        rm "$PID_FILE"
    fi
}

# Status of Jupyter Server
status_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo "✅ Jupyter server is running (PID $PID)."
        else
            echo "⚠️ PID file exists but process $PID not running."
        fi
    else
        echo "❌ No running Jupyter server found."
    fi
}

# Restart Jupyter Server
restart_server() {
    stop_server
    start_server
}

# Main command router
case "$1" in
    setup)
        setup_environment "$@"
        ;;
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    status)
        status_server
        ;;
    restart)
        restart_server
        ;;
    *)
        echo "Usage: $0 {setup|start|stop|status|restart} [--auto-all|--auto-none|--auto=gpu,rag|--prompt]"
        exit 1
        ;;
esac
