# HMDB Metabolites XML Processing

This repository contains instructions for processing the HMDB Metabolites XML file. The **current version is 5.0, released on 2021-11-17** (see [here](https://hmdb.ca/downloads/), Metabolite and Protein Data (in XML format), All Metabolites file).

## Steps

1. Download the HMDB Metabolites XML file:
```bash
wget http://www.hmdb.ca/system/downloads/current/hmdb_metabolites.zip
```

2. Unzip the downloaded file:
```bash
unzip hmdb_metabolites.zip
```

3. Navigate to the "hmdb" directory:
```bash
cd hmdb
```

4. Copy the XML file to the current directory:
```bash
cp ../hmdb_metabolites.xml .
```

5. Split the XML file into smaller parts (one per metabolite):
```bash
xml_split -v -l 1 hmdb_metabolites.xml
```

6. Remove the original XML file:
```bash
rm hmdb_metabolites.xml
```

7. Navigate back to the parent directory:
```bash
cd ..
```

8. (Optional) Create a zip archive of the "hmdb" directory for easier distribution:
```bash
zip -r hmdb_metabolites_split.zip hmdb
```

## Processing Scripts
Both Java and R scripts can be used to process the split XML files and create the prossesed mapping files. Java is recommended for faster processing. Refer to the links below for more information on using Java or R scripts.

- [Java Processing Scripts](https://github.com/tabbassidaloii/create-bridgedb-secondary2primary/blob/main/src/org/bridgedb/sec2pri/hmdb_XML_sec2pri.java), also creates a derby file. The input for this script is the zip file.
- [R Processing Scripts](https://github.com/tabbassidaloii/BridgeDb-Shiny/blob/main/Docker/app/datasources/hmdb_processing.R), the input for this script is the "hmdb" directory.  
