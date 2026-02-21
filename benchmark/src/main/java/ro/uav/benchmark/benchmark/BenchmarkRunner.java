package ro.uav.benchmark.benchmark;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import ro.uav.benchmark.config.AppConfig;
import ro.uav.benchmark.db.DatabaseConnector;
import ro.uav.benchmark.query.QueryDescriptor;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@RequiredArgsConstructor
public class BenchmarkRunner {
    private final AppConfig appConfig;

    public List<BenchmarkResult> runAll(List<QueryDescriptor> queries, int nodeCount) {
        var results = new ArrayList<BenchmarkResult>();
        for (var query : queries) {
            results.add(run(query, nodeCount));
        }
        return results;
    }

    public BenchmarkResult run(QueryDescriptor query, int nodeCount) {
        var connector = DatabaseConnector.create(appConfig.activeDatabase(), appConfig.databaseProfile());

        log.info("Benchmarking {} on {} ({} nodes) - {} warmup + {} runs", query.id(), appConfig.activeDatabase(), nodeCount, appConfig.warmupRuns(), appConfig.measurementRuns());

        for (int i = 0; i < appConfig.warmupRuns(); i++) {
            try (var conn = connector.connect()) {
                executeQuery(conn, query.sql());
            } catch (SQLException e) {
                log.warn("Warmup run {} failed {}", i, e.getMessage());
            }
        }

        var durations = new ArrayList<Long>();
        for (int i = 0; i < appConfig.measurementRuns(); i++) {
            try (var conn = connector.connect()) {
                connector.clearCache(conn);

                long startNanos = System.nanoTime();
                executeQuery(conn, query.sql());
                long durationNanos = System.nanoTime() - startNanos;

                durations.add(durationNanos);

                log.info("  Run {}/{} completed", i + 1, appConfig.measurementRuns());
            } catch (SQLException e) {
                log.error("Measurement run {} failed: {}", i, e.getMessage());
            }
        }

        return new BenchmarkResult(appConfig.activeDatabase(), query.id(), query.name(), query.dataset(), nodeCount, durations);
    }

    private void executeQuery(Connection conn, String sql) throws SQLException {
        try (var stmt = conn.createStatement(); var rs = stmt.executeQuery(sql)) {
            consumeResultSet(rs);
        }
    }

    private void consumeResultSet(ResultSet rs) throws SQLException {
        int columnCount = rs.getMetaData().getColumnCount();
        // read everything to force full data transfer
        while (rs.next()) {
            for (int i = 1; i <= columnCount; i++) {
                rs.getObject(i);
            }
        }
    }
}
