BINARY=bin/api
CMD=./cmd/api
ENV_FILE ?= .env.dev

.PHONY: build run dev test lint migrate-up migrate-down

build:
	go build -o $(BINARY) $(CMD)

run:
	go run $(CMD)/main.go

# dev: load .env.dev and run (requires docker compose up postgres minio -d first)
dev:
	set -a && . ./$(ENV_FILE) && set +a && go run $(CMD)/main.go

# dev-migrate: run migrations using .env.dev vars
dev-migrate:
	set -a && . ./$(ENV_FILE) && set +a && migrate -path migrations -database "$$DATABASE_URL" up

test:
	go test -race -count=1 ./...

lint:
	golangci-lint run ./...

migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

migrate-create:
	migrate create -ext sql -dir migrations -seq $(name)
