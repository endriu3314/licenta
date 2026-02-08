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
    private static final String HEADER = "database,query_id,query_name,query_dataset,node_count,mean_ms,stddev_ms,median_ms,p95_ms,p99_ms,runs";

    public static void export(List<BenchmarkResult> results, Path outputDir) throws IOException {
        Files.createDirectories(outputDir);

        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
        Path file = outputDir.resolve("benchmark_%s.csv".formatted(timestamp));

        Files.write(file, Stream.concat(Stream.of(HEADER), results.stream().map(CsvExporter::toCsvLine)).toList());
        log.info("Results exported to {}", file);
    }

    private static String toCsvLine(BenchmarkResult r) {
        return "%s,%s,%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%d".formatted(
                r.database(), r.queryId(), r.queryName(), r.queryDataset(), r.nodeCount(),
                r.meanMs(), r.stdDevMs(), r.medianMs(), r.p95Ms(), r.p99Ms(), r.durationsNanos().size()
        );
    }
}
