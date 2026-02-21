package ro.uav.benchmark.benchmark;

import ro.uav.benchmark.config.AppConfig;

import java.util.List;

public record BenchmarkResult(
        AppConfig.DatabaseType database,
        String queryId,
        String queryName,
        String queryDataset,
        int nodeCount,
        List<Long> durationsNanos
) {
}
