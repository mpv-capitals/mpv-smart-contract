network = development

all: build

.PHONY: install
install:
	@npm install
	@npm i -g ganache-cli zos

.PHONY: build
build:
	@truffle compile

.PHONY: start
start:
	@ganache-cli --deterministic

.PHONY: deploy
deploy:
	@zos push --network=$(network)

.PHONY: deploy/deps
deploy/deps:
	@npx zos push --deploy-dependencies --network=$(network)

.PHONY: create
create:
	@npx zos create MasterPropertyValue --init initialize --network=$(network)

.PHONY: test
test:
	@npm test
