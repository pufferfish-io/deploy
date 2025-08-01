#### Drop

```sh
helm uninstall minio -n minio || true
kubectl delete ns minio --wait=true || true
```

#### Get secrets

```sh
kubectl get secret minio -n minio -o jsonpath="{.data.root-user}" | base64 -d && echo
kubectl get secret minio -n minio -o jsonpath="{.data.root-password}" | base64 -d && echo
```

####

```sh
kubectl get secrets -n minio
```

```
kubectl get secret minio -n minio -o jsonpath="{.data.rootUser}" | base64 -d && echo
kubectl get secret minio -n minio -o jsonpath="{.data.rootPassword}" | base64 -d && echo
```
