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
    public double meanMs() {
        return durationsNanos.stream()
                .mapToLong(Long::longValue)
                .average()
                .orElse(0.0) / 1_000_000.0;
    }

    public double stdDevMs() {
        double mean = meanMs() * 1_000_000.0;
        double variance = durationsNanos.stream()
                .mapToDouble(d -> Math.pow(d - mean, 2))
                .average()
                .orElse(0.0);
        return Math.sqrt(variance) / 1_000_000.0;
    }

    public double medianMs() {
        if (durationsNanos.isEmpty()) {
            return -1;
        }

        var sorted = durationsNanos.stream().sorted().toList();
        int mid = sorted.size() / 2;
        long medianNanos = sorted.size() % 2 == 0
                ? (sorted.get(mid - 1) + sorted.get(mid)) / 2
                : sorted.get(mid);
        return medianNanos / 1_000_000.0;
    }

    public double p95Ms() {
        if (durationsNanos.isEmpty()) {
            return -1;
        }

        var sorted = durationsNanos.stream().sorted().toList();
        int index = (int) Math.ceil(0.95 * sorted.size()) - 1;
        return sorted.get(Math.max(0, index)) / 1_000_000.0;
    }

    public double p99Ms() {
        if (durationsNanos.isEmpty()) {
            return -1;
        }

        var sorted = durationsNanos.stream().sorted().toList();
        int index = (int) Math.ceil(0.99 * sorted.size()) - 1;
        return sorted.get(Math.max(0, index)) / 1_000_000.0;
    }
}
