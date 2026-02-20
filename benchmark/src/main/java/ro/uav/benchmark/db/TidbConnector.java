package ro.uav.benchmark.db;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import ro.uav.benchmark.config.AppConfig;
import ro.uav.benchmark.config.DatabaseProfile;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

@Slf4j
@RequiredArgsConstructor
public final class TidbConnector implements DatabaseConnector {
    private final DatabaseProfile profile;

    @Override
    public Connection connect() throws SQLException {
        log.debug("Connecting to TiDB at {}:{}", profile.host(), profile.port());
        return DriverManager.getConnection(jdbcUrl(), profile.user(), profile.password());
    }

    @Override
    public void clearCache(Connection connection) throws SQLException {
        try (var stmt = connection.createStatement()) {
            log.debug("TiDB - connection-based cache strategy");
        }
    }

    @Override
    public AppConfig.DatabaseType type() {
        return AppConfig.DatabaseType.TIDB;
    }

    @Override
    public String jdbcUrl() {
        return "jdbc:mysql://%s:%d/%s?useServerPrepStmts=true&cachePrepStmts=false"
                .formatted(profile.host(), profile.port(), profile.database());
    }
}
