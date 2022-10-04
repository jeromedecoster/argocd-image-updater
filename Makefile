.SILENT:
.PHONY: app-version

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-22s\033[0m%s\n", $$1, $$2 }'

env-create: # 1) env-create
	./make.sh env-create

terraform-create: # 2) terraform-create
	./make.sh terraform-create
	
minikube-create: # 4) start minikube + setup argocd + image-updater
	./make.sh minikube-create

app-version: # 2) run app-version server using npm - dev mode
	./make.sh app-version

prod-build: # 3) build app-version image
	./make.sh prod-build

prod-run: # 3) run app-version image
	./make.sh prod-run

prod-stop: # 3) stop app-version container
	./make.sh prod-stop

docker-push: # 4) push app-version image to docker
	./make.sh docker-push

# update-major: # update major
# 	./make.sh update-major

# update-minor: # update minor
# 	./make.sh update-minor

update-patch: # 5) update patch version
	./make.sh update-patch

docker-watch: # 5) watch the update
	./make.sh docker-watch

image-updater-logs: # 5) argocd image updater logs
	./make.sh image-updater-logs
	
ecr-public-push: # 6) push website image to ecr (public)
	./make.sh ecr-public-push

secret-ecr-creds: # 7) set secret + creds for private ecr
	./make.sh secret-ecr-creds

ecr-private-push: # 7) push website image to ecr (private)
	./make.sh ecr-private-push

terraform-destroy: # 8) terraform-destroy
	./make.sh terraform-destroy
