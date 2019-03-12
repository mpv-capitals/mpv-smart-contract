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
	@#@truffle deploy
	@zos push --network=$(network)

.PHONY: test
test:
	@truffle test
