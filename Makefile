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
	@ganache-cli --deterministic -a 10 --gasLimit=7712383

.PHONY: push
push:
	@npx zos push --network=$(network)

.PHONY: deploy
deploy: push
	@./scripts/deploy.sh -n $(network)
	@node scripts/deploy.js

.PHONY: deploy/reset
deploy/reset:
	@rm -rf zos.dev*.json
	@rm -rf zos.rinkeby.json
	$(MAKE) deploy

.PHONY: deploy/deps
deploy/deps:
	@npx zos push --deploy-dependencies --network=$(network)

.PHONY: create
create:
	@npx zos create MasterPropertyValue --init initialize --network=$(network)

.PHONY: test
test:
	@npm test

.PHONY: lint
lint:
	@npm run lint:fix
	@solhint contracts/*.sol
	@#@npm run lint:sol

#solc required: https://solidity.readthedocs.io/en/v0.4.24/installing-solidity.html
.PHONY: docs
docs:
	@rm -rf docs/docs
	@mkdir -p docs/docs
	@SOLC_PATH="/usr/local/bin/solc" SOLC_ARGS="openzeppelin-solidity=$$PWD/node_modules/openzeppelin-solidity zos-lib=$$PWD/node_modules/zos-lib openzeppelin-eth=$$PWD/node_modules/openzeppelin-eth" \
		npx solidity-docgen ./ ./contracts ./docs
	@echo 'output: ./docs/docs'

.PHONY: docs/site/start
docs/site/start:
	@(cd docs/website && yarn start)

.PHONY: docs/site/build
docs/site/build:
	@(cd docs/website && yarn build) && \
		rm -rf docs/build && \
		mv docs/website/build/Master\ Property\ Value docs/build
	@echo 'output: ./docs/build'
