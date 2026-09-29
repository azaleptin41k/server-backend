# ── Stage 1: сборка ──────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src

# Сначала только файлы сборки — слой с зависимостями кэшируется
COPY gradlew settings.gradle build.gradle ./
COPY gradle gradle
RUN chmod +x gradlew && ./gradlew --no-daemon dependencies > /dev/null

COPY src src
RUN ./gradlew --no-daemon bootJar -x test \
    && find build/libs -name '*.jar' ! -name '*-plain.jar' -exec cp {} /src/app.jar \;

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
# Distroless: нет shell и пакетного менеджера, меньше поверхность атаки и CVE.
FROM gcr.io/distroless/java21-debian12:nonroot
WORKDIR /app
COPY --from=build /src/app.jar /app/app.jar

# Секреты (JWT_SECRET, пароли БД, keystore для подписи) передаются при запуске,
# в образ они не попадают (см. .dockerignore и docker-compose.yml).
USER nonroot
EXPOSE 8081

LABEL org.opencontainers.image.title="rbpo-backend" \
      org.opencontainers.image.source="https://github.com/azaleptin41k/server-backend"

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
