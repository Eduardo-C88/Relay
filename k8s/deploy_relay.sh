#!/bin/bash
#
# Automated deployment script for the 'relay' application on Minikube.

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

log "Starting Minikube Deployment for the '$NAMESPACE' application."

# --- 1. MINIKUBE SETUP ---
log "1. Starting Minikube cluster and enabling Docker driver..."
minikube start --driver=docker
check_error "Minikube start"

log "Enabling Minikube addons: ingress and metrics-server (required for HPA)..."
minikube addons enable ingress
minikube addons enable metrics-server
check_error "Minikube addons enable"

# --- 2. DEPLOY KUBERNETES RESOURCES ---
log "2. Applying Kubernetes manifests in sequence..."

for file in "${K8S_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "   \033[32m-> Applying $file...\033[0m"
        kubectl apply -f "$file"
        check_error "kubectl apply -f $file"
    else
        echo -e "\n\033[33m[WARNING]\033[0m Manifest file not found: $file. Skipping."
    fi
done

# --- 3. WAITING FOR READINESS ---
log "3. Waiting for key deployments to become Ready (up to 5 minutes)..."
# Wait for the database
kubectl wait --namespace=$NAMESPACE --for=condition=Ready statefulset/postgresql --timeout=300s
check_error "Waiting for PostgreSQL StatefulSet"

# --- 3.1 INITIALIZE DATABASE ---
log "Initializing PostgreSQL database with init.sql..."

POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgresql -o jsonpath="{.items[0].metadata.name}")

kubectl cp sql/init.sql $NAMESPACE/$POSTGRES_POD:/tmp/init.sql

kubectl exec -n $NAMESPACE $POSTGRES_POD -- bash -c "
    PGPASSWORD=$(kubectl get secret postgres-secret -n $NAMESPACE -o jsonpath='{.data.postgres-password}' | base64 --decode) \
    psql -U $(kubectl get secret postgres-secret -n $NAMESPACE -o jsonpath='{.data.postgres-user}' | base64 --decode) \
        -d $(kubectl get configmap postgres-config -n $NAMESPACE -o jsonpath='{.data.postgres-db}') \
        -f /tmp/init.sql
"
check_error "Running database initialization script"
log "Database initialized successfully."

# Wait for the application servers
kubectl wait --namespace=$NAMESPACE --for=condition=Available deployment/app-server --timeout=300s
check_error "Waiting for App Server deployment"

kubectl wait --namespace=$NAMESPACE --for=condition=Available deployment/auth-server --timeout=300s
check_error "Waiting for Auth Server deployment"

log "Core application components are deployed and ready!"

# --- 4. ACCESS INSTRUCTIONS (Improved with Hosts & Tunnel Info) ---
log "4. Minikube Access Configuration and Hosts File Update"

MINIKUBE_IP=$(minikube ip)
echo "Minikube IP detected: $MINIKUBE_IP"
echo ""

# 4.1 Hosts File Update (Primary Method)
echo -e "------------------------------------------------------------------------------------------------------"
echo -e "\033[33mACTION REQUIRED: Update Host file (Method 1: Minikube IP)\033[0m"
echo -e "To ensure Ingress works correctly, you must map the Minikube IP to \033[36m$INGRESS_HOST\033[0m."
echo -e "Run the following command (requires sudo) to append the entry to /etc/hosts:"
echo -e "------------------------------------------------------------------------------------------------------"
echo -e "  \033[35msudo sh -c 'echo \"$MINIKUBE_IP $INGRESS_HOST\" >> /etc/hosts'\033[0m"
echo -e "------------------------------------------------------------------------------------------------------"
echo ""

# 4.2 Minikube Tunnel (Alternative Method)
log "4.2 Alternative Access (Method 2: minikube tunnel)"
echo "If updating /etc/hosts is challenging, you can use 'minikube tunnel' in a separate terminal."
echo "This requires elevated permissions and keeps running, but it ensures external access to your Ingress:"
echo -e "   \033[32mminikube tunnel\033[0m"
echo ""
echo "After using either method, access your endpoints via:"
echo "  - API: http://$INGRESS_HOST/api/your-route"
echo "  - Auth: http://$INGRESS_HOST/auth/your-route"
echo "------------------------------------------------------------------------------------------------------"


# --- 5. USEFUL COMMANDS (Load Generator Clarification) ---
log "5. Useful Commands for Verification"
echo "- Check overall status:              \033[32mkubectl get all -n $NAMESPACE\033[0m"
echo "- Watch pods initialize:             \033[32mkubectl get pods -n $NAMESPACE -w\033[0m"
echo "- Check Horizontal Pod Autoscalers:  \033[32mkubectl get hpa -n $NAMESPACE\033[0m"
echo "- View HPA pods:                     \033[32mkubectl kubectl get hpa app-server-hpa -n relay -w\033[0m"
echo "- Port Database to localhost         \033[32mkubectl kubectl port-forward -n relay svc/postgresql-service 5432:5432\033[0m"
echo ""
echo "- Enable/Start Load Generator:       \033[32mkubectl apply -f 09-load-generator.yaml\033[0m"
echo "- Stop/Remove Load Generator:        \033[32mkubectl delete -f 09-load-generator.yaml\033[0m (This removes the deployment and stops the traffic.)"
echo ""
echo "- Cleanup All Resources:             \033[32mkubectl delete all,pvc,pv,configmaps,secrets,ingress,hpa --namespace=$NAMESPACE --all\033[0m"
echo "--- Deployment Finished ---"
