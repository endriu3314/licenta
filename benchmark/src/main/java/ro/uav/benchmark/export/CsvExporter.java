package ro.uav.benchmark.export;

import lombok.extern.slf4j.Slf4j;
import ro.uav.benchmark.benchmark.BenchmarkResult;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Stream;

@Slf4j
public class CsvExporter {
    private static final String HEADER = "database,query_id,query_name,query_dataset,node_count,duration_ms";

    public static void export(List<BenchmarkResult> results, Path outputDir) throws IOException {
        Files.createDirectories(outputDir);
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));

        Path file = outputDir.resolve("benchmark_%s_raw.csv".formatted(timestamp));
        Files.write(
                file,
                Stream.concat(
                        Stream.of(HEADER),
                        results.stream().flatMap(
                                r -> r.durationsNanos().stream().map(
                                        duration -> toRawCsvLine(r, duration))
                        )
                ).toList()
        );
        log.info("Raw results exported to {}", file);
    }

    private static String toRawCsvLine(BenchmarkResult r, Long durationNanos) {
        return "%s,%s,%s,%s,%d,%.3f".formatted(
                r.database(), r.queryId(), r.queryName(),
                r.queryDataset(), r.nodeCount(), durationNanos / 1_000_000.0
        );
    }
}
