.PHONY: bootstrap validate pull up down restart ps logs clean reset

bootstrap:
	bash scripts/bootstrap.sh

validate:
	docker compose config --quiet
	bash -n scripts/bootstrap.sh

pull:
	docker compose pull

up: bootstrap
	docker compose up -d
	docker compose ps

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
