# Kasir Dapur backend — Render/Railway Docker deploy
FROM dart:3.13.0 AS build

WORKDIR /app
COPY backend/pubspec.yaml backend/pubspec.lock ./
RUN dart pub get

COPY backend/ ./
RUN dart pub get && dart compile exe bin/server.dart -o /server

FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates libsqlite3-0 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /server /app/server

ENV PORT=8080
EXPOSE 8080

CMD ["/app/server"]
