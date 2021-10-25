import com.lovelysystems.db.testing.DBTest
import com.lovelysystems.db.testing.PGTestSettings

val settings = PGTestSettings(
    clientImage = "lovelysystems/lovely-db-commons:dev",
    defaultDB = "app",
    resetScripts = listOf("/pgdev/reset.sql")
) {
    // mount the sql files directly into the client make changes in sql visible without building the docker image
    withFileSystemBind("src/main/sql", "/app/schema/sql")
}

class SQLTest : DBTest(settings)
