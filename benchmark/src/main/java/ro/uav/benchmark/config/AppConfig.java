package ro.uav.benchmark.config;

import lombok.extern.slf4j.Slf4j;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

@Slf4j
public record AppConfig(
    Map<DatabaseType, DatabaseProfile> databases,
    int warmupRuns,
    int measurementRuns,
    Path queriesPath,
    Path resultsPath
) {
    public enum  DatabaseType { CITUS, TIDB, COCKROACH }

    public static AppConfig load(Path envFilePath) {
        Map<String, String> env = loadEnv(envFilePath);

        var databases = Map.of(
                DatabaseType.COCKROACH, new DatabaseProfile(
                        env.getOrDefault("COCKROACH_HOST", "localhost"),
                        Integer.parseInt(env.getOrDefault("COCKROACH_PORT", "26257")),
                        env.getOrDefault("COCKROACH_DB", "tpch"),
                        env.getOrDefault("COCKROACH_USER", "root"),
                        env.getOrDefault("COCKROACH_PASSWORD", "")
                )
        );

        return new AppConfig(
                databases,
                Integer.parseInt(env.getOrDefault("WARMUP_RUNS", "5")),
                Integer.parseInt(env.getOrDefault("MEASUREMENT_RUNS", "50")),
                Path.of(env.getOrDefault("QUERIES_PATH", "./queries")),
                Path.of(env.getOrDefault("RESULTS_PATH", "./results"))
        );
    }

    private static Map<String, String> loadEnv(Path envFilePath) {
        var merged = new HashMap<String, String>();

        try {
            Files.readAllLines(envFilePath).stream()
                    .filter(line -> !line.isBlank() && !line.startsWith("#"))
                    .map(line -> line.split("=", 2))
                    .filter(parts -> parts.length == 2)
                    .forEach(parts -> merged.put(parts[0].trim(), parts[1].trim()));
            log.info("Loaded config from {}", envFilePath);
        } catch (IOException e) {
            log.warn("Could not read {}: {}", envFilePath, e.getMessage());
        }

        System.getenv().forEach((key, value) -> {
            if (merged.containsKey(key)) {
                merged.put(key, value);
            }
        });

        return merged;
    }
}
