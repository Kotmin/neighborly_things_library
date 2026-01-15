# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Run tests
```bash
docker build -t neighborly:test --target test .
docker run --rm neighborly:test

```

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...


## Smoke api test
Install jq (if not installed)

Debian/Ubuntu:
```bash
sudo apt-get update && sudo apt-get install -y jq
```
Run against docker-compose
```bash
BASE_URL=http://localhost:3000 ./scripts/api_smoke_and_bench.sh
```

Run against Minikube Ingress
```bash
MINIKUBE_IP="$(minikube ip)"
BASE_URL="http://${MINIKUBE_IP}" HOST_HEADER="neighborly.local" ./scripts/api_smoke_and_bench.sh
```