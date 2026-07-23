SHELL := /bin/sh

FLUTTER ?= flutter
PYTHON ?= python3
HOST ?= 0.0.0.0
PORT ?= 3000
TARGET ?= lib/main_mock.dart
BUILD_DIR ?= build/web
SERVER_HOST ?= http://127.0.0.1:8888
PID_FILE ?= .dart_tool/web-server-$(PORT).pid
LOG_FILE ?= .dart_tool/web-server-$(PORT).log

.PHONY: help setup analyze test dev dev-real build-web serve start stop restart status

help:
	@printf '%s\n' \
		'make setup       Resolve Flutter dependencies' \
		'make analyze     Run Flutter static analysis' \
		'make test        Run the test suite' \
		'make dev         Start Mock Web in foreground with hot reload' \
		'make dev-real    Start Web against SERVER_HOST' \
		'make build-web   Build the Mock Web release artifact' \
		'make start       Build and serve release Web in background' \
		'make stop        Stop the release Web server started by make' \
		'make restart     Restart the release Web server' \
		'make status      Show release Web server status'

setup:
	$(FLUTTER) pub get

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

dev:
	$(FLUTTER) run -d web-server \
		--web-hostname "$(HOST)" \
		--web-port "$(PORT)" \
		-t "$(TARGET)"

dev-real:
	$(FLUTTER) run -d web-server \
		--web-hostname "$(HOST)" \
		--web-port "$(PORT)" \
		--dart-define=SERVER_HOST="$(SERVER_HOST)" \
		-t lib/main.dart

build-web:
	$(FLUTTER) build web --release -t "$(TARGET)"

serve: build-web
	$(PYTHON) -m http.server "$(PORT)" \
		--bind "$(HOST)" \
		--directory "$(BUILD_DIR)"

start: build-web
	@mkdir -p "$$(dirname "$(PID_FILE)")"
	@if [ -f "$(PID_FILE)" ]; then \
		pid=$$(cat "$(PID_FILE)"); \
		if kill -0 "$$pid" 2>/dev/null; then \
			echo "Web server already running (pid $$pid) at http://localhost:$(PORT)"; \
			exit 0; \
		fi; \
		rm -f "$(PID_FILE)"; \
	fi
	@if $(PYTHON) -c 'import socket,sys; s=socket.socket(); s.settimeout(0.2); sys.exit(0 if s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)' "$(PORT)"; then \
		echo "Port $(PORT) is already in use; stop that process before make start."; \
		exit 1; \
	fi
	@nohup setsid $(PYTHON) -m http.server "$(PORT)" \
		--bind "$(HOST)" \
		--directory "$(BUILD_DIR)" \
		>"$(LOG_FILE)" 2>&1 </dev/null & echo $$! >"$(PID_FILE)"
	@sleep 1
	@if ! kill -0 "$$(cat "$(PID_FILE)")" 2>/dev/null; then \
		echo "Failed to start Web server; see $(LOG_FILE)."; \
		rm -f "$(PID_FILE)"; \
		exit 1; \
	fi
	@echo "Web release server started at http://localhost:$(PORT) (pid $$(cat "$(PID_FILE)"))"

stop:
	@if [ ! -f "$(PID_FILE)" ]; then \
		echo "Web release server is not managed by make."; \
		exit 0; \
	fi
	@pid=$$(cat "$(PID_FILE)"); \
	if kill -0 "$$pid" 2>/dev/null; then \
		kill "$$pid"; \
		echo "Stopped Web release server (pid $$pid)."; \
	else \
		echo "Web release server process $$pid is already stopped."; \
	fi
	@rm -f "$(PID_FILE)"

restart:
	@$(MAKE) stop
	@$(MAKE) start

status:
	@if [ -f "$(PID_FILE)" ] && kill -0 "$$(cat "$(PID_FILE)")" 2>/dev/null; then \
		echo "Web release server is running at http://localhost:$(PORT) (pid $$(cat "$(PID_FILE)"))"; \
	else \
		echo "Web release server is not running under make."; \
	fi
