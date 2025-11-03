#!/bin/bash
#
# Automated deployment script for the 'relay' application on Minikube.

# --- PATH RESOLUTION (Crucial for finding files from any directory) ---
# Get the directory where the script is located (even if called from elsewhere)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Assuming the project structure is:
# /project-root
#   /k8s (where this script is)
#   /sql (where init.sql is)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
K8S_DIR="$SCRIPT_DIR"
SQL_DIR="$PROJECT_ROOT/sql"
# --------------------------------------------------------------------

# --- Configuration ---
NAMESPACE="relay"
INGRESS_HOST="relay.local"
# File order is crucial for dependencies (e.g., namespace must exist first)
K8S_FILES=(
    "00-namespace.yaml"
    "01-postgres-config.yaml"
    "02-postgres-secret.yaml"
    "03-postgres.yaml"
    "04-jwt-secret.yaml"
    "05-server.yaml"
    "06-authentication.yaml"
    "07-ingress.yaml"
    "08-hpa.yaml"
)
# ---------------------

# Custom logging function
log() {
    echo -e "\n\033[34m[INFO]\033[0m \033[1m$1\033[0m"
}

# Function to check if the last command succeeded
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "\n\033[31m[ERROR]\033[0m Failed at step: $1. Exiting." >&2
        exit 1
    fi
}

# Function to wait for the PostgreSQL server to accept connections
wait_for_db() {
    local max_attempts=30
    local attempt=0
    local sleep_time=5
    local pod_name=$1
    local namespace=$2
    
    log "Waiting for PostgreSQL server inside $pod_name to become fully available..."

    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        
        # Check connection using psql command (only checks the server's readiness)
        # It uses the same PGPASSWORD setup as the init script
        kubectl exec -n $namespace "$pod_name" -- bash -c "
            PGPASSWORD='$POSTGRES_PASSWORD' psql -U '$POSTGRES_USER' -d '$POSTGRES_DB' -c 'SELECT 1'
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log "PostgreSQL server is running and ready on attempt $attempt."
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts failed. Retrying in $sleep_time seconds..."
        sleep $sleep_time
    done

    echo -e "\n\033[31m[ERROR]\033[0m PostgreSQL server failed to become ready after $max_attempts attempts." >&2
    return 1
}

log "Starting Minikube Deployment for the '$NAMESPACE' application."
echo "Resolved K8s YAML directory: $K8S_DIR"
echo "Resolved SQL script directory: $SQL_DIR"

# --- 1. MINIKUBE SETUP ---
log "1. Starting Minikube cluster and enabling Docker driver..."
minikube start --driver=docker
check_error "Minikube start"

log "Enabling Minikube addons: ingress and metrics-server (required for HPA)..."
minikube addons enable ingress
minikube addons enable metrics-server
check_error "Minikube addons enable"

log "Waiting for the ingress-nginx controller to be ready (up to 2 minutes)..."
# Wait for the deployment to become ready in the 'ingress-nginx' namespace.
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s
check_error "Waiting for NGINX Ingress Controller Pod"

# --- Recommended: Ensure Minikube hostPath for PV exists ---
# This addresses the common issue with static hostPath PVs in Minikube.
log "Ensuring hostPath directory (/mnt/data) exists and is writable in Minikube VM for PostgreSQL PV..."
minikube ssh -- sudo mkdir -p /mnt/data
minikube ssh -- sudo chmod 777 /mnt/data
check_error "Minikube hostPath setup"


# --- 2. DEPLOY KUBERNETES RESOURCES ---
log "2. Applying Kubernetes manifests in sequence..."

for file in "${K8S_FILES[@]}"; do
    FILE_PATH="$K8S_DIR/$file" # <-- Using derived path
    if [ -f "$FILE_PATH" ]; then
        echo -e "   \033[32m-> Applying $file...\033[0m"
        kubectl apply -f "$FILE_PATH" # <-- Using derived path
        check_error "kubectl apply -f $file"
    else
        echo -e "\n\033[33m[WARNING]\033[0m Manifest file not found: $FILE_PATH. Skipping."
    fi
done

# --- 3. WAITING FOR READINESS ---
log "3. Waiting for key deployments to become Ready (up to 5 minutes)..."

# Wait for the PostgreSQL pod (postgresql-0) to be fully Ready
log "Waiting for PostgreSQL pod (postgresql-0) to be Ready..."
kubectl wait --namespace=$NAMESPACE --for=condition=Ready pod/postgresql-0 --timeout=300s
check_error "Waiting for PostgreSQL Pod/postgresql-0"

# --- 3.1 INITIALIZE DATABASE (FINAL REVISION WITH CUSTOM WAIT) ---
log "Initializing PostgreSQL database by streaming init.sql..."

# We still need the Pod name and credentials first
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgresql -o jsonpath="{.items[0].metadata.name}")
check_error "Getting PostgreSQL Pod name."

# 1. Get Credentials from Kubernetes Secrets/ConfigMap (must be done before wait_for_db)
POSTGRES_USER=$(kubectl get secret postgres-secret -n $NAMESPACE -o jsonpath='{.data.postgres-user}' | base64 --decode)
POSTGRES_PASS=$(kubectl get secret postgres-secret -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 --decode)
POSTGRES_DB=$(kubectl get configmap postgres-config -n $NAMESPACE -o jsonpath='{.data.postgres-db}')
check_error "Retrieving PostgreSQL credentials/DB name"

# 2. Wait for the PostgreSQL SERVER to be ready using the custom function
wait_for_db "$POSTGRES_POD" "$NAMESPACE"
check_error "PostgreSQL server readiness check"

INIT_SQL_PATH="$SQL_DIR/init.sql"
if [ ! -f "$INIT_SQL_PATH" ]; then
    echo -e "\n\033[31m[ERROR]\033[0m Database initialization file not found at: $INIT_SQL_PATH. Exiting." >&2
    exit 1
fi

# 3. Execute script by streaming the local file contents directly into 'psql'
log "Streaming local '$INIT_SQL_PATH' into $POSTGRES_POD..."

# The magic: The entire output of 'cat $INIT_SQL_PATH' is piped to the STDIN of the 'psql' command
cat "$INIT_SQL_PATH" | kubectl exec -i -n $NAMESPACE "$POSTGRES_POD" -- bash -c "
    PGPASSWORD='$POSTGRES_PASS' psql -U '$POSTGRES_USER' -d '$POSTGRES_DB'
"
check_error "Running database initialization script"
log "Database initialized successfully."

# Wait for the application servers
kubectl wait --namespace=$NAMESPACE --for=condition=Available deployment/app-server --timeout=300s
check_error "Waiting for App Server deployment"

kubectl wait --namespace=$NAMESPACE --for=condition=Available deployment/auth-server --timeout=300s
check_error "Waiting for Auth Server deployment"

log "Core application components are deployed and ready!"

# --- 4. ACCESS INSTRUCTIONS (Revised with Windows Path) ---
log "4. Minikube Access Configuration and Hosts File Update"

MINIKUBE_IP=$(minikube ip)
LOOPBACK_IP="127.0.0.1" # Standard loopback address for minikube tunnel
echo "Minikube IP detected: $MINIKUBE_IP"
echo ""

# 4.1 Hosts File Update (Crucial Step)
echo -e "------------------------------------------------------------------------------------------------------"
echo -e "\033[33mACTION REQUIRED: Update Host file\033[0m"
echo -e "To ensure Ingress works correctly, you \033[1mmust\033[0m map the IP address to \033[36m$INGRESS_HOST\033[0m."
echo ""
echo -e "The hosts file location is:"
echo -e " \033[36m- Linux/macOS: /etc/hosts\033[0m"
echo -e " \033[36m- Windows: C:\\Windows\\System32\\drivers\\etc\\hosts\033[0m"
echo ""

echo -e "CHOOSE YOUR ACCESS METHOD (and run the corresponding command with \033[1mAdministrator/root\033[0m privileges):"
echo ""

# 4.1a Method 1: Direct Minikube IP (No tunnel needed)
echo -e "\033[32m-> Method A: Using Minikube IP (if NOT running 'minikube tunnel')\033[0m"
echo -e "   - Required Entry: \033[35m$MINIKUBE_IP $INGRESS_HOST\033[0m"
echo -e "   - Linux/macOS Command: \033[35msudo sh -c 'echo \"$MINIKUBE_IP $INGRESS_HOST\" >> /etc/hosts'\033[0m"
echo -e "   - Windows (PowerShell as Admin): \033[35mAdd-Content -Path C:\\Windows\\System32\\drivers\\etc\\hosts -Value \"`n$MINIKUBE_IP $INGRESS_HOST\"\033[0m"
echo ""

# 4.1b Method 2: Loopback IP with Tunnel (Recommended for Minikube Ingress)
echo -e "\033[32m-> Method B: Using 127.0.0.1 (RECOMMENDED - requires 'minikube tunnel')\033[0m"
echo -e "   - Required Entry: \033[35m$LOOPBACK_IP $INGRESS_HOST\033[0m"
echo -e "   - Linux/macOS Command: \033[35msudo sh -c 'echo \"$LOOPBACK_IP $INGRESS_HOST\" >> /etc/hosts'\033[0m"
echo -e "   - Windows (PowerShell as Admin): \033[35mAdd-Content -Path C:\\Windows\\System32\\drivers\\etc\\hosts -Value \"`n$LOOPBACK_IP $INGRESS_HOST\"\033[0m"
echo -e "------------------------------------------------------------------------------------------------------"
echo ""


# 4.2 Minikube Tunnel Reminder
log "4.2 Minikube Tunnel (If using Method B)"
echo "If you chose Method B (127.0.0.1), you must run 'minikube tunnel' in a separate, elevated terminal:"
echo -e "   \033[32mminikube tunnel\033[0m"
echo ""

echo "After completing the Hosts file update AND ensuring 'minikube tunnel' is running (if using Method B), access your endpoints via:"
echo "  - API: http://$INGRESS_HOST/api/your-route"
echo "  - Auth: http://$INGRESS_HOST/auth/your-route"
echo "------------------------------------------------------------------------------------------------------"


# --- 5. USEFUL COMMANDS (Load Generator Clarification) ---
log "5. Useful Commands for Verification"
echo -e "- Check overall status:              \033[32mkubectl get all -n $NAMESPACE\033[0m"
echo -e "- Watch pods initialize:             \033[32mkubectl get pods -n $NAMESPACE -w\033[0m"
echo -e "- Check Horizontal Pod Autoscalers:  \033[32mkubectl get hpa -n $NAMESPACE\033[0m"
echo -e "- View HPA pods:                     \033[32mkubectl kubectl get hpa app-server-hpa -n relay -w\033[0m"
echo -e "- Port Database to localhost         \033[32mkubectl kubectl port-forward -n relay svc/postgresql-service 5432:5432\033[0m"
echo ""
echo -e "- Enable/Start Load Generator:       \033[32mkubectl apply -f $K8S_DIR/09-load-generator.yaml\033[0m"
echo -e "- Stop/Remove Load Generator:        \033[32mkubectl delete -f $K8S_DIR/09-load-generator.yaml\033[0m (This removes the deployment and stops the traffic.)"
echo ""
echo -e "- Cleanup All Resources:             \033[32mkubectl delete all,pvc,pv,configmaps,secrets,ingress,hpa --namespace=$NAMESPACE --all\033[0m"
echo "--- Deployment Finished ---"