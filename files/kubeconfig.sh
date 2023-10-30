ns=default #update
API_SERVER_URL="https://api.c-36d93b8.kyma.ondemand.com"

SECRET_NAME=docker-secret

CA=$(kubectl get secret/${SECRET_NAME} -n $ns -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl get secret/${SECRET_NAME} -n $ns -o jsonpath='{.data.token}' | base64 --decode)

echo -n "apiVersion: v1
kind: Config
clusters:
  - name: default-cluster
    cluster:
      certificate-authority-data: ${CA}
      server: ${API_SERVER_URL}
users:
  - name: default-user
    user:
      token: ${TOKEN}
contexts:
  - name: default-context
    context:
      cluster: default-cluster
      namespace: $ns
      user: default-user
current-context: default-context" | base64
