package ro.uav.benchmark.query;

import lombok.extern.slf4j.Slf4j;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

@Slf4j
public class QueryLoader {
    public static List<QueryDescriptor> loadAll(Path queriesRoot) throws IOException {
        if (!Files.isDirectory(queriesRoot)) {
            throw new IllegalArgumentException("Queries path does not exist " + queriesRoot);
        }

        try (var datasets = Files.list(queriesRoot)) {
            return datasets
                    .filter(Files::isDirectory)
                    .flatMap(QueryLoader::loadDataset)
                    .sorted(Comparator.comparing(QueryDescriptor::id))
                    .toList();
        }
    }

    public static List<QueryDescriptor> loadDataset(Path queriesRoot, String datasetName) {
        var datasetDir = queriesRoot.resolve(datasetName);
        if (!Files.isDirectory(datasetDir)) {
            throw new IllegalArgumentException("Dataset not found: " + datasetName);
        }
        return loadDataset(datasetDir).toList();
    }

    private static Stream<QueryDescriptor> loadDataset(Path datasetDir) {
        String dataset = datasetDir.getFileName().toString();
        try (var files = Files.list(datasetDir)) {
            return files
                    .filter(f -> f.toString().endsWith(".sql"))
                    .map(f -> loadQuery(f, dataset))
                    .toList()
                    .stream();
        } catch (IOException e) {
            log.error("Failed to load dataset {}: {}", dataset, e.getMessage());
            return Stream.empty();
        }
    }

    private static QueryDescriptor loadQuery(Path file, String dataset) {
        try {
            String sql = Files.readString(file).strip();
            String name = file.getFileName().toString().replace(".sql", "");
            log.debug("Loaded query {}/{}", dataset, name);
            return new QueryDescriptor(name, dataset, sql);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read " + file, e);
        }
    }
}
