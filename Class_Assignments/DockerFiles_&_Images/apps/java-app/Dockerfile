# ---- Stage 1: compile and package with the full JDK ----
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /src
COPY src/ .
RUN javac -d out HelloApp.java \
 && jar --create --file app.jar --main-class HelloApp -C out .

# ---- Stage 2: run the jar on a JRE-only image (no compiler) ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /src/app.jar .
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
