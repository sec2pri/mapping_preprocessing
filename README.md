# create-bridgedb-secondary2primary

Creation of secondary to primary mapping database.

## How to create a Derby file

```shell
mvn clean install assembly:single
java -cp target/create-bridgedb-secondary2primary-0.0.1-SNAPSHOT-jar-with-dependencies.jar org.bridgedb.sec2pri.sec2pri $databaseName $separator $databaseCode
```