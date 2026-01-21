.PHONY: help up down restart logs clean test-app

help:
	@echo "Available commands:"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - View logs from all services"
	@echo "  make clean      - Stop services and remove volumes"
	@echo "  make test-app   - Run the test application (requires Python)"
	@echo "  make status     - Check status of all services"

up:
	docker compose up -d
	@echo ""
	@echo "Services started!"
	@echo "  Grafana:  http://localhost:3000"
	@echo "  Alloy UI: http://localhost:12345"
	@echo "  Tempo:    http://localhost:3200"
	@echo "  Loki:     http://localhost:3100"

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

clean:
	docker compose down -v
	@echo "All services stopped and volumes removed"

test-app:
	@if [ ! -d "examples/venv" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv examples/venv; \
		echo "Installing dependencies..."; \
		examples/venv/bin/pip install -r examples/requirements.txt; \
	fi
	@echo "Running test application..."
	@echo "Make sure the stack is running (make up)"
	examples/venv/bin/python examples/test-app.py

status:
	@docker compose ps
	@echo ""
	@echo "Health checks:"
	@curl -s http://localhost:3200/ready > /dev/null && echo "  Tempo: ✓ Ready" || echo "  Tempo: ✗ Not ready"
	@curl -s http://localhost:3100/ready > /dev/null && echo "  Loki:  ✓ Ready" || echo "  Loki:  ✗ Not ready"
	@curl -s http://localhost:3000/api/health > /dev/null && echo "  Grafana: ✓ Ready" || echo "  Grafana: ✗ Not ready"
	@curl -s http://localhost:12345/ > /dev/null && echo "  Alloy: ✓ Ready" || echo "  Alloy: ✗ Not ready"
