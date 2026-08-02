.PHONY: bootstrap validate pull up up-full up-backends up-grafana down restart ps logs clean reset

bootstrap:
	bash scripts/bootstrap.sh

validate:
	docker compose config --quiet
	bash -n scripts/bootstrap.sh

pull:
	docker compose pull

up: up-full

up-full: bootstrap
	docker compose up -d
	docker compose ps

up-backends: bootstrap
	docker compose up -d loki mimir tempo pyroscope alloy
	docker compose ps loki mimir tempo pyroscope alloy

up-grafana: bootstrap
	docker compose up -d grafana
	docker compose ps grafana

down:
	docker compose down

restart:
	docker compose restart

ps:
	docker compose ps

logs:
	docker compose logs -f --tail=200

clean:
	docker compose down --remove-orphans

reset:
	@echo "ATENÇÃO: este comando remove todos os dados locais da stack."
	@printf "Digite RESET para continuar: "; read answer; [ "$$answer" = "RESET" ]
	docker compose down --remove-orphans
	. ./.env 2>/dev/null || true; rm -rf "$${DATA_ROOT:-./data}"
