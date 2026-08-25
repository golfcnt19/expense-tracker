# syntax=docker/dockerfile:1
#
# ใช้ได้ทั้ง podman build และ docker build
#   podman build -t expense-api -f Containerfile .
#
# แยกสองสเตจเพื่อไม่ให้ JDK, ซอร์ส และ Maven cache ติดไปกับ image ที่ deploy จริง

# ── stage 1: build ───────────────────────────────────────────────────────
FROM docker.io/library/eclipse-temurin:25-jdk AS build

WORKDIR /build

# คัดลอกเฉพาะไฟล์ที่กำหนด dependency ก่อน
# ถ้าโค้ดเปลี่ยนแต่ dependency ไม่เปลี่ยน สเตจนี้จะถูก cache ไว้
COPY api/.mvn/ .mvn/
COPY api/mvnw api/pom.xml ./
RUN chmod +x mvnw && ./mvnw -B dependency:go-offline -DskipTests

COPY api/src/ src/
RUN ./mvnw -B -DskipTests package \
    && mv target/*.jar app.jar

# ── stage 2: runtime ─────────────────────────────────────────────────────
# JRE ไม่ใช่ JDK — ไม่ต้องมีคอมไพเลอร์ในเครื่องที่รันจริง
FROM docker.io/library/eclipse-temurin:25-jre

# curl มีไว้ให้ HEALTHCHECK ใช้ — JRE image ไม่ได้ติดมาให้
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# รันด้วยผู้ใช้ธรรมดา ไม่ใช่ root
RUN groupadd --system app && useradd --system --gid app --home /app app
WORKDIR /app

COPY --from=build --chown=app:app /build/app.jar app.jar

USER app
EXPOSE 8080

# ให้ JVM อ่านโควตาหน่วยความจำของคอนเทนเนอร์เอง
# แทนการฮาร์ดโค้ด -Xmx ซึ่งจะผิดทันทีที่เปลี่ยนขนาดเครื่อง
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -XX:TieredStopAtLevel=1"

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl --fail --silent http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
