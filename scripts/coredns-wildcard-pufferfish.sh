#!/usr/bin/env bash
# Purpose: Fix cert-manager HTTP-01 self-check without touching router by adding
#          a CoreDNS split-DNS rule that resolves *.pufferfish.ru to the
#          ingress controller Service ClusterIP from inside the cluster.
#
# Usage:
#   chmod +x scripts/coredns-wildcard-pufferfish.sh
#   scripts/coredns-wildcard-pufferfish.sh
#
# Env overrides (optional):
#   BASE_DOMAIN=pufferfish.ru
#   INGRESS_NS=ingress-nginx
#   INGRESS_SVC=ingress-nginx-controller
#
# What it does:
# 1) Detect ingress controller Service ClusterIP
# 2) Patch kube-system/coredns ConfigMap Corefile to add a `template` block
# 3) Restart CoreDNS
# 4) Show quick tests and next steps to re-issue certs

set -euo pipefail

BASE_DOMAIN=${BASE_DOMAIN:-pufferfish.ru}
INGRESS_NS=${INGRESS_NS:-ingress-nginx}
INGRESS_SVC=${INGRESS_SVC:-ingress-nginx-controller}

echo "[i] Detecting ingress Service ClusterIP (${INGRESS_NS}/${INGRESS_SVC})..."
INGRESS_CLUSTER_IP=$(kubectl -n "$INGRESS_NS" get svc "$INGRESS_SVC" -o jsonpath='{.spec.clusterIP}')
if [[ -z "${INGRESS_CLUSTER_IP}" ]]; then
  echo "[!] Could not detect ingress ClusterIP. Is ingress-nginx installed?" >&2
  exit 1
fi
echo "[i] Ingress ClusterIP = ${INGRESS_CLUSTER_IP}"

echo "[i] Fetching current CoreDNS Corefile..."
TMP_DIR=$(mktemp -d)
CORE_ORIG="${TMP_DIR}/Corefile.orig"
CORE_NEW="${TMP_DIR}/Corefile.new"

kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' >"${CORE_ORIG}" || {
  echo "[!] Failed to read kube-system/coredns ConfigMap" >&2
  exit 1
}

if grep -q "template IN A" "${CORE_ORIG}" && grep -q "${BASE_DOMAIN}" "${CORE_ORIG}"; then
  echo "[i] CoreDNS template for ${BASE_DOMAIN} already present; refreshing with detected IP..."
  # Replace only the IP inside existing answer lines for our domain block
  sed -E "s/(answer \"\{\{ \\.Name \}\} 60 IN A )([0-9.]+)(\")/\1${INGRESS_CLUSTER_IP}\3/" "${CORE_ORIG}" >"${CORE_NEW}"
else
  echo "[i] Inserting split-DNS template block before 'forward . ...' in Corefile..."
  TEMPL=$(cat <<'EOF'
    # Split-DNS: resolve *.BASE_DOMAIN to ingress ClusterIP (in-cluster only)
    template IN A {
        match ^([a-z0-9-]+\.)*BASE_DOMAIN\.$
        answer "{{ .Name }} 60 IN A INGRESS_IP"
    }
EOF
)
  TEMPL=${TEMPL//BASE_DOMAIN/${BASE_DOMAIN//./\\.}}
  TEMPL=${TEMPL//INGRESS_IP/${INGRESS_CLUSTER_IP}}

  awk -v block="$TEMPL" '
    inserted==0 && $0 ~ /^\s*forward\s+\.\s+/ { print block; inserted=1 }
    { print }
    END { if (inserted==0) {
            print block > "/dev/stderr";
            exit 0;
          } }
  ' "${CORE_ORIG}" >"${CORE_NEW}"
fi

echo "[i] Applying updated Corefile back to coredns ConfigMap..."
kubectl -n kube-system create configmap coredns --from-file=Corefile="${CORE_NEW}" \
  -o yaml --dry-run=client | kubectl -n kube-system apply -f -

echo "[i] Restarting CoreDNS to pick up changes..."
kubectl -n kube-system rollout restart deploy/coredns
kubectl -n kube-system rollout status deploy/coredns -w

echo "[✓] CoreDNS split-DNS in place. Quick smoke tests (should show ${INGRESS_CLUSTER_IP}):"
set +e
kubectl -n minio run -it --rm dns-smoke --restart=Never --image=busybox:1.36 -- \
  sh -c "nslookup backminio.${BASE_DOMAIN} || true; nslookup consoleminio.${BASE_DOMAIN} || true"
set -e

cat <<EONEXT

Next steps to re-issue MinIO certs (run once):

  # 1) Clean stale ACME orders/challenges (minio ns)
  kubectl -n minio delete challenges.acme.cert-manager.io --all || true
  kubectl -n minio delete orders.acme.cert-manager.io --all || true
  kubectl -n minio delete secret minio-tls minio-console-tls || true

  # 2) Re-run the MinIO deploy workflow (or Helm upgrade locally)
  #    Helm example (if running by hand):
  #  helm upgrade --install minio minio/minio \
  #    -n minio --create-namespace \
  #    -f k8s/minio/values-prod.yaml \
  #    --set auth.rootUser="$MINIO_ROOT_USER" \
  #    --set auth.rootPassword="$MINIO_ROOT_PASSWORD"

  # 3) Watch certs become Ready
  kubectl -n minio get certificate -w

EONEXT

echo "[Done]"

