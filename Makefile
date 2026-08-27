SHELL := /bin/sh

FLUTTER ?= flutter
PYTHON ?= python3
COVERAGE_MIN ?= 70
HOST ?= 0.0.0.0
PORT ?= 3000
TARGET ?= lib/main_mock.dart
BUILD_DIR ?= build/web
SERVER_HOST ?=
PID_FILE ?= .dart_tool/web-server-$(PORT).pid
LOG_FILE ?= .dart_tool/web-server-$(PORT).log

.PHONY: help setup analyze test test-coverage knowledge-check dev dev-real build-web serve start stop restart status

help:
	@printf '%s\n' \
		'make setup       Resolve Flutter dependencies' \
		'make analyze     Run Flutter static analysis' \
		'make test        Run the test suite' \
		'make test-coverage  Run tests with coverage; fails below COVERAGE_MIN (default 70)' \
		'make knowledge-check  Validate five-layer project knowledge' \
		'make dev         Start Mock Web in foreground with hot reload' \
		'make dev-real    Start Web with relative /api paths (optional SERVER_HOST)' \
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

test-coverage:
	$(FLUTTER) test --coverage
	$(PYTHON) -m unittest discover -s tools -p 'test_*.py'
	$(PYTHON) tools/lcov_summary.py coverage/lcov.info --min $(COVERAGE_MIN)
knowledge-check:
	$(PYTHON) tools/knowledge_base.py check

dev:
	$(FLUTTER) run -d web-server \
		--web-hostname "$(HOST)" \
		--web-port "$(PORT)" \
		-t "$(TARGET)"

# Flutter 3.44 起引擎经编译期常量读取 FLUTTER_WEB_CANVASKIT_URL，必须以
# --dart-define 传入；bootstrap 对引擎产物的预取则由 --no-web-resources-cdn
# 切到本地相对路径（web/canvaskit/ 由编排层符号链接自 SDK 缓存）。
# 二者缺一：只给 dart-define 时 bootstrap 仍会预取 gstatic 并被 CSP 拦截。
CANVASKIT_URL ?= /canvaskit/

# DEVICE=chrome 需在 Xvfb 环境下运行（由根仓 stack.sh 包装）；该模式下调试
# 通道走 Chrome DevTools 协议，任意访客的引导不经 DWDS RunRequest 门控。
DEVICE ?= web-server

dev-real:
	$(FLUTTER) run -d "$(DEVICE)" \
		--web-hostname "$(HOST)" \
		--web-port "$(PORT)" \
		$(if $(SERVER_HOST),--dart-define=SERVER_HOST="$(SERVER_HOST)",) \
		--dart-define=FLUTTER_WEB_CANVASKIT_URL="$(CANVASKIT_URL)" \
		--no-web-resources-cdn \
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
