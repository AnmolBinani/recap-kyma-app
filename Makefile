
DOCKER_ACCOUNT=cap-dev.common.repositories.cloud.sap/anmol

build:
	cds build --production

build-dbimage:
	pack build bookshop-hana-deployer --path gen/db --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
	docker tag bookshop-hana-deployer:latest $(DOCKER_ACCOUNT)/bookshop-hana-deployer:latest

build-srv:
	pack build bookshop-srv --path gen/srv --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
	docker tag bookshop-srv:latest $(DOCKER_ACCOUNT)/bookshop-srv:latest

build-uiimage:
	pack build bookshop-approuter --path app --buildpack gcr.io/paketo-buildpacks/nodejs --builder paketobuildpacks/builder:base --env BP_NODE_RUN_SCRIPTS=""
	docker tag bookshop-approuter:latest $(DOCKER_ACCOUNT)/bookshop-approuter:latest

push-images: build build-dbimage build-srv build-uiimage
	docker push $(DOCKER_ACCOUNT)/bookshop-hana-deployer:latest
	docker push $(DOCKER_ACCOUNT)/bookshop-srv:latest
	docker push $(DOCKER_ACCOUNT)/bookshop-approuter:latest
