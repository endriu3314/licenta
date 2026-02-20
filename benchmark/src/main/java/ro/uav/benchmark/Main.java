package ro.uav.benchmark;

import lombok.extern.slf4j.Slf4j;
import ro.uav.benchmark.benchmark.BenchmarkRunner;
import ro.uav.benchmark.config.AppConfig;
import ro.uav.benchmark.export.CsvExporter;
import ro.uav.benchmark.query.QueryLoader;

import java.nio.file.Path;
import java.util.List;

@Slf4j
public class Main {
    static void main(String[] args) {
        var envFile = getArg(args, "--env", ".env");
        var nodeCount = Integer.parseInt(getArg(args, "--nodes", "1"));
        var config = AppConfig.load(Path.of(envFile));

        try {
            var queries = QueryLoader.loadAll(config.queriesPath());
            var runner = new BenchmarkRunner(config);
            var results = runner.runAll(
                    queries,
                    nodeCount
            );

            CsvExporter.export(results, config.resultsPath());
        } catch (Exception e) {
            log.error("Benchmark failed", e);
            System.exit(1);
        }
    }

    private static String getArg(String[] args, String key, String defaultValue) {
        for (var arg : args) {
            if (arg.startsWith(key + "=")) {
                return arg.substring(key.length() + 1);
            }
        }
        return defaultValue;
    }
}
