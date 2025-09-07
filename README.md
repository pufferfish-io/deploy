# deploy

Helm-based deployment configs for services, including `telegram-forwarder`.

telegram-forwarder
- Single-file manifest: `k8s/telegram-forwarder/deploy.yaml`
- Env берутся из Secret `telegram-forwarder-env` (создаётся в workflow из GitHub Secrets)

Required GitHub Secrets
- `TG_FORWARDER_KAFKA_BOOTSTRAP_SERVERS_VALUE`
- `TG_FORWARDER_KAFKA_TG_MESS_TOPIC_NAME`
- `TG_FORWARDER_KAFKA_SASL_USERNAME`
- `TG_FORWARDER_KAFKA_SASL_PASSWORD`
- `TG_FORWARDER_TELEGRAM_TOKEN`
- Optional: `TG_FORWARDER_API_TG_WEB_HOOK_PATH`, `TG_FORWARDER_API_HEALTH_CHECK_PATH`

Deploy workflow
- `.github/workflows/deploy-telegram-forwarder.yaml` (self‑hosted, kubectl apply)
- Input: `image_tag` (defaults to `latest`)
