# Deploy

Infrastructure manifests and GitHub Actions for services (Ingress, MinIO, Telegram Forwarder).

## Prerequisites
- Kubernetes cluster (k3s/EKS/…) and `kubectl` available on the CI runner.
- NGINX Ingress Controller (class: `nginx`).
- cert-manager installed with a `ClusterIssuer` named `letsencrypt-http01`.
- DNS records pointing to your ingress controller for all domains in manifests.
- Image pull secret `ghcr-secret` in required namespaces (e.g., `app`):
  ```bash
  kubectl -n app create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=<github_user> \
    --docker-password=<personal_access_token> \
    --docker-email=-
  ```

## Repository Layout
- `k8s/ingress/hello-demo-ingress.yaml`: Ingress for `demo.pufferfish.ru`.
- `k8s/ingress/keycloak-ingress.yaml`: Ingress for `auth.pufferfish.ru`.
- `k8s/minio/values-prod.yaml`: Helm values for MinIO (prod).
- `k8s/telegram-forwarder/deploy.yaml`: Namespace, Deployment, Service, Ingress for Telegram Forwarder.
- `.github/workflows/*`: GitHub Actions to apply manifests and deploy services.

## Telegram Forwarder
- Manifest: `k8s/telegram-forwarder/deploy.yaml`
- Image: `ghcr.io/<repo>:<tag>`; the tag is provided via the workflow input.
- Environment: loaded from Secret `telegram-forwarder-env` (created/updated by workflow from GitHub Secrets).

Required GitHub Secrets
- `TG_FORWARDER_KAFKA_BOOTSTRAP_SERVERS_VALUE`
- `TG_FORWARDER_KAFKA_TG_MESS_TOPIC_NAME`
- `TG_FORWARDER_KAFKA_SASL_USERNAME`
- `TG_FORWARDER_KAFKA_SASL_PASSWORD`
- `TG_FORWARDER_TELEGRAM_TOKEN`
- Optional: `TG_FORWARDER_API_TG_WEB_HOOK_PATH`, `TG_FORWARDER_API_HEALTH_CHECK_PATH`

Deploy (GitHub Actions)
- Workflow: `.github/workflows/deploy-telegram-forwarder.yaml`
- Inputs:
  - `image_tag` (e.g., `v0.1.5`; defaults to `latest`)
  - `image_repo` (defaults to `ghcr.io/pufferfish-io/telegram-forwarder`)
- What it does:
  - Ensures namespace `app`.
  - Creates/updates Secret `telegram-forwarder-env` from GitHub Secrets.
  - Applies `k8s/telegram-forwarder/deploy.yaml`.
  - Sets the container image to `<image_repo>:<image_tag>` and waits for rollout.

Change domain or webhook path
- Edit host and path in `k8s/telegram-forwarder/deploy.yaml` under the Ingress `rules` section (default host `tg.forwarder.pufferfish.ru`, path `/telegram/webhook`).

## Ingresses
- Demo: `k8s/ingress/hello-demo-ingress.yaml` → domain `demo.pufferfish.ru`.
  - Workflow: `.github/workflows/deploy-ingress.yaml` (triggered on file change or manual run).
- Keycloak: `k8s/ingress/keycloak-ingress.yaml` → domain `auth.pufferfish.ru`.
  - Workflow: `.github/workflows/deploy-auth-ingress.yaml` (manual run).
- Both use cert-manager `letsencrypt-http01` and class `nginx`.

## MinIO
- Deployed via Helm using workflow `.github/workflows/deploy-minio.yaml` (manual run).
- Required GitHub Secrets:
  - `MINIO_ROOT_USER`
  - `MINIO_ROOT_PASSWORD`
- Default domains in `k8s/minio/values-prod.yaml`:
  - Console: `minio.ui.pufferfish.ru` (TLS `minio-ui-tls`).
  - API: `minio.back.pufferfish.ru` (TLS `minio-back-tls`).
- Update hosts/secret names directly in `values-prod.yaml` if needed.

## Useful Commands
- Check ingresses:
  ```bash
  kubectl get ingress -n demo -o wide
  kubectl get ingress -n auth -o wide
  kubectl get ingress -n app -o wide
  ```
- Change image manually:
  ```bash
  kubectl -n app set image deployment/telegram-forwarder \
    telegram-forwarder=ghcr.io/<repo>:<tag>
  ```

## Troubleshooting
- Certificate pending/failed: ensure cert-manager is installed and `ClusterIssuer` `letsencrypt-http01` exists; verify DNS is pointing to the ingress controller.
- Image pull errors: confirm `ghcr-secret` exists in the `app` namespace and has valid GH credentials.
- 404 on webhook: verify Ingress host and path match the Telegram webhook URL and the service is healthy (`/healthz`).
