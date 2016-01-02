BIN = $(GOPATH)/bin
NODE_BIN = $(shell npm bin)
PID_APP = .pid
PID_WDS = .pid_wds
PID_WP = .pid_wp
GO_FILES = $(filter-out src/app/server/bindata.go, $(shell find src/app -type f -name "*.go"))
TEMPLATES = $(wildcard src/app/server/data/templates/*.html)
BINDATA = src/app/server/bindata.go
BINDATA_FLAGS = -pkg=server -prefix=src/app/server/data
BUNDLE = src/app/server/data/static/build/bundle.js
APP = $(shell find src/app/client -type f)

build: clean $(BIN)/app

clean:
	@rm -rf src/app/server/data/static/build/*
	@rm -rf src/app/server/data/bundle.server.js
	@rm -rf $(BINDATA)
	@echo cleaned

$(BUNDLE): $(APP)
	@$(NODE_BIN)/webpack --progress --colors

$(BIN)/app: $(BUNDLE) $(BINDATA)
	@go install -ldflags "-w -X main.buildstamp=`date -u '+%Y-%m-%d_%I:%M:%S%p'` -X main.gittag=`git describe --tags || true` -X main.githash=`git rev-parse HEAD || true`" app

kill:
	@kill `cat $(PID_APP)` || true
	@kill `cat $(PID_WDS)` || true
	@kill `cat $(PID_WP)` || true

kill_app:
	@kill `cat $(PID_APP)` || true

serve: clean $(BUNDLE)
	@make kill
	@make restart
	@BABEL_ENV=dev node hot.proxy & echo $$! > $(PID_WDS)
	@$(NODE_BIN)/webpack --watch & echo $$! > $(PID_WP)
	@fswatch --event=Updated $(GO_FILES) $(TEMPLATES) $(BUNDLE) | xargs -n1 -I{} make restart || make kill_app

restart: BINDATA_FLAGS += -debug
restart: $(BINDATA)
	@make kill_app
	@echo restart the app...
	@go install app
	@$(BIN)/app run & echo $$! > $(PID_APP)

$(BINDATA):
	$(BIN)/go-bindata $(BINDATA_FLAGS) -o=$@ src/app/server/data/...

lint:
	@eslint src/app/client || true
	@golint $(filter-out src/app/main.go, $(GO_FILES)) || true
	@golint -min_confidence=1 app
