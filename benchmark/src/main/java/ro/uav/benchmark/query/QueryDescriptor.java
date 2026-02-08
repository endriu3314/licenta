package ro.uav.benchmark.query;

public record QueryDescriptor(
        String name,
        String dataset,
        String sql
) {
    public String id() {
        return "%s/%s".formatted(dataset, name);
    }
}
