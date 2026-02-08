package ro.uav.benchmark.db;

import ro.uav.benchmark.config.AppConfig;
import ro.uav.benchmark.config.DatabaseProfile;

import java.sql.Connection;
import java.sql.SQLException;

public sealed interface DatabaseConnector permits CockroachConnector {
    Connection connect() throws SQLException;

    void clearCache(Connection connection) throws SQLException;

    AppConfig.DatabaseType type();

    String jdbcUrl();

    static DatabaseConnector create(AppConfig.DatabaseType type, DatabaseProfile profile) {
        return switch (type) {
            case COCKROACH -> new CockroachConnector(profile);
            default -> throw new RuntimeException("Database Connector not implemented yet");
        };
    }
}
