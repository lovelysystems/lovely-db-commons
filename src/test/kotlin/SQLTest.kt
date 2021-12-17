import com.lovelysystems.db.testing.DBTest
import com.lovelysystems.db.testing.PGTestSettings
import org.junit.jupiter.api.Test

val settings = PGTestSettings(
    clientImage = "lovelysystems/lovely-db-commons:dev",
    serverImage = "lovelysystems/docker-postgres:12.9.0",
    defaultDB = "app",
    resetScripts = listOf("/pgdev/reset.sql")
) {
    // mount the sql files directly into the client make changes in sql visible without building the docker image
    withFileSystemBind("src/main/sql", "/app/schema/sql")
    // mount the json schema example directory
    withFileSystemBind("src/test/json_schema", "/app/schema/json_schema")

}

class TestingTest : DBTest(settings.copy(testFilePattern = "*_testing.sql")) {

    @Test
    fun `json schemas are tested`() {
        pg.client.runFiles("/app/schema/sql/t/test_json_schemas.sql")
    }
}

class MicroschemaTest : DBTest(settings.copy(testFilePattern = "*_microschema.sql"))
