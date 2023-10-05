# Processing mapping files for the IDRefiner tool
In this repo, the details of data processing are explained. Most of the data processing is done in R and some in Java (when the input is large to be processed in R).

To install those in Java, you can follow the steps below:

Installation
--------
Java 11 is required.

```shell
mvn clean install assembly:single
```

How to create a Derby file
--------
1) ChEBI SDF 

```shell
java -cp target/mapping_prerocessing-0.0.1-SNAPSHOT-jar-with-dependencies.jar org.sec2pri.chebi_sdf $inputFile $outputDir
```

2) HMDB XML

```shell
java -cp target/mapping_prerocessing-0.0.1-SNAPSHOT-jar-with-dependencies.jar org.sec2pri.hmdb_xml $inputFile $outputDir
```

**`InputFile`:** the input file;

**`outputDir`:** the directory in which the output should be saved.


Releases
--------
The mapping files are released and archived on [Zenodo]()
