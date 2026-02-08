package ro.uav.benchmark.config;

public record DatabaseProfile(
        String host,
        int port,
        String database,
        String user,
        String password
) {}
