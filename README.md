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

## Message Responder

- Manifest: `k8s/message-responder/deploy.yaml`
- Image: `ghcr.io/pufferfish-io/message-responder:<tag>`; tag is provided via the deploy workflow input.
- Environment: loaded from Secret `message-responder-env` (created/updated by workflow from GitHub Secrets).

Required GitHub Secrets (in this deploy repo)

- `MSG_RESP_KAFKA_BOOTSTRAP_SERVERS_VALUE`
- `MSG_RESP_KAFKA_GROUP_ID`
- `MSG_RESP_KAFKA_REQUEST_TOPIC_NAME`
- `MSG_RESP_KAFKA_RESPONSE_TOPIC_NAME`
- `MSG_RESP_KAFKA_OCR_TOPIC_NAME`
- `MSG_RESP_KAFKA_SASL_USERNAME`
- `MSG_RESP_KAFKA_SASL_PASSWORD`
- `MSG_RESP_KAFKA_CLIENT_ID`

Deploy (GitHub Actions)

- Workflow: `.github/workflows/deploy-message-responder.yaml`
- Inputs:
  - `image_tag` (e.g., `v0.1.0`; defaults to `latest`)
- What it does:
  - Ensures namespace `app`.
  - Creates/updates Secret `message-responder-env` from GitHub Secrets (above).
  - Applies `k8s/message-responder/deploy.yaml`.
  - Sets the container image to `ghcr.io/pufferfish-io/message-responder:<image_tag>` and waits for rollout.

Build & Push (service repository)

- In the service repo, use a Dockerfile like:
  - `golang:1.24.4` builder → `gcr.io/distroless/static:nonroot` runtime
  - Set `CGO_ENABLED=0 GOOS=linux GOARCH=amd64`, build `./cmd/message-responder`
  - Expose `8080`, run as `nonroot`
  - A simple CI on tag push can build and push to GHCR using `${{ secrets.GITHUB_TOKEN }}` as in other services. Target image name should be `ghcr.io/<org-or-user>/message-responder:${{ github.ref_name }}`.

## Telegram Response Preparer

- Manifest: `k8s/telegram-response-preparer/deploy.yaml`
- Image: `ghcr.io/pufferfish-io/telegram-response-preparer:<tag>`; tag is provided via the deploy workflow input.
- Environment: loaded from Secret `telegram-response-preparer-env` (created/updated by workflow from GitHub Secrets).

Required GitHub Secrets (in this deploy repo)

- `TGRP_KAFKA_BOOTSTRAP_SERVERS_VALUE`
- `TGRP_KAFKA_TELEGRAM_MESSAGE_TOPIC_NAME`
- `TGRP_KAFKA_RESPONSE_MESSAGE_TOPIC_NAME`
- `TGRP_KAFKA_RESPONSE_MESSAGE_GROUP_ID`
- `TGRP_KAFKA_SASL_USERNAME`
- `TGRP_KAFKA_SASL_PASSWORD`
- `TGRP_KAFKA_CLIENT_ID`
- Optional: `TGRP_SERVER_PORT` (default `8080` if omitted)

Deploy (GitHub Actions)

- Workflow: `.github/workflows/deploy-telegram-response-preparer.yaml`
- Inputs:
  - `image_tag` (e.g., `v0.1.0`; defaults to `latest`)
- What it does:
  - Ensures namespace `app`.
  - Creates/updates Secret `telegram-response-preparer-env` from GitHub Secrets (above).
  - Applies `k8s/telegram-response-preparer/deploy.yaml`.
  - Sets the container image to `ghcr.io/pufferfish-io/telegram-response-preparer:<image_tag>` and waits for rollout.

Build & Push (service repository)

- Example Dockerfile (builder + distroless runtime) and CI:
  - Dockerfile uses `golang:1.24.4` as builder and `gcr.io/distroless/static:nonroot` as runtime.
  - Build with `CGO_ENABLED=0 GOOS=linux GOARCH=amd64` and output binary for `./cmd/tg-response-preparer`.
  - Expose `8080` (adjust to your server port if needed).
- Example GitHub Actions (in the service repo) to build on tag push and push to GHCR:
  - Uses `${{ secrets.GITHUB_TOKEN }}` to authenticate to GHCR.
  - Tags image as `ghcr.io/<org>/<repo>:${{ github.ref_name }}`.

## Telegram Sender

- Manifest: `k8s/telegram-sender/deploy.yaml`
- Image: `ghcr.io/pufferfish-io/telegram-sender:<tag>`; tag is provided via the deploy workflow input.
- Environment: loaded from Secret `telegram-sender-env` (created/updated by workflow from GitHub Secrets).

Required GitHub Secrets (names only)

- `TGSENDER_KAFKA_BOOTSTRAP_SERVERS_VALUE`
- `TGSENDER_KAFKA_TELEGRAM_MESSAGE_TOPIC_NAME`
- `TGSENDER_KAFKA_RESPONSE_MESSAGE_GROUP_ID`
- `TGSENDER_KAFKA_SASL_USERNAME`
- `TGSENDER_KAFKA_SASL_PASSWORD`
- `TGSENDER_KAFKA_CLIENT_ID`
- `TGSENDER_TELEGRAM_TOKEN`
- Optional: `TGSENDER_SERVER_PORT` (default `8084` if omitted)

Deploy (GitHub Actions)

- Workflow: `.github/workflows/deploy-telegram-sender.yaml`
- Inputs:
  - `image_tag` (e.g., `v0.1.0`; defaults to `latest`)
- What it does:
  - Ensures namespace `app`.
  - Creates/updates Secret `telegram-sender-env` from GitHub Secrets (above).
  - Applies `k8s/telegram-sender/deploy.yaml`.
  - Sets the container image to `ghcr.io/pufferfish-io/telegram-sender:<image_tag>` and waits for rollout.

## Doc2Text

- Manifest: `k8s/doc2text/deploy.yaml`
- Ingress (HTTP): `doc2text.pufferfish.ru` (TLS `doc2text-tls`), пути `/` и `/healthz`.
- Ingress (gRPC): `grpc.doc2text.pufferfish.ru` (TLS `grpc-doc2text-tls`), backend `doc2text:50052`.
- Image: `ghcr.io/pufferfish-io/doc2text:<tag>`; tag is provided via the deploy workflow input.
- Environment: loaded from Secret `doc2text-env` (created/updated by workflow from GitHub Secrets).

Required GitHub Secrets (names only)

- `DOC2TEXT_ADDR`
- `DOC2TEXT_PROVIDER`
- `DOC2TEXT_MAX_FILE_MB`
- `DOC2TEXT_MAX_FILES`
- `DOC2TEXT_YC_API_KEY`
- `DOC2TEXT_YC_FOLDER_ID`
- `DOC2TEXT_YC_ENDPOINT`
- `DOC2TEXT_YC_DEFAULT_MODEL`
- `DOC2TEXT_YC_MIN_CONFIDENCE`
- `DOC2TEXT_YC_HTTP_TIMEOUT`
- `DOC2TEXT_YC_LANGUAGES`
- `DOC2TEXT_S3_ENDPOINT`
- `DOC2TEXT_S3_ACCESS_KEY`
- `DOC2TEXT_S3_SECRET_KEY`
- `DOC2TEXT_S3_BUCKET`
- `DOC2TEXT_S3_USE_SSL`
- `DOC2TEXT_HTTP_ADDR`
- `DOC2TEXT_HTTP_HEALTH_CHECK_PATH`
- `DOC2TEXT_OIDC_ISSUER`
- `DOC2TEXT_OIDC_JWKS_URL`
- `DOC2TEXT_OIDC_AUDIENCE`
- `DOC2TEXT_OIDC_EXPECTED_AZP`

Deploy (GitHub Actions)

- Workflow: `.github/workflows/deploy-doc2text.yaml`
- Inputs:
  - `image_tag` (e.g., `v0.1.0`; defaults to `latest`)
- What it does:
  - Ensures namespace `app`.
  - Creates/updates Secret `doc2text-env` from GitHub Secrets (above).
  - Applies `k8s/doc2text/deploy.yaml`.
  - Sets the container image to `ghcr.io/pufferfish-io/doc2text:<image_tag>` and waits for rollout.

gRPC доступ

- Внутри кластера: `doc2text.app.svc.cluster.local:50052`.
- Снаружи: `grpc.doc2text.pufferfish.ru:443` (HTTP/2 TLS, NGINX Ingress, аннотация `backend-protocol: GRPC`).
- Пример вызова (если включён OIDC):
  ```bash
  grpcurl -H "authorization: Bearer $TOKEN" \
    grpc.doc2text.pufferfish.ru:443 \
    ocr.v1.OcrService/Process \
    -d '{"objectkey":"path/in/s3"}'
  ```
  Если на сервере нет gRPC reflection, передайте proto-файлы через `-proto`/`-import-path`.

Build & Push (service repository)

- Use a two-stage Dockerfile (Go builder → distroless runtime) that builds `./cmd/doc2text` for Linux amd64 and runs as nonroot, exposing ports as required by the service.
- Example CI (in the service repo) on tag push:
  - Logs into GHCR with `${{ secrets.GITHUB_TOKEN }}`
  - Builds with build args `VERSION`, `COMMIT`, `BUILT_AT`
  - Pushes `ghcr.io/<org>/<service>:${{ github.ref_name }}`

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

## Read logs

```bash
sudo journalctl -u telegram-forwarder.service -f -n 200 -o short-iso-precise
sudo journalctl -u telegram-normalizer.service -f -n 200 -o short-iso-precise

sudo journalctl -u telegram-forwarder.service -f -n 200 -o short-iso-precise
```
