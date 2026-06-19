BINARY=bin/api
CMD=./cmd/api

.PHONY: build run test lint generate migrate-up migrate-down

build:
	go build -o $(BINARY) $(CMD)

run:
	go run $(CMD)/main.go

test:
	go test -race -count=1 ./...

lint:
	golangci-lint run ./...

generate:
	sqlc generate

migrate-up:
	migrate -path migrations -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path migrations -database "$(DATABASE_URL)" down 1

migrate-create:
	migrate create -ext sql -dir migrations -seq $(name)
